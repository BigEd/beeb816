# Use gtkwave dump.vcd signals_list.sav
# to view the waveforms
#
# Simple view of CPLD process here - reruns whole flow if source files
# have changed.
#

VPATH = ../trial3_rtl

SRC = ../trial3_rtl

# Primary targets
all : clkctrl_tb_phi1.vcd clkctrl_tb_phi2.vcd clkctrl2_tb_phi1.vcd clkctrl2_tb_phi2.vcd

## +define+CLOCK_SWITCH_PIPELINED_RETIME_D=1

clean:
	\rm -rf build *.vcd *~ *exe *out


# Secondary targets


clkctrl_tb_phi1.vcd : clkctrl_tb.v
	iverilog -D STOP_ON_PHI1_D -m clkctrl_tb -o clkctrl_tb_phi1.exe clkctrl_tb.v 
	./clkctrl_tb_phi1.exe
	mv dump.vcd clkctrl_tb_phi1.vcd

clkctrl_tb_phi2.vcd : clkctrl_tb.v
	iverilog -m clkctrl_tb -o clkctrl_tb_phi2.exe clkctrl_tb.v 
	./clkctrl_tb_phi2.exe
	mv dump.vcd clkctrl_tb_phi2.vcd

clkctrl2_tb_phi1.vcd : clkctrl2_tb.v s_edge_detect.v as_edge_detect.v clkctrl2.v 
	iverilog -D STOP_ON_PHI1_D -m clkctrl2_tb -o clkctrl2_tb_phi1.exe clkctrl2_tb.v  ${SRC}/s_edge_detect.v ${SRC}/as_edge_detect.v ${SRC}/clkctrl2.v
	./clkctrl2_tb_phi1.exe
	mv dump.vcd clkctrl2_tb_phi1.vcd

clkctrl2_tb_phi2.vcd : clkctrl2_tb.v s_edge_detect.v as_edge_detect.v clkctrl2.v 
	iverilog -m clkctrl2_tb -o clkctrl2_tb_phi2.exe clkctrl2_tb.v  ${SRC}/s_edge_detect.v ${SRC}/as_edge_detect.v ${SRC}/clkctrl2.v
	./clkctrl2_tb_phi2.exe
	mv dump.vcd clkctrl2_tb_phi2.vcd


## 
## 
## 
## 
## 
## testbench.vcd: testbench.v
## 	iverilog -D SIMULATION_D=1 -m testbench testbench.v ../rtl/clock_switch_p2_m.v ../rtl/hs_timing_control_m.v ../rtl/level1b_m.v ../rtl/clock_divider24_m.v ../testbench/ram_512kx8_m.v	../testbench/ram_64kx8_m.v ../rtl/clock_switch_p3_m.v ../rtl/clock_divider3_m.v ../rtl/master_ckgen_m.v ../rtl/clkdiv4_m.v ../rtl/clkdiv1to8_m.v
## 	mv a.out testbench.out
## 	./testbench.out
## 	mv dump.vcd testbench.vcd
## 
## 
## clock_switch_p2.vcd : clock_switch_p2.out
## 	./clock_switch_p2.out
## 	mv dump.vcd clock_switch_p2.vcd
## 
## clock_switch_p2.out : clock_switch_p2_m.v clock_switch_tb.v 
## 	iverilog -D SIMULATION_D=1 -m clock_switch_tb ../rtl/clock_switch_p2_m.v clock_switch_tb.v ../rtl/hs_timing_control_m.v
## 	mv a.out clock_switch_p2.out
## 
