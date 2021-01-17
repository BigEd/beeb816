// Switch stops the clock in the PHI2 state
//

// Number of retiming steps of fast clock for low speed clock enable. Found N=2 to be
// unreliable, but N=3 seems ok in testing ... so use N=4 since it has negligible
// impact on cycle by cycle performance. (NB (depth of pipeline+1) must be >= 1 phase of slow clock
// for correct logical operation.)
`define HS_PIPE_SZ 4

// Number of retiming steps of slow clock for hs clock enable.
// 1 Retiming stage seems to work on slow clock - 2 might be safer
`define SINGLE_LS_RETIMER 1
`ifdef SINGLE_LS_RETIMER
  `define LS_PIPE_SZ 1
`else
  `define LS_PIPE_SZ 2
`endif

// Define this to assert RDY each time a clock switch is made
//`define ASSERT_RDY_ON_CLKSW 1
// Define this to use a latch open in second half of clock cycle to allow more time for
// clock selection decision. If undefined then clock decision is FF'd on leading edge
// of PHI2
`define USE_LATCH_ON_CLKSEL 1

module clkctrl_phi2(
               input       hsclk_in,
               input       lsclk_in,
               input       rst_b,
               input       hsclk_sel,
               input [1:0] cpuclk_div_sel,
               output      rdy,
               output      hsclk_selected,
               output      lsclk_selected,
               output      clkout
               );

  reg [1:0]               clkdiv_q;
  reg                     hs_enable_q, ls_enable_q;
  reg                     selected_ls_q;
  reg                     selected_hs_q;
  reg [`HS_PIPE_SZ-1:0]   pipe_retime_ls_enable_q;
  reg [`LS_PIPE_SZ-1:0]   pipe_retime_hs_enable_q;
  wire                    retimed_ls_enable_w = pipe_retime_ls_enable_q[0];
  wire                    retimed_hs_enable_w = pipe_retime_hs_enable_q[0];
  wire                    div2not4_w = (cpuclk_div_sel == 2'b01);
  wire                    cpuclk_w;

  assign clkout = (cpuclk_w & hs_enable_q) | (lsclk_in & ls_enable_q);
  assign lsclk_selected = selected_ls_q;

`ifdef ASSERT_RDY_ON_CLKSW
  assign rdy = (hsclk_sel == hsclk_selected);
`else
  assign rdy = 1'b1;
`endif

`ifdef USE_LATCH_ON_CLKSEL
  // New state for feedback to clock selection
  assign hsclk_selected = selected_hs_q;
`else
  assign hsclk_selected = hs_enable_q;
`endif
  assign cpuclk_w = (cpuclk_div_sel==2'b00)? hsclk_in : clkdiv_q[0];

  // Selected LS signal must change on posedge of clock
  always @ (posedge lsclk_in or negedge rst_b)
    if ( ! rst_b )
      selected_ls_q <= 1'b1;
    else
      selected_ls_q <= !hsclk_sel & !retimed_hs_enable_w;

`ifdef USE_LATCH_ON_CLKSEL
  // Edge triggered FF for feedback to clock selection
  always @ ( posedge cpuclk_w or negedge rst_b )
    if ( ! rst_b )
      selected_hs_q <= 1'b0;
    else
      selected_hs_q <= hs_enable_q;

  // Make HS enable latch open in 2nd half of cycle, to allow more time
  // for selection signal to stabilize. (Remember that clock sense is
  // inverted here - first phase is high, second phase is low)
  always @ (  *  )
    if ( !cpuclk_w ) begin
      if ( ! rst_b )
        hs_enable_q <= 1'b0;
      else
        hs_enable_q <= hsclk_sel & !retimed_ls_enable_w;
    end
`else
  always @ ( negedge cpuclk_w or negedge rst_b )
    if ( ! rst_b )
      hs_enable_q <= 1'b0;
    else
      hs_enable_q <= hsclk_sel & !retimed_ls_enable_w;
`endif

  always @ ( negedge lsclk_in or negedge rst_b )
    if ( ! rst_b )
      ls_enable_q <= 1'b1;
    else
      ls_enable_q <= !hsclk_sel & !retimed_hs_enable_w;

  always @ ( negedge  cpuclk_w or negedge rst_b )
    if ( ! rst_b )
      pipe_retime_ls_enable_q <= {`HS_PIPE_SZ{1'b1}};
    else
      if ( ls_enable_q )
        pipe_retime_ls_enable_q <= {`HS_PIPE_SZ{1'b1}};
      else
        pipe_retime_ls_enable_q <= {!pipe_retime_hs_enable_q[0], pipe_retime_ls_enable_q[`HS_PIPE_SZ-1:1]};

  always @ ( negedge  lsclk_in or posedge hs_enable_q )
    if ( hs_enable_q )
      pipe_retime_hs_enable_q <= {`LS_PIPE_SZ{1'b1}};
    else
`ifdef SINGLE_LS_RETIMER
      pipe_retime_hs_enable_q <= {`LS_PIPE_SZ{hsclk_sel}};
`else
      pipe_retime_hs_enable_q <= {hsclk_sel, pipe_retime_hs_enable_q[`LS_PIPE_SZ-1:1]};
`endif

  // Clock Dividers
  always @ ( posedge hsclk_in  or negedge rst_b)
    if ( !rst_b )
      clkdiv_q <= 2'b00;
    else
      clkdiv_q <= { !clkdiv_q[0], (div2not4_w) ? !clkdiv_q[0]: clkdiv_q[1]};

endmodule
