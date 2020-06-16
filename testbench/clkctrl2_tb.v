`timescale 1ns/1ns

/*
 * Trial test bench for clock switching between two asynchronous clocks, but where one clock is synchronous to a much
 * higher speed clock which is used to control the digital state machine
 * 
 * Enable the `define STOP_IN_PHI1_D to stop the clocks low for the handover, and omit it to stop in PHI2.
 * 
 * 
 * ie for Beeb816 there's not much time to detect whether to switch to the low speed clock when running in a 
 * high speed mode if STOP_ON_PHI1 is selected - this is probably why we defaulted to stopping in PHI2 instead.
 * 
 * In this version 
 * o hsclk = high speed clock
 * o hsclk_by4 = hsclk div 4, expected to be the 65816 CPU clock
 * o lsclk = low speed clock
 * 
 * The state machine needs at least a 4x relationship between hsclk and the CPU clock, and assumes that
 * the lsclk is much slower. Clock switching with this version is quicker than with the fully async one,
 * but there is still the same limitation that when stopping in PHI1 (PHI2) the clock selection signal must only 
 * change in PHI1 (PHI2). 
 * 
 */

//`define STOP_ON_PHI1_D 1
`ifdef STOP_ON_PHI1_D
  `define CHANGEDGE negedge
  `define DETECTEDGE negedge
`else
  `define CHANGEDGE posedge
  `define DETECTEDGE posedge
`endif


`define LSCLK_HALF_CYCLE 450
`define HSCLK_HALF_CYCLE  66


module as_edge_detect( clk, din, rst_b, dout);

  // edge detect for significantly slower async clock (less than 1/4 freq)
  input din;
  input clk;
  input rst_b;
  output dout;

  reg r1_q, r2_q, r3_q;

`ifdef STOP_ON_PHI1_D
  assign dout = r3_q & !r2_q;
`else
  assign dout = !r3_q & r2_q;
`endif 
  always @ ( posedge clk or negedge rst_b )
    if ( !rst_b)
      { r1_q, r2_q, r3_q} <= 3'b0;
    else
      { r1_q, r2_q, r3_q} <= {din, r1_q, r2_q};

endmodule

module s_edge_detect( clk, din, rst_b, dout);

  // edge detect for slightly slower sync clock (at least 1/4)
  input din;
  input clk;
  input rst_b;
  output dout;

  reg r1_q;

`ifdef STOP_ON_PHI1_D
  assign dout = r1_q & !din;
`else 
  assign dout = !r1_q & din;
`endif

  always @ ( posedge clk or negedge rst_b )
    if ( !rst_b)
      r1_q  <= 0;
    else
      r1_q  <= din;

endmodule



module clkctrl2_tb ;

  parameter   HSRUNNING=3'h0, KILLHS=3'h1, WAITLSE=3'h3,LSRUNNING=3'h7,KILLLS=3'h6,WAITHSE=3'h4;

  reg reset_b_r;
  reg hsclk_by2_r;
  reg hsclk_by4_r; 
  reg lsclk_r;
  reg hsclk_r;
  reg   hienable_r;

  reg[2:0] state_q, state_d;

  wire  clkout;
  wire loselect_w;
  wire hiselect_w;
  wire lodetect_w;
  wire hidetect_w;
  wire cpuclk_w;

  always @ ( *  )
    begin
      case (state_q )
        HSRUNNING: state_d = (hienable_r)? HSRUNNING: KILLHS;
        KILLHS: state_d = WAITLSE;
        WAITLSE: state_d = ( lodetect_w ) ? LSRUNNING : WAITLSE;
        LSRUNNING: state_d = (!hienable_r)? LSRUNNING: KILLLS;
        KILLLS: state_d = WAITHSE;
        WAITHSE: state_d = ( hidetect_w ) ? HSRUNNING : WAITHSE;
        default: state_d = LSRUNNING;
      endcase;
    end

  always @ ( posedge hsclk_r or negedge reset_b_r )
    if ( !reset_b_r )
      state_q <= LSRUNNING;
    else
      state_q <= state_d;

`ifdef STOP_ON_PHI1_D 
  assign clkout = ( (state_q==HSRUNNING) & hienable_r & hsclk_by4_r ) | ((state_q==LSRUNNING) & !hienable_r & lsclk_r);
`else
  assign clkout = ( !(state_q==HSRUNNING) | !hienable_r | hsclk_by4_r ) & (!(state_q==LSRUNNING) | hienable_r | lsclk_r);
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

      #2500  @ ( `CHANGEDGE clkout);
      #13 hienable_r = 1;

      #2500  @ ( `CHANGEDGE clkout);
      #27 hienable_r = 0;

      #2500  @ ( `CHANGEDGE clkout);
      #27 hienable_r = 1;

      #2500  @ ( `CHANGEDGE clkout);
      #13 hienable_r = 0;

      #2500  @ ( `CHANGEDGE clkout);
      #13 hienable_r = 1;

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

  as_edge_detect as_detect_u ( hsclk_r , lsclk_r,     reset_b_r  , lodetect_w);
  s_edge_detect   s_detect_u  ( hsclk_r , hsclk_by4_r, reset_b_r , hidetect_w); 

endmodule
