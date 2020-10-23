#!/usr/bin/env python
## **************************************************************************
##   build.py - wrapper script to run all Xilinx cpld/fpga build processes
##  
##   COPYRIGHT 2010 Richard Evans, Ed Spittles
## 
##   build.py is free software: you can redistribute it and/or modify
##   it under the terms of the GNU Lesser General Public License as published by
##   the Free Software Foundation, either version 3 of the License, or
##   (at your option) any later version.
##
##   tube is distributed in the hope that it will be useful,
##   but WITHOUT ANY WARRANTY; without even the implied warranty of
##   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##   GNU Lesser General Public License for more details.
##
##   You should have received a copy of the GNU Lesser General Public License
##   along with tube.  If not, see <http://www.gnu.org/licenses/>.
##
## **************************************************************************
"""
build.py

     Run a complete Xilinx CPLD or FPGA build.

"""

import getopt, os, os.path, shutil, sys, time
from subprocess import Popen, PIPE, call

# Use globals to hold all command line arguments
g_directory = ""
g_noexecute = False
g_verbose = False
g_toolargs = dict()
g_module = ""
g_project_file = ""
g_constraints = ""
g_keephierarchy = "No"
g_target = "xc9500"
g_optimize = "area"
g_fresh = False
g_fpga_flow = False


def usage() :
    """
    Print usage message.
    """
    print __doc__ + """
  USAGE:

    build.py -m|--module <verilog or vhdl module name>  \\
             -p|--project <project filename> \\
             -t|--target <target device> \\
             -c|--constraints <constraints filename> \\
             -o|--optimize <optimization setting> \\
             -d|--dir <directory name for build> \\
             -a|--toolargs "toolname: arguments" \\
             -k|--keephierarchy \\
             -n|--no-execute \\
             -f|--fresh \\
             -h|--help

  REQUIRED SWITCHES

    -m --module  <verilog or vhdl module name>    Name of base modules


  OPTIONAL SWITCHES

    -a --toolargs "toolname: args..."     Specifies a string of arguments to be passed verbatim
                                          to the named tool.
    -c --constraints <filename>           Name of a constraints file. Default is to run with
                                          no constraints.
    -d --directory <dirname>              Name for working directory to be created in current
                                          directory. Default is to create a directory named
                                          <module>-<target>-<datestamp>
    -f --fresh                            Cleans out all data in the build directory if it
                                          already exists before starting build.py
    -o --optimize <speed|area>            Specify speed or area optimization. Default is
                                          to optimize for area.
    -k --keephierarchy                    Synthesis should try not to flatten hierarchy
    -n --no-execute                       Show steps without running
    -p --project <filename>               Name of project file with paths to verilog/vhdl
                                          source. Default it to generate one automatically
                                          with all rtl files in the current directory
    -t --target  <device_name or family>  Name of specific Xilinx device or family (for CPLDs
                                          only - FPGAs require a device to be specified for 
                                          mapping). Defaults to xc9500. 
    -v --verbose                          Writes stdout from tools to screen in place of 
                                          shorter summary messages
    -h --help                             Produce this help information.

  COMMON TARGETS

    Type     Family        Name                Example Device Name
    CPLD     xpla3         CoolRunner XPLA3    xcr3032xl-r-PC44    

    CPLD     acr2          CoolRunner2         xc2c32a-6-vq44, xc2c256-6-tq144,
                                               xc2c256-10-tq144

    CPLD     xc9500        XC9500              xc9536-5-pc44, xc9572-10-pc44,
                                               xc95108-10-pc84, xc95216-12-pq160
    FPGA     spartan3e(*)  Spartan3e           xc3s500e-pq208-5, xc3s250e-pq208-5

  (*) When running with an FPGA target you need to specify a device rather than the
  generic family or the mapping process will fail. The CPLD mapper will automatically
  choose the smallest CPLD in that family.

  EXAMPLES

    build.py -m cpu16 -t xc9500 -a "xst: -define {SYNTH_D=1 USE_SOMETHING_D=1}"

    - build a module cpu16 and target the smallest available device in the xc9500 
      family

    build.py -m lfsr10 -t xc2c256-10-tq144 -o speed -p lfsr.prj -c lfsr.constraints  \\
             -a "cpldfit: -pterms 10 -inputs 10" -a "xst: -mux_extract no"

    - build a module into a specific device, optimizing for speed instead of area
      and using user created project and constraints files, apply command options
      to cpldfit and xst.

    """
    return



