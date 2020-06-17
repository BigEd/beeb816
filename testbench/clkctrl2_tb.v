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
 * Setting stop on PHI1 requires the state machine to wait with clock low until it sees a falling edge on the other clock
 * Setting stop on PHI2 requires the state machine to wait with clock low until it sees a rising edge on the other clock
 * 
 * NB CPLD is not that fast ! The BBC clock is 2MHz. Aiming for, say, a 12 MHz 65816 clock means that the logic here must
 * be running at 48MHz if using a 4X clock for the state machine. That's only a 21ns cycle ! The XC95108s I have available 
 * are rated at 10ns or 15 ns per macrocell. So, maybe running with a 2x high speed (state machine) clock and a 24MHz Xtal/42ns 
 * cycle is more realistic.
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


`define LSCLK_HALF_CYCLE 250  // 2MHz mother board clock
`define HSCLK_HALF_CYCLE  61  // 16.384MHZ XTAL -> 8.192MHz CPU Clock 

module as_edge_detect( clk, din, srst_b, dout);

  // edge detect for significantly slower async clock (less than 1/4 of sampling clock freq)
  // When detecting a rising (falling) edge the reset state of the chain is all-ones (zeroes)
   
  input 	din;
  input		clk;
  input 	srst_b;
  output	dout;

  reg 	r1_q, r2_q, r3_q;

`ifdef STOP_ON_PHI1_D 
  assign dout = r3_q & !r2_q & srst_b;
  always @ ( posedge clk )
    if ( !srst_b)
      { r1_q, r2_q, r3_q} <= 3'b000;      
    else	
      { r1_q, r2_q, r3_q} <= {din, r1_q, r2_q};
`else
  assign dout = !r3_q & r2_q & srst_b;
  always @ ( negedge clk )
    if ( !srst_b)
      { r1_q, r2_q, r3_q} <= 3'b111;          
    else	
      { r1_q, r2_q, r3_q} <= {din, r1_q, r2_q};  
`endif  
endmodule

module s_edge_detect( clk, din, srst_b, dout);

  // edge detect for slightly slower sync clock (sampling freq >= 2x sampled clock freq)
  // When detecting a rising (falling) edge the reset state of the chain is all-ones (zeroes)
  input 	din;
  input		clk;
  input 	srst_b;
  output	dout;

  reg 	r1_q;

`ifdef STOP_ON_PHI1_D
  assign dout = r1_q & !din & srst_b;
  always @ ( posedge clk )
    if ( !srst_b)
      r1_q  <= 0;
    else
      r1_q  <= din;      
`else    
  assign dout = !r1_q & din & srst_b;
  always @ ( negedge clk )
    if ( !srst_b)
      r1_q  <= 1;
    else	
      r1_q  <= din;
`endif
  
endmodule

module clkctrl2_tb ;

  parameter	  HSRUNNING=2'h0, WAITLSE=2'h1,LSRUNNING=2'h3,WAITHSE=2'h2;

  reg	reset_b_r;
  reg	hsclk_by2_r;
  reg 	hsclk_by4_r;  
  reg 	lsclk_r;
  reg	hsclk_r;
  reg   hienable_r;

  reg[1:0] state_q, state_d;

  wire  clkout;
  wire 	loselect_w;
  wire 	hiselect_w;
  wire 	lodetect_w;
  wire 	hidetect_w;
`ifdef DIVIDE_BY_4_D  
  wire 	cpuclk_w = hsclk_by4_r;
`else
  wire 	cpuclk_w = hsclk_by2_r;
`endif
  

  always @ ( *  )
    begin
      case (state_q )
        HSRUNNING: state_d = (hienable_r)? HSRUNNING: WAITLSE;
        WAITLSE: state_d = ( lodetect_w ) ? LSRUNNING : WAITLSE; 
        LSRUNNING: state_d = (!hienable_r)? LSRUNNING: WAITHSE;
        WAITHSE: state_d = ( hidetect_w ) ? HSRUNNING : WAITHSE;
      endcase;
    end

`ifdef STOP_ON_PHI1_D
  always @ ( posedge hsclk_r or negedge reset_b_r )
`else    
  always @ ( negedge hsclk_r or negedge reset_b_r )
`endif
    if ( !reset_b_r )
      state_q <= LSRUNNING;
    else
      state_q <= state_d;
  
`ifdef STOP_ON_PHI1_D  
  assign clkout = ( (state_q==HSRUNNING) & hienable_r & cpuclk_w ) | ((state_q==LSRUNNING) & !hienable_r & lsclk_r);
`else
  assign clkout = ( !(state_q==HSRUNNING) | !hienable_r | cpuclk_w ) & (!(state_q==LSRUNNING) | hienable_r | lsclk_r);
`endif
  
  initial
    begin

      $dumpvars();
        
      reset_b_r = 0;
      lsclk_r = 0;
      hsclk_r = 0;  
      hienable_r = 0;
      #500 reset_b_r = 1;
      #2000;


      // Always need to wait for the right edge to select a change
      // - ie if stopping in PHI1 then enable must be asserted in PHI1
      // - ie if stopping in PHI2 then enable must be asserted in PHI2
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
  
  
  always @ (negedge reset_b_r or posedge hsclk_r )
    if ( !reset_b_r)
      { hsclk_by2_r, hsclk_by4_r } <= 0;
    else		
      begin
        hsclk_by2_r <= !hsclk_by2_r;
        hsclk_by4_r <= hsclk_by2_r ^ hsclk_by4_r;
      end

  as_edge_detect as_detect_u ( hsclk_r , lsclk_r,   reset_b_r & (state_q==WAITLSE) , lodetect_w);
  s_edge_detect   s_detect_u  ( hsclk_r , cpuclk_w, reset_b_r & (state_q==WAITHSE), hidetect_w);  
  
endmodule


