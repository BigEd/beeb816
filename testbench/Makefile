# Use gtkwave dump.vcd signals_list.sav
# to view the waveforms
#
# Simple view of CPLD process here - reruns whole flow if source files
# have changed.
#

VPATH = ../rtl

# Primary targets
all : icarus cver

icarus: dump.vcd

cver: verilog.dump

verilog.dump : level1b_m.v clock_switch_p1_m.v ram_512kx8_m.v ram_64kx8_m.v testbench.v clock_switch_p2_m.v clock_divider24_m.v
	cver  testbench.v ../rtl/clock_divider24_m.v ../rtl/level1b_m.v ../rtl/clock_switch_p1_m.v ../rtl/clock_switch_p2_m.v ram_64kx8_m.v ram_512kx8_m.v +define+SIMULATION_D=1

## +define+CLOCK_SWITCH_PIPELINED_RETIME_D=1

clean:
	\rm -rf build a.out *.vcd verilog.dump


# Secondary targets

dump.vcd : a.out
	./a.out


a.out : level1b_m.v clock_switch_p1_m.v clock_divider24_m.v ram_512kx8_m.v ram_64kx8_m.v testbench.v clock_switch_p2_m.v
	iverilog -D ALLOW_512K_RAM_D=1 -D SIMULATION_D=1 -D ALLOW_GPIOS_D=1 -D CLOCK_SWITCH_PIPELINED_RETIME_D=1 -m testbench ../rtl/level1b_m.v ../rtl/clock_switch_p1_m.v ../rtl/clock_switch_p2_m.v ../rtl/clock_divider24_m.v ram_512kx8_m.v ram_64kx8_m.v testbench.v

