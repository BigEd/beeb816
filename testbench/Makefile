# Use gtkwave dump.vcd signals_list.sav
# to view the waveforms
#
# Simple view of CPLD process here - reruns whole flow if source files
# have changed.
#

VPATH = ../rtl

# Primary targets
all : icarus 

icarus: clock_switch_p2.vcd 

## +define+CLOCK_SWITCH_PIPELINED_RETIME_D=1

clean:
	\rm -rf build a.out *.vcd


# Secondary targets



testbench.vcd: testbench.v
	iverilog -D SIMULATION_D=1 -m testbench testbench.v ../rtl/clock_switch_p2_m.v ../rtl/hs_timing_control_m.v ../rtl/level1b_m.v ../rtl/clock_divider24_m.v ../testbench/ram_512kx8_m.v	../testbench/ram_64kx8_m.v ../rtl/clock_switch_p3_m.v ../rtl/clock_divider3_m.v
	mv a.out testbench.out
	./testbench.out
	mv dump.vcd testbench.vcd


clock_switch_p2.vcd : clock_switch_p2.out
	./clock_switch_p2.out
	mv dump.vcd clock_switch_p2.vcd

clock_switch_p2.out : clock_switch_p2_m.v clock_switch_tb.v 
	iverilog -D SIMULATION_D=1 -m clock_switch_tb ../rtl/clock_switch_p2_m.v clock_switch_tb.v ../rtl/hs_timing_control_m.v
	mv a.out clock_switch_p2.out