def remove_dir_contents(directory):
    """
    Recursively remove all files and subdirectories within a given directory.
    """
    for root, dirs, files in os.walk(directory):
        for f in files:
            os.unlink(os.path.join(root, f))
        for d in dirs:
            shutil.rmtree(os.path.join(root, d))
            
def timestamp():
    lt = time.localtime(time.time())
    return "%02d.%02d.%04d_%02d:%02d:%02d" % (lt[2], lt[1], lt[0], lt[3], lt[4], lt[5])

def create_files():
    """
    Ensure that all working directories and temporary files exist. Create any
    files with design data as required.
    """
    global g_project_file
    workdir=g_directory

    #ensure that the working and temp directories exist
    for d in ( workdir, os.path.join(workdir,"tmp"), os.path.join(workdir,"xst")):
        if not os.path.exists(d):
            os.mkdir(d)

    # Write the .lso file
    f = open( os.path.join(workdir, "%s.lso" % g_module), 'w')
    f.write("work\n")
    f.close()

    # create the project file if required
    if g_project_file == "" :
        g_project_file = "%s.%s" % (g_module,"prj")
        f = open( os.path.join(workdir,"%s" % g_project_file), 'w' )
        for filename in os.listdir("."):
            if filename.endswith(".v") and not filename.startswith(".#"):
                f.write("verilog work %s\n" % (os.path.abspath(filename) ))
            if filename.endswith(".vhd") and not filename.startswith(".#"):
                f.write("vhdl work %s\n" % (os.path.abspath(filename) ))
        f.close()

    return


def launch_command( command_line, input = "") :
    """
    Launch a command line string via Popen and return True if successful, False if not.

    When the verbose flag is True, the stdout of the process is printed to screen otherwise
    it is suppressed.
    """
    if g_noexecute:
        print "launch_command(g_noexecute): %s" % command_line
        if input != "":
            print "launch_command(g_noexecute-input-begins):\n"
            print input
            print "launch_command(g_noexecute-input-ends)\n"
        return True
    
    if g_verbose and input == "":
        # provide raw IO without prefiltering
        rc = call( command_line, shell=True) 
    else :
        f = Popen( command_line, stdout=PIPE, stdin=PIPE, shell=True)
        if input == "":
            (sout, serr) = f.communicate()
        else:
            (sout, serr) = f.communicate(input=input)
        if g_verbose:
            print sout
        rc = f.wait()

    return (rc == 0 )

def create_run_file( filename, command_list ):
    """
    Write a shell command to run a list of commands saving the file in the workdir, 
    """
    f = open(os.path.join(g_directory, filename), 'w')
    f.write("#!/bin/sh\n")
    f.write("#   build script written by build.py\n")
    f.write("\n".join(command_list) )
    f.write("\n")
    f.close()
    os.chmod( os.path.join(g_directory, filename), 0777)
    return

def create_sim_netlist():
    """
    Create simulation netlist.
    """
    print "INFO: Generating simulation netlist ..."

    if "netgen" in g_toolargs:
        arg_string = g_toolargs["netgen"]
    else:
        arg_string = "" 

    command_list = ["netgen -w -ofmt verilog -aka %s_map.ncd %s" % \
        (g_module, arg_string)]

    # Write a shell command to run the process, 
    runfile = "run_create_netlist_%s.sh" % g_module 
    create_run_file(runfile, command_list)

    return launch_command(  "cd %s ; ./%s" % (g_directory, runfile))

   
