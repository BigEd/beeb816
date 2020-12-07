// Switch stops the clock in the PHI2 state
//

// Number of retiming steps of fast clock for low speed clock enable. Found N=2 to be
// unreliable, but N=3 seems ok in testing ... so use N=4 since it has negligible
// impact on cycle by cycle performance.
`define HS_PIPE_SZ 4

// Number of retiming steps of slow clock for hs clock enable, N must be >= 2
// at higher speeds esp with -15ns parts
//`define SINGLE_LS_RETIMER 1
`define LS_PIPE_SZ 2

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

  reg                     hsclk_by2_q;
  reg                     cpuclk_r;
  reg                     hsclk_by4_q;
  reg                     hs_enable_q, ls_enable_q;
  reg                     selected_ls_q;
  reg                     selected_hs_q;
  reg [`HS_PIPE_SZ-1:0]   pipe_retime_ls_enable_q;
  reg [`LS_PIPE_SZ-1:0]   pipe_retime_hs_enable_q;

  wire                    retimed_ls_enable_w = pipe_retime_ls_enable_q[0];
  wire                    retimed_hs_enable_w = pipe_retime_hs_enable_q[0];

  assign clkout = (cpuclk_r & hs_enable_q) | (lsclk_in & ls_enable_q);
  assign lsclk_selected = selected_ls_q;
  // New state for feedback to clock selection
  assign hsclk_selected = selected_hs_q;

  always @ ( * )
    case (cpuclk_div_sel)
      2'b00 : cpuclk_r = hsclk_in;
      2'b01 : cpuclk_r = hsclk_by2_q;
      2'b10 : cpuclk_r = hsclk_by4_q;
      2'b11 : cpuclk_r = hsclk_by4_q;
      default: cpuclk_r = 1'bx;
    endcase // case (cpuclk_div_sel)

  // Selected LS signal must change on posedge of clock
  always @ (posedge lsclk_in or negedge rst_b)
    if ( ! rst_b )
      selected_ls_q <= 1'b1;
    else
      selected_ls_q <= !hsclk_sel & !retimed_hs_enable_w;

// Edge triggered FF for feedback to clock selection
  always @ ( posedge cpuclk_r or negedge rst_b )
    if ( ! rst_b )
      selected_hs_q <= 1'b0;
    else
      selected_hs_q <= hs_enable_q;

// Make HS enable latch open in 2nd half of cycle, to allow more time
// for selection signal to stabilize. (Remember that clock sense is
// inverted here - first phase is high, second phase is low)
  always @ (  *  )
    if ( !cpuclk_r ) begin
      if ( ! rst_b )
        hs_enable_q <= 1'b0;
      else
        hs_enable_q <= hsclk_sel & !retimed_ls_enable_w;
    end

//  always @ ( negedge cpuclk_r or negedge rst_b )
//    if ( ! rst_b )
//      hs_enable_q <= 1'b0;
//    else
//      hs_enable_q <= hsclk_sel & !retimed_ls_enable_w;

  always @ ( negedge lsclk_in or negedge rst_b )
    if ( ! rst_b )
      ls_enable_q <= 1'b1;
    else
      ls_enable_q <= !hsclk_sel & !retimed_hs_enable_w;

  always @ ( negedge  cpuclk_r or negedge rst_b )
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
      pipe_retime_hs_enable_q <= hsclk_sel;
`else
      pipe_retime_hs_enable_q <= {hsclk_sel, pipe_retime_hs_enable_q[`LS_PIPE_SZ-1:1]};
`endif

  // Clock Dividers
  always @ ( posedge hsclk_in  or negedge rst_b)
    if ( !rst_b )
      hsclk_by2_q <= 1'b0;
    else
      hsclk_by2_q <= !hsclk_by2_q;
`endif

  always @ ( posedge hsclk_by2_q  or negedge rst_b )
    if ( !rst_b )
      hsclk_by4_q <= 1'b0;
    else
      hsclk_by4_q <= !hsclk_by4_q;
`endif
endmodule
