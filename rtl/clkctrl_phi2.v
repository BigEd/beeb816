// Switch stops the clock in the PHI2 state
//

// Number of retiming steps of fast clock for low speed clock enable.
`define HS_PIPE_SZ 4

// Define this to use a latch open in second half of clock cycle to allow more time for
// clock selection decision. If undefined then clock decision is FF'd on leading edge
// of PHI2
`define USE_LATCH_ON_CLKSEL 1

// Size of clock delay pipe - needs to be 2 for the Master but 3 for BBC /Elk ? TBC
`define CLKDEL_PIPE_SZ 3

module clkctrl_phi2(
               input       hsclk_in,
               input       lsclk_in,
               input       rst_b,
               input       hsclk_sel,
               input [1:0] cpuclk_div_sel,
               output      hsclk_selected,
               output      lsclk_selected,
               output      clkout
               );

  reg [2:0]                clkdiv_q;
  reg [2:0]                clkdiv_d;
  reg                      hs_enable_q, ls_enable_q;
  reg                      selected_ls_q;
  reg                      selected_hs_q;
  reg [`HS_PIPE_SZ-1:0]    retimed_ls_enable_q;
  reg                      retimed_hs_enable_q;
  reg [`CLKDEL_PIPE_SZ-1:0] del_q;
  wire                      retimed_ls_enable_w = retimed_ls_enable_q[0];
  wire                      retimed_hs_enable_w = retimed_hs_enable_q;

  // Force Keep clock nets to prevent ISE merging divider logic into other equations and
  // causing timing issues
  (* KEEP="TRUE" *) wire  cpuclk_w;
  (* KEEP="TRUE" *) wire  lsclk_del_w;
  BUF cpuclkbuf  ( .O(cpuclk_w), .I(clkdiv_q[0]));
  BUF lsclkbuf   ( .O(lsclk_del_w), .I(del_q[0]));

  assign clkout = (cpuclk_w & hs_enable_q) | (lsclk_del_w & ls_enable_q);
  assign lsclk_selected = selected_ls_q;
  assign hsclk_selected = selected_hs_q;

  // Delay the host clock to match delays on the motherboard
  always @ (posedge hsclk_in) begin
    del_q <= { lsclk_in, del_q[`CLKDEL_PIPE_SZ-1:1]};
  end

  // Selected LS signal must change on posedge of clock
  always @ (posedge lsclk_del_w or negedge rst_b)
    if ( ! rst_b )
      selected_ls_q <= 1'b1;
    else
      selected_ls_q <= !hsclk_sel & !retimed_hs_enable_w;

  // Edge triggered FF for feedback to clock selection
  always @ ( posedge cpuclk_w or negedge rst_b )
    if ( ! rst_b )
      selected_hs_q <= 1'b0;
    else
      selected_hs_q <= hs_enable_q;

`ifdef USE_LATCH_ON_CLKSEL
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

  always @ ( negedge lsclk_del_w or negedge rst_b )
    if ( ! rst_b )
      ls_enable_q <= 1'b1;
    else
      ls_enable_q <= !hsclk_sel & !retimed_hs_enable_w;

  always @ ( negedge  lsclk_del_w or posedge hs_enable_q )
    if ( hs_enable_q )
      retimed_hs_enable_q <= 1'b1;
    else
      retimed_hs_enable_q <= 1'b0;

  always @ ( negedge cpuclk_w )
    if (ls_enable_q)
      retimed_ls_enable_q <= {`HS_PIPE_SZ{1'b1}};
    else
      retimed_ls_enable_q <= {1'b0, retimed_ls_enable_q[`HS_PIPE_SZ-1:1]};

  // Clock Dividers
  always @ ( * ) begin
    clkdiv_d[2] = !clkdiv_q[0] ;
    clkdiv_d[1] = (cpuclk_div_sel == 2'b01) ? !clkdiv_q[0] : clkdiv_q[2];
    clkdiv_d[0] = (cpuclk_div_sel == 2'b00) ? !clkdiv_q[0] : clkdiv_q[1];
  end

  always @ ( posedge hsclk_in or negedge rst_b)
    if ( !rst_b)
      clkdiv_q <= 3'b0;
    else
      clkdiv_q <= clkdiv_d;

endmodule
