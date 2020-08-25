// Switch stops the clock in the PHI2 state
//

// Number of retiming steps of fast clock for low speed clock enable. Found N=2 to be
// unreliable, but N=3 seems ok in testing ... so use N=4 since it has negligible
// impact on cycle by cycle performance.
`define HS_PIPE_SZ 4

// Number of retiming steps of slow clock for hs clock enable, N must be >= 2. If using
// LS_RETIME_ON_POSEDGE then actual retiming is N-0.5 cycles for a slight improvement in
// cycle count, but with a half-cycle path in the last retiming stage. The XC95108-15
// (15ns) parts need the full cycle to be able to run with a 16.65MHz clock, but are ok
// with 15MHz and lower with this `define set. Use a pipe size of 3 for the -15 parts, but
// 2 or even 1 is ok for the -10s
//
//`define LS_RETIME_ON_POSEDGE 1
`define LS_PIPE_SZ 3

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
  reg                     selected_hs_q;
  reg [`HS_PIPE_SZ-1:0]   pipe_retime_ls_enable_q;
  reg [`LS_PIPE_SZ-1:0]   pipe_retime_hs_enable_q;

  wire                    retimed_ls_enable_w = pipe_retime_ls_enable_q[0];
  wire                    retimed_hs_enable_w = pipe_retime_hs_enable_q[0];

  assign clkout = (cpuclk_r & hs_enable_q ) | (lsclk_in & ls_enable_q);
  assign hsclk_selected = selected_hs_q;

`ifdef LS_RETIME_ON_POSEDGE
  // LS selected is computed on pos edge of retiming pipe same as the enable  
  assign lsclk_selected = !hsclk_sel & !pipe_retime_hs_enable_q[0] ;
`else
  reg                     selected_ls_q;
  assign lsclk_selected = selected_ls_q;  
`endif  

  always @ ( * )
    case (cpuclk_div_sel)
      2'b00 : cpuclk_r = hsclk_in;
      2'b01 : cpuclk_r = hsclk_by2_q;
      2'b10 : cpuclk_r = hsclk_by4_q;
      2'b11 : cpuclk_r = hsclk_by8_q;
      default: cpuclk_r = 1'bx;
    endcase // case (cpuclk_div_sel)

  // HS select is computed on pos edge, but enable is running on negedge (ie 1/2 cycle behind)
  // so that the select signal can be used externally to modify the address/rnw etc
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

  // Use negedge for multi-cycle hsclk retiming of LS enable - need at least
  // 3 FFs here in practice. If changing this chain to posedge then
  // the 'selected_hs_q' logic needs to change with it.
  always @ ( negedge  cpuclk_r or posedge ls_enable_q or negedge rst_b )
    if ( ! rst_b )
      pipe_retime_ls_enable_q <= {`HS_PIPE_SZ{1'b1}};
    else if ( ls_enable_q )
      pipe_retime_ls_enable_q <= {`HS_PIPE_SZ{1'b1}};
    else
      pipe_retime_ls_enable_q <= {!hsclk_sel, pipe_retime_ls_enable_q[`HS_PIPE_SZ-1:1]};
         
`ifdef LS_RETIME_ON_POSEDGE
  always @ ( posedge  lsclk_in or posedge hs_enable_q or negedge rst_b )
`else
  // LS select is computed on pos edge, but enable is running on negedge (ie 1/2 cycle behind)
  // so that the select signal can be used externally to modify the address/rnw etc
  always @ (posedge lsclk_in or negedge rst_b)
    if ( ! rst_b )
      selected_ls_q <= 1'b0;
    else
      selected_ls_q <= !hsclk_sel & !retimed_hs_enable_w;
    
  always @ ( negedge  lsclk_in or posedge hs_enable_q or negedge rst_b )
`endif    
    if ( ! rst_b )
      pipe_retime_hs_enable_q <= `LS_PIPE_SZ'b0;
    else if ( hs_enable_q )
      pipe_retime_hs_enable_q <= {`LS_PIPE_SZ{1'b1}};
    else
      pipe_retime_hs_enable_q <= {hsclk_sel, pipe_retime_hs_enable_q[`LS_PIPE_SZ-1:1]};
  
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
