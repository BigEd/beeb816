# Use gtkwave dump.vcd signals_list.sav
# to view the waveforms
#
# Simple view of CPLD process here - reruns whole flow if source files
# have changed.
#

VPATH = ../trial3_rtl:../trial4_rtl

SRC = ../trial3_rtl

# Primary targets
all : clkctrl_tb_phi1.vcd clkctrl_tb_phi2.vcd clkctrl2_tb_sync_phi2.vcd clkctrl2_tb_async_phi2.vcd

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

clkctrl2_tb_sync_phi2.vcd : clkctrl2_tb.v s_edge_detect.v as_edge_detect.v clkctrl2.v
	iverilog -D SYNC_SWITCH_D -m clkctrl2_tb -o clkctrl2_tb_sync_phi2.exe clkctrl2_tb.v  ${SRC}/s_edge_detect.v ${SRC}/as_edge_detect.v ${SRC}/clkctrl2.v
	./clkctrl2_tb_sync_phi2.exe
	mv dump.vcd clkctrl2_tb_sync_phi2.vcd

clkctrl2_tb_async_phi2.vcd : clkctrl2_tb.v clkctrl.v 
	iverilog -m clkctrl2_tb -o clkctrl2_tb_async_phi2.exe clkctrl2_tb.v  ../trial4_rtl/clkctrl.v 
	./clkctrl2_tb_async_phi2.exe
	mv dump.vcd clkctrl2_tb_async_phi2.vcd
