# (make sure we can access the parser package)
CLASSPATH=../../:$CLASSPATH
TERM=xterm

netlister_dir ?= ~/Documents/nas/Development/git/netlister

ALLLIBS ?= $(shell ls -1 ${netlister_dir}/lib/*.lib)


%.scr : %.v %_footer.scr ${ALLLIBS}
	${netlister_dir}/src/netlister.py \
	-i $*.v \
	-l ${netlister_dir}/lib/memory.lib \
	-l ${netlister_dir}/lib/idc_connectors.lib \
	-l ${netlister_dir}/lib/l1a-custom.lib \
	-l ${netlister_dir}/lib/l1b-custom.lib \
	-l ${netlister_dir}/lib/cpu.lib \
	-l ${netlister_dir}/lib/xilinx.lib \
	-l ${netlister_dir}/lib/rcl.lib \
	-l ${netlister_dir}/lib/triac.lib \
	-l ${netlister_dir}/lib/diode.lib \
	-l ${netlister_dir}/lib/74series.lib \
	-l ${netlister_dir}/lib/74series_soic.lib \
	-l ${netlister_dir}/lib/switches.lib \
	-l ${netlister_dir}/lib/i2c.lib \
	-o $*.scr \
	-f scr \
	-u \
	-t $*_footer.scr
	cp auto-params-l1b.ctl /tmp
	cp fine_routing.ctl /tmp
	cp design_rules.dru /tmp
	cp design_rules_smd.dru /tmp


%.net : %.v ${ALLLIBS}
	${netlister_dir}/src/netlister.py -i $*.v \
	-l ${netlister_dir}/lib/memory.lib \
	-l ${netlister_dir}/lib/idc_connectors.lib \
	-l ${netlister_dir}/lib/l1a-custom.lib \
	-l ${netlister_dir}/lib/l1b-custom.lib \
	-l ${netlister_dir}/lib/xilinx.lib \
	-l ${netlister_dir}/lib/cpu.lib \
	-l ${netlister_dir}/lib/rcl.lib \
	-l ${netlister_dir}/lib/triac.lib \
	-l ${netlister_dir}/lib/diode.lib \
	-l ${netlister_dir}/lib/74series.lib \
	-l ${netlister_dir}/lib/74series_soic.lib \
	-l ${netlister_dir}/lib/switches.lib \
	-l ${netlister_dir}/lib/i2c.lib \
	-o $*.net \
	-u \
	-f net
	cp auto-params-l1b.ctl /tmp
	cp fine_routing.ctl /tmp
	cp design_rules.dru /tmp
	cp design_rules_smd.dru /tmp


bufboard:	bufboard.scr bufboard.net
beeb816_mk2b:	beeb816_mk2b.net  beeb816_mk2b.scr 

all: bufboard beeb816_mk2b
