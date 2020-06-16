`timescale 1ns/1ns

/*
 * Trial test bench for clock switching between two asynchronous clocks
 * 
 * Enable the `define STOP_IN_PHI1_D to stop the clocks low for the handover, and omit it to stop in PHI2.
 * 
 * When stopping in PHI1 the clock selection signal must only change in PHI1. Similarly if stopping in PHI2 the
 * selection signal must change only in PHI2.
 * 
 * ie for Beeb816 there's not much time to detect whether to switch to the low speed clock when running in a 
 * high speed mode if STOP_ON_PHI1 is selected - this is probably why we defaulted to stopping in PHI2 instead.
 * 
 * /



//`define STOP_IN_PHI1_D 1


`ifdef STOP_IN_PHI1_D
  // to stop in PHI1 enable must be asserted with clock low
  `define CHANGEDGE negedge
`else
  // to stop in PHI2 enable must be asserted with clock high
  `define CHANGEDGE posedge
`endif

`define LSCLK_HALF_CYCLE 500
`define HSCLK_HALF_CYCLE  30

module retimer(clk, din, rst_b, dout);
  input din;
  input clk;
  input rst_b;
  output dout;

  reg r1_q, r2_q;
 
  assign dout = r2_q & din;
 
  always @ ( `CHANGEDGE clk or negedge rst_b )
    if ( !rst_b)
      { r1_q, r2_q} <= 0;
    else
      { r1_q, r2_q} <= {din, r1_q};

endmodule

module clkctrl_tb ;


  reg reset_b_r;
  reg hsclk_by2_r;
  reg hsclk_by4_r;  
  reg lsclk_r;
  reg hsclk_r;
  reg   hienable_r;


  wire  clkout;
  wire loselect_w;
  wire hiselect_w;
  wire cpuclk_w;


`ifdef STOP_IN_PHI1_D  
  assign clkout = (hiselect_w & hienable_r & hsclk_by4_r ) | (!hienable_r & loselect_w & lsclk_r);
`else
  assign clkout = (!hiselect_w | !hienable_r | hsclk_by4_r ) & (hienable_r | !loselect_w | lsclk_r);
`endif  
 
  initial
    begin

      $dumpvars();
       
      reset_b_r = 0;
      lsclk_r = 0;
      hsclk_r = 0;  
      hienable_r = 0;
      #500 reset_b_r = 1;

      #2500  @ ( `CHANGEDGE clkout);
      #10 hienable_r = 1;

      #2500  @ ( `CHANGEDGE clkout);
      #10 hienable_r = 0;

      #2500  @ ( `CHANGEDGE clkout);
      #25 hienable_r = 1;
     
      #10000 $finish();
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

  retimer  ls_retime ( lsclk_r, !hienable_r & !hiselect_w, reset_b_r, loselect_w);
  retimer  hs_retime ( hsclk_by4_r, hienable_r & !loselect_w, reset_b_r, hiselect_w);  
 
endmodule
