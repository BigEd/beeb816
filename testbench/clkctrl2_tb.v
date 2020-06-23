`timescale 1ns/1ns

/*
 * Trial test bench for clock switching between two asynchronous clocks, but where one clock is synchronous to a much
 * higher speed clock which is used to control the digital state machine
 * 
 * Enable the `define STOP_IN_PHI1_D to stop the clocks low for the handover, and omit it to stop in PHI2.
 * 
 * ie for Beeb816 there's not much time to detect whether to switch to the low speed clock when running in a 
 * high speed mode if STOP_ON_PHI1 is selected - this is probably why we defaulted to stopping in PHI2 instead.
 * 
 * In this version 
 * o hsclk = high speed clock
 * o hsclk_by4 = hsclk div 4, alternative for 65816 clock
 * o hsclk_by2 = hsclk div 2, expected to be the 65816 CPU clock 
 * o lsclk = low speed clock
 * 
 * The state machine needs at least a 2x relationship between hsclk and the CPU clock, and assumes that
 * the lsclk is much slower. Clock switching with this version is quicker than with the fully async one,
 * but there is still the same limitation that when stopping in PHI1 (PHI2) the clock selection signal must only 
 * change in PHI1 (PHI2). 
 * 
 * Sample clock must be >= 6x faster than the async BBC clock due to the length of the retiming chain.
 * 
 * Setting stop on PHI1 requires the state machine to wait with clock low until it sees a falling edge on the other clock
 * Setting stop on PHI2 requires the state machine to wait with clock low until it sees a rising edge on the other clock
 * 
 * 
 */

//`define STOP_ON_PHI1_D 1
//`define DIVIDE_BY_4_D 


`ifdef STOP_ON_PHI1_D
  `define CHANGEDGE negedge
`else
  `define CHANGEDGE posedge
`endif


`define LSCLK_HALF_CYCLE 250     // 2MHz mother board clock
`define HSCLK_HALF_CYCLE  30.5   //  16.384MHZ XTAL

`define HSCLK_DIV 2'b00          // Divide by 1
`define CPUCLK_DIV 2'b00         // Divide by 2


module clkctrl2_tb ;

  parameter	  HSRUNNING=2'h0, WAITLSE=2'h1,LSRUNNING=2'h3,WAITHSE=2'h2;

  reg	reset_b_r;
  reg 	lsclk_r;
  reg	hsclk_r;
  reg   hienable_r;

  wire  clkout;
    
  initial
    begin
      $dumpvars();
        
      reset_b_r = 0;
      lsclk_r = 0;
      hsclk_r = 0;  
      hienable_r = 0;
      #500 reset_b_r = 1;
      #2000;

      #2500  @ ( `CHANGEDGE clkout);
      #(`HSCLK_HALF_CYCLE-4) hienable_r = 1;

      #2500  @ ( `CHANGEDGE clkout);
      #(`HSCLK_HALF_CYCLE-4) hienable_r = 0;
      
      #2500  @ ( `CHANGEDGE clkout);
      #(`HSCLK_HALF_CYCLE-4) hienable_r = 1;
      
      #2500  @ ( `CHANGEDGE clkout);
      #(`HSCLK_HALF_CYCLE-4) hienable_r = 0;
      
      #2500  @ ( `CHANGEDGE clkout);
      #(`HSCLK_HALF_CYCLE-4) hienable_r = 1;
      
      #2000 $finish();
    end
  
  always
    #`LSCLK_HALF_CYCLE lsclk_r = !lsclk_r ;
  
  always
    #`HSCLK_HALF_CYCLE hsclk_r = !hsclk_r ;


`ifdef SYNC_SWITCH_D  
  clkctrl2       clkctrl2_u(
                            .hsclk_in(hsclk_r),
                            .lsclk_in(lsclk_r),
                            .rst_b(reset_b_r),
                            .hsclk_sel(hienable_r),
                            .hsclk_div_sel(`HSCLK_DIV),
                            .cpuclk_div_sel(`CPUCLK_DIV),
                            .clkout(clkout)
                );
`else
  clkctrl       clkctrl_u(
                          .hsclk_in(hsclk_r),
                          .lsclk_in(lsclk_r),
                          .rst_b(reset_b_r),
                          .hsclk_sel(hienable_r),
                          .cpuclk_div_sel(`CPUCLK_DIV),
                          .clkout(clkout)
                );
`endif
  
endmodule