def create_jedec():
    """
    Create JEDEC file for programming hardware
    """
    print "INFO: Generating JEDEC programming file ..."

    if g_fpga_flow:
       if "bitgen" in g_toolargs:
            arg_string = g_toolargs["bitgen"]
       else:
            arg_string = "" 

       command_list = ["bitgen \\"]
       command_list.append("-w                          \\")
       command_list.append("-g DebugBitstream:No        \\")
       command_list.append("-g Binary:no                \\")
       command_list.append("-g CRC:Enable               \\")
       command_list.append("-g ConfigRate:6             \\")
       command_list.append("-g CclkPin:PullUp           \\")
       command_list.append("-g M0Pin:PullUp             \\")
       command_list.append("-g M1Pin:PullUp             \\")
       command_list.append("-g M2Pin:PullUp             \\")
       command_list.append("-g ProgPin:PullUp           \\")
       command_list.append("-g DonePin:PullUp           \\")
       command_list.append("-g TckPin:PullUp            \\")
       command_list.append("-g TdiPin:PullUp            \\")
       command_list.append("-g TdoPin:PullUp            \\")
       command_list.append("-g TmsPin:PullUp            \\")
       command_list.append("-g UnusedPin:PullDown       \\")
       command_list.append("-g UserID:0xFFFFFFFF        \\")
       command_list.append("-g DCMShutdown:Disable      \\")
       command_list.append("-g DCIUpdateMode:AsRequired \\")
       command_list.append("-g StartUpClk:CClk          \\")
       command_list.append("-g DONE_cycle:4             \\")
       command_list.append("-g GTS_cycle:5              \\")
       command_list.append("-g GWE_cycle:6              \\")
       command_list.append("-g LCK_cycle:NoWait         \\")
       command_list.append("-g Match_cycle:Auto         \\")
       command_list.append("-g Security:None            \\")
       command_list.append("-g DonePipe:No              \\")
       command_list.append("-g DriveDone:No             \\")
       command_list.append("%s.ncd  %s" % (g_module, arg_string))
       # generate the PROM file for the GODIL - hard coded parameters for now, size and ROM type
       command_list.append("promgen -w -spi -p mcs -s 16384 -u 0 %s.bit" % g_module)

    else:
        # CPLD Flow
        if "hprep6" in g_toolargs:
            arg_string = g_toolargs["hprep6"]
        else:
            arg_string = ""
        
        command_list = ["hprep6  -s IEEE1149 -n %s -i %s %s" % \
            (g_module,g_module,arg_string)]

    # Write a shell command to run the process, 
    runfile = "run_create_jedec_%s.sh" % g_module 
    create_run_file(runfile, command_list)

    return launch_command(  "cd %s ; ./%s" % (g_directory, runfile))


def fpgapnr( ):
    """
    Run mapping and PNR for a FPGA target
    """
    print "INFO: Running FPGA mapping and PNR ..."
    if "map" in g_toolargs:
        arg_string = g_toolargs["map"]
    else:
        arg_string = ""

    command_list = ["map -p %s -cm %s -ir off -pr off -c 100 -o %s_map.ncd %s.ngd %s.pcf"  \
        % (g_target,g_optimize,g_module,g_module,g_module)]
    if "par" in g_toolargs:
        arg_string = g_toolargs["par"]
    else:
        arg_string = ""
    command_list.append("par -w -ol std -t 1 %s_map.ncd %s.ncd %s.pcf" % \
            (g_module, g_module, g_module))

    # Write a shell command to run the process, 
    runfile = "run_fpgapnr_%s.sh" % g_module 
    create_run_file(runfile, command_list)

    return launch_command(  "cd %s ; ./%s" % (g_directory, runfile))

