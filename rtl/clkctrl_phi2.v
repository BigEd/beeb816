// Switch stops the clock in the PHI2 state
//
// Use only a single bit retiming for the slow domain, since there is a second FF
// in both the enable path and the clock-selected path, so at least one slow clock
// cycle to resolve any meta-stability (ie 1 slow clock cycle is still >> several
// fast clock phases resolving in the other direction)
//
// Defining this allows a full LS clock cycle for resolving MS, but needs an extra
// flop for the ls_selected signal. Leaving this undefined allows only a 1/2 cycle
// (one phase) of LS clk. The XC95108-10 seems fine with this undefined, but the -15
// parts run at higher MHz if the additional 1/2 cycle is allowed.
`define RETIME_ON_NEGEDGE 1

// Number of retiming steps of fast clock for low speed clock enable. Found 2 to be
// slightly unreliable, but 3 is fine.
`define HS_PIPE_SZ 3

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
  reg                     selected_ls_q;
`ifdef RETIME_ON_NEGEDGE
  reg                     selected_hs_q;
`endif  
  reg [`HS_PIPE_SZ-1:0]   pipe_retime_ls_enable_q;
  reg                     pipe_retime_hs_enable_q;

  wire                    retimed_ls_enable_w = pipe_retime_ls_enable_q[0];
  wire                    retimed_hs_enable_w = pipe_retime_hs_enable_q;

  assign clkout = (cpuclk_r & hs_enable_q ) | (lsclk_in & ls_enable_q);

  // LS selected is computed on pos edge of retiming pipe same as the enable
`ifdef RETIME_ON_NEGEDGE
  assign lsclk_selected = selected_ls_q;  
`else
  assign lsclk_selected = !hsclk_sel & !pipe_retime_hs_enable_q ;
`endif  
  assign hsclk_selected = selected_hs_q;

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

`ifdef RETIME_ON_NEGEDGE  
  // LS select is computed on pos edge, but enable is running on negedge (ie 1/2 cycle behind)
  // so that the select signal can be used externally to modify the address/rnw etc
  always @ (posedge lsclk_in or negedge rst_b)
    if ( ! rst_b )
      selected_ls_q <= 1'b0;
    else
      selected_ls_q <= !hsclk_sel & !retimed_hs_enable_w;
`endif
  
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
  // 3 FFs here in practice with a whole cycle between each and then the 1/2
  // cycle to the negedge enable FF. If changing this chain to posedge then
  // the 'selected_hs_q' logic needs to change with it.
  always @ ( negedge  cpuclk_r or posedge ls_enable_q or negedge rst_b )
    if ( ! rst_b )
      pipe_retime_ls_enable_q <= {`HS_PIPE_SZ{1'b1}};
    else if ( ls_enable_q )
      pipe_retime_ls_enable_q <= {`HS_PIPE_SZ{1'b1}};
    else
      pipe_retime_ls_enable_q <= {1'b0, pipe_retime_ls_enable_q[`HS_PIPE_SZ-1:1]};
         
  // Use negedge for single cycle lsclk retiming of HS enable, or posedge
  // to allow only a 1/2 cycle. The full cycle is better for -15ns parts
  // at higher clock speeds         
`ifdef RETIME_ON_NEGEDGE
  always @ ( negedge  lsclk_in or posedge hs_enable_q or negedge rst_b )
`else         
  always @ ( posedge  lsclk_in or posedge hs_enable_q or negedge rst_b )
`endif    
    if ( ! rst_b )
      pipe_retime_hs_enable_q <= 1'b0;
    else if ( hs_enable_q )
      pipe_retime_hs_enable_q <= 1'b1;
    else
      pipe_retime_hs_enable_q <= hsclk_sel;

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
