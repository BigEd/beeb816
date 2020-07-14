# Use gtkwave dump.vcd signals_list.sav
# to view the waveforms
#
# Simple view of CPLD process here - reruns whole flow if source files
# have changed.
#

VPATH = ./:../rtl2

# /:../trial3_rtl:../trial4_rtl:../trial3_rtl/build_xc95108_p3_ff/netlist

SRC = ../rtl2

# Primary targets
all : testbench_phi1.vcd testbench_phi2.vcd

clean:
	\rm -rf build *.vcd *~ *exe *out

##clkctrl2_tb_sync_phi2.vcd : clkctrl2_tb.v s_edge_detect.v as_edge_detect.v clkctrl2.v
##	iverilog -D SYNC_SWITCH_D -m clkctrl2_tb -o clkctrl2_tb_sync_phi2.exe clkctrl2_tb.v  ${SRC}/s_edge_detect.v ${SRC}/as_edge_detect.v ${SRC}/clkctrl2.v
##	./clkctrl2_tb_sync_phi2.exe
##	mv dump.vcd clkctrl2_tb_sync_phi2.vcd
##
##clkctrl2_tb_async_phi2.vcd : clkctrl2_tb.v clkctrl.v 
##	iverilog -m clkctrl2_tb -o clkctrl2_tb_async_phi2.exe clkctrl2_tb.v  ../trial4_rtl/clkctrl.v 
##	./clkctrl2_tb_async_phi2.exe
##	mv dump.vcd clkctrl2_tb_async_phi2.vcd
##

testbench_phi1.vcd  : testbench.v ram_512kx8_m.v ram_64kx8_m.v level1b_mk2_m.v clkctrl_phi1.v 
	iverilog -m testbench -o testbench_phi1.exe testbench.v ram_512kx8_m.v ram_64kx8_m.v  ${SRC}/level1b_mk2_m.v ${SRC}/clkctrl_phi1.v
	./testbench_phi1.exe
	mv dump.vcd testbench_phi1.vcd
testbench_phi2.vcd  : testbench.v ram_512kx8_m.v ram_64kx8_m.v level1b_mk2_m.v clkctrl_phi2.v 
	iverilog -D STOP_ON_PHI2 -m testbench -o testbench_phi2.exe testbench.v ram_512kx8_m.v ram_64kx8_m.v  ${SRC}/level1b_mk2_m.v ${SRC}/clkctrl_phi2.v 
	./testbench_phi2.exe
	mv dump.vcd testbench_phi2.vcd


gatesim.vcd  : testbench.v ram_512kx8_m.v ram_64kx8_m.v level1b_mk2_m.v 
	iverilog -D GATESIM_D -m testbench -o gatesim.exe testbench.v ram_512kx8_m.v ram_64kx8_m.v  ../trial3_rtl/build_xc95108_p3_ff/netlist/level1b_mk2_m.v
	./gatesim.exe
	mv dump.vcd gatesim.vcd