def sta ():
    """
    Run Static timing analysis and generate reports
    """
    print "INFO: Running STA ..."

    if g_fpga_flow:
        if "trce" in g_toolargs:
            arg_string = g_toolargs["trce"]
        else:
            arg_string = ""
        command_list = ["trce -v 3 -s 5 -fastpaths -xml %s.twx %s.ncd -o %s.twr %s.pcf\n" % \
            (g_module,g_module,g_module,g_module)]
    else:
        # CPLD specific flow
        if "tsim" in g_toolargs:
            arg_string = g_toolargs["tsim"]
        else:
            arg_string = ""
    
        command_list = ["tsim %s %s.nga %s\n" % (g_module,g_module,arg_string)]
        if "taengine" in g_toolargs:
            arg_string = g_toolargs["taengine"]
        else:
            arg_string = ""
        command_list.append( "taengine -f %s -detail %s\n" % (g_module,arg_string))

    # Write a shell command to run the process, 
    runfile = "run_sta_%s.sh" % g_module 
    create_run_file(runfile, command_list)

    return launch_command(  "cd %s ; ./%s" % (g_directory, runfile))


def cpldfit( ):
    """
    Fit the selected device and generate reports
    """
    
    print "INFO: Starting CPLD fitting process ..."
    optimize = g_optimize
    if g_optimize == "area":
        optimize = "density"
        

    if "cpldfit" in g_toolargs:
        arg_string = g_toolargs["cpldfit"]
    else:
        arg_string = ""

    # we need some options to set the effort:
    #    make inputs, pterms and exhaust optional
    #    ideally we should write these options to a file in the subdir
    #    and have an option to allow reuse, so the file can be tweaked
    #
    command_list = [ "cpldfit -p %s \\" % g_target]
    command_list.append("-ofmt vhdl \\")
    command_list.append("-optimize %s \\" % optimize)
    command_list.append("-loc on \\")
    command_list.append("-slew slow \\")
    command_list.append("-exhaust \\")
    command_list.append("-init low \\")
    command_list.append("-inputs 20 \\")
    command_list.append("-pterms 20 \\")
    # Additional options for xc9500
    if g_target.startswith("xc95") and not g_target.endswith("100") :
        command_list.append("-power std -localfbk -pinfbk \\")
        command_list.append("-unused float \\")        
##    command_list.append("-exhaust \\")
    command_list.append("%s.ngd %s" % (g_module, arg_string))

    # Write a shell command to run the process, 
    runfile = "run_cpldfit_%s.sh" % g_module 
    create_run_file( runfile, command_list )
    return launch_command( "cd %s ; ./%s" % (g_directory, runfile) )


def ngdbuild():
    '''
    Run the ngdbuild process (backend for synthesis)
    '''
    print "INFO: Starting ngdbuild process ..."

    if "ngdbuild" in g_toolargs:
        arg_string = g_toolargs["ngdbuild"]
    else:
        arg_string = ""

    if g_constraints == "":
        cons_arg = ""
    else:
        cons_arg = "-uc %s" % g_constraints    

    command_list = ["ngdbuild -dd _ngo -p %s %s %s.ngc %s.ngd %s\n" \
        % (g_target,cons_arg,g_module,g_module,arg_string) ]

    # Write a shell command to run the xst process, 
    runfile = "run_ngdbuild_%s.sh" % g_module 
    create_run_file( runfile, command_list )
    return launch_command( "cd %s ; ./%s" % (g_directory, runfile) )

