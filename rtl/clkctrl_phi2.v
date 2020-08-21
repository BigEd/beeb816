// Enabling on the LS clock is always done via a FF, because it's easy to compute the HIMEM state in
// half the LS clock period.
//
// Switch stops the clock in the PHI2 state
//

// Use only a single bit retiming for the slow domain, since there is a second FF
// in both the enable path and the clock-selected path, so at least a slow clock
// phase to resolve any meta-stability (ie 1 slow clock phase is still >> several
// fast clock phases resolving in the other direction)
`define SINGLE_FF_SLOW_RETIMER 1

// Define this to give a full clock cycle for the metastability resolution in stage 1 of the slow clock
// retiming circuit, otherwise a pos edge flop is used as the first stage giving half a cycle for the
// metastability to resolve. This is enough (tested on the BBC) and anyway is still longer than the
// corresponding HS clock cycle has for the same purpose switching the other way.
// `define ALL_NEGEDGE_SLOW_PIPE 1

`ifdef SINGLE_FF_SLOW_RETIMER
  `define PIPE_SZ 1
`else
  `define PIPE_SZ 2
`endif

// Make resync to HS as long as half a slow clock cycle
`define LONG_PIPE_SZ 10

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

  reg                     hsclk_by2_q, hsclk_by4_q, hsclk_by8_q;
  reg                     cpuclk_r;
  reg                     hs_enable_q, ls_enable_q;
  reg                     selected_ls_q, selected_hs_q;
  reg [`LONG_PIPE_SZ-1:0] pipe_retime_ls_enable_q;
  reg [`PIPE_SZ-1:0]      pipe_retime_hs_enable_q;

  wire                    retimed_ls_enable_w = pipe_retime_ls_enable_q[0];
  wire                    retimed_hs_enable_w = pipe_retime_hs_enable_q[0];

  assign clkout = (cpuclk_r & hs_enable_q ) | (lsclk_in & ls_enable_q);

  assign lsclk_selected = selected_ls_q;
  assign hsclk_selected = selected_hs_q;

  always @ ( * )
    case (cpuclk_div_sel)
      2'b00 : cpuclk_r = hsclk_in;
      2'b01 : cpuclk_r = hsclk_by2_q;
      2'b10 : cpuclk_r = hsclk_by4_q;
      2'b11 : cpuclk_r = hsclk_by8_q;
      default: cpuclk_r = 1'bx;
    endcase // case (cpuclk_div_sel)

  // The 'status' returned needs to be edge triggered for use in a feedback loop
  always @ (posedge lsclk_in or negedge rst_b)
    if ( ! rst_b )
      selected_ls_q <= 1'b0;
    else
      selected_ls_q <= !hsclk_sel & !retimed_hs_enable_w;

  always @ (posedge cpuclk_r or negedge rst_b)
    if ( ! rst_b )
      selected_hs_q <= 1'b0;
    else
      selected_hs_q <= hsclk_sel & !retimed_ls_enable_w;

  always @ ( negedge cpuclk_r or negedge rst_b )
    if ( ! rst_b )
      hs_enable_q <= 1'b0;
    else
      hs_enable_q <= hsclk_sel & !retimed_ls_enable_w;

  always @ ( negedge lsclk_in or negedge rst_b )
    if ( ! rst_b )
      ls_enable_q <= 1'b1;
    else
      ls_enable_q <= !hsclk_sel & !retimed_hs_enable_w;

  always @ ( negedge  cpuclk_r or posedge ls_enable_q or negedge rst_b )
    if ( ! rst_b )
      pipe_retime_ls_enable_q <= {`LONG_PIPE_SZ{1'b1}};
    else if ( ls_enable_q )
      pipe_retime_ls_enable_q <= {`LONG_PIPE_SZ{1'b1}};
    else
      pipe_retime_ls_enable_q <= {1'b0, pipe_retime_ls_enable_q[`LONG_PIPE_SZ-1:1]};

`ifdef SINGLE_FF_SLOW_RETIMER
  always @ ( negedge  lsclk_in or posedge hs_enable_q or negedge rst_b )
    if ( ! rst_b )
      pipe_retime_hs_enable_q[0] <= 1'b0;
    else if ( hs_enable_q )
      pipe_retime_hs_enable_q[0] <= 1'b1;
    else
      pipe_retime_hs_enable_q[0] <= 1'b0;
`else         
`ifdef ALL_NEGEDGE_SLOW_PIPE
  always @ ( negedge  lsclk_in or posedge hs_enable_q or negedge rst_b )
    if ( ! rst_b )
      pipe_retime_hs_enable_q <= {`PIPE_SZ{1'b0}};
    else if ( hs_enable_q )
      pipe_retime_hs_enable_q <= {`PIPE_SZ{1'b1}};
    else
      pipe_retime_hs_enable_q <= {1'b0, pipe_retime_hs_enable_q[`PIPE_SZ-1:1]};
`else
  always @ ( posedge  lsclk_in or posedge hs_enable_q or negedge rst_b )
    if ( ! rst_b )
      pipe_retime_hs_enable_q[1] <= 1'b0;
    else if ( hs_enable_q )
      pipe_retime_hs_enable_q[1] <= 1'b1;
    else
      pipe_retime_hs_enable_q[1] <= 1'b0;
  
  always @ ( negedge  lsclk_in or posedge hs_enable_q or negedge rst_b )
    if ( ! rst_b )
      pipe_retime_hs_enable_q[0] <= 1'b0;
    else if ( hs_enable_q )
      pipe_retime_hs_enable_q[0] <= 1'b1;
    else
      pipe_retime_hs_enable_q[0] <= pipe_retime_hs_enable_q[1];
`endif         
`endif // !`ifdef SINGLE_FF_SLOW_RETIMER
  
  // Clock Dividers
  always @ ( posedge hsclk_in  or negedge rst_b)
    if ( !rst_b )
      hsclk_by2_q <= 1'b0;
    else
      hsclk_by2_q <= !hsclk_by2_q;

  always @ ( posedge hsclk_by2_q  or negedge rst_b )
    if ( !rst_b )
      hsclk_by4_q <= 1'b0;
    else
      hsclk_by4_q <= !hsclk_by4_q;

  always @ ( posedge hsclk_by4_q  or negedge rst_b )
    if ( !rst_b )
      hsclk_by8_q <= 1'b0;
    else
      hsclk_by8_q <= !hsclk_by8_q;

endmodule
