# Use gtkwave dump.vcd signals_list.sav
# to view the waveforms
#
# Simple view of CPLD process here - reruns whole flow if source files
# have changed.
#

VPATH = ../rtl

# Primary targets
all : icarus 

icarus: dump.vcd 

## +define+CLOCK_SWITCH_PIPELINED_RETIME_D=1

clean:
	\rm -rf build a.out *.vcd


# Secondary targets

dump.vcd : a.out
	./a.out

a.out : clock_switch_p2_m.v clock_switch_tb.v 
	iverilog -D SIMULATION_D=1 -m clock_switch_tb ../rtl/clock_switch_p2_m.v clock_switch_tb.v