def synthesis():
    '''
    Run synthesis and ngdbuild process. Return True if successful, false otherwise. 
    '''

    print "INFO: Starting xst synthesis process ..."
    if "xst" in g_toolargs:
        arg_string = g_toolargs["xst"]
    else:
        arg_string = ""
    
    # Write the run commands to an input script file
    xstfile = "%s.xst" % g_module
    f = open( os.path.join(g_directory, xstfile), 'w')
    command_list= ["set -tmpdir ./tmp\n"]
    command_list.append("set -xsthdpdir ./xst\n")
    command_list.append("run -ifn %s -p %s -ifmt mixed  " % (g_project_file, g_target))
    command_list.append("-ofn %s -ofmt NGC -top %s -opt_mode %s " % (g_module,g_module,g_optimize) )
    command_list.append("-opt_level 2 ")
    command_list.append("-iuc NO -lso %s.lso -keep_hierarchy %s " % (g_module,g_keephierarchy) )
    command_list.append("-netlist_hierarchy as_optimized  -rtlview Yes ")
    command_list.append("""-hierarchy_separator /  -bus_delimiter <>  """)
    command_list.append("-case maintain  -verilog2001 YES  -fsm_extract YES ")
    command_list.append("-fsm_encoding COMPACT  -safe_implementation No  ")
    command_list.append("-mux_extract YES  -resource_sharing YES  -iobuf YES ")
    if not g_fpga_flow:
        command_list.append("-pld_mp YES  -pld_xp YES  -wysiwyg NO  ")
    command_list.append("-equivalent_register_removal YES ")
    command_list.append( arg_string + "\n")
    f.write( "".join(command_list) )
    f.close()

    command_list = ["xst -ifn %s -intstyle xflow -ofn ./%s.syr\n" % (xstfile,g_module)]
    # Write a shell command to run the xst process, 
    runfile = "run_xst_%s.sh" % g_module 
    create_run_file( runfile, command_list )
    return launch_command( "cd %s ; ./%s" % (g_directory, runfile) )

def main_loop():
    """
    Main Device flows controlled from here
    """
    if g_fresh and os.path.exists(g_directory) :
        remove_dir_contents(g_directory)
    
    create_files()

    if g_fpga_flow :
        steps = ( synthesis, ngdbuild, fpgapnr, sta, create_jedec, create_sim_netlist )
    else:
        steps = ( synthesis, ngdbuild, cpldfit, sta, create_jedec )

    for step in steps :
        if not step():
            print "ERROR - completed with errors, check log files"
            sys.exit(1) 
        else:
            print "INFO: Done"
    return


    
def main ( argv ) :
    print ( "Executing build.py ", sys.argv ) ;
    global g_directory
    global g_noexecute
    global g_verbose
    global g_toolargs
    global g_module
    global g_project_file
    global g_constraints
    global g_target
    global g_optimize
    global g_keephierarchy
    global g_fresh
    global g_fpga_flow

    ## Use getopts to process arguments
    try:
        opts, args = getopt.getopt( argv[1:], "m:p:t:c:o:d:a:kfhvn",
                                     ["module=","project=","target=",
                                     "constraints=", "optimize=","dir=",
                                     "toolargs=","keephierarchy","fresh", "help", "verbose", "no-execute"])
    except getopt.GetoptError:
        usage()
        sys.exit(0)

    
    for opt, arg in opts:
        if opt in ( "-m", "--module" ) :
            g_module = arg
        if opt in ( "-p", "--project" ) :
            g_project_file = os.path.abspath(arg)
        if opt in ( "-t", "--target" ) :
            g_target = arg.lower()
        if opt in ( "-c", "--constraints" ) :
            g_constraints = os.path.abspath(arg)
        if opt in ( "-o", "--optimize" ) :
            g_optimize = arg.lower()
        if opt in ( "-d", "--directory", "--dir" ) :
            g_directory = arg
        if opt in ( "-a", "--toolargs" ) :
            fields = (arg).split(":")
            g_toolargs[fields[0].lower()] = fields[1]
        if opt in ( "-k", "--keephierarchy" ) :
            g_keephierarchy = "Yes"
        if opt in ( "-f", "--fresh" ) :
            g_fresh = True
        if opt in ( "-v", "--verbose" ) :
            g_verbose = True
        if opt in ( "-n", "--no-execute" ) :
            g_noexecute = True
        if opt in ( "-h","--help" ) :            
            usage()
            sys.exit(0)
            
    # Check mandatory args are present
    if ( g_module == "" ) :
        usage()
        sys.exit(1)
    if (g_directory == "" ) :
        g_directory = "%s-%s-%s" % ( g_module, g_target, timestamp())

    g_fpga_flow = ( g_target.startswith("xc3s") or 
                    g_target.startswith("xc2v") or 
                    (g_target.find("spartan") > -1))

    main_loop()
    sys.exit(0)
    
if __name__ == "__main__":
    main( sys.argv)
    
