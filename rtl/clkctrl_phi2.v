// Switch stops the clock in the PHI2 state
//

// Number of retiming steps of fast clock for low speed clock enable. Found N=2 to be
// unreliable, but N=3 seems ok in testing ... so use N=4 since it has negligible
// impact on cycle by cycle performance.
`define HS_PIPE_SZ 4

// Number of retiming steps of slow clock for hs clock enable, N must be >= 2
// at higher speeds esp with -15ns parts
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

  reg                     hs_enable_q, ls_enable_q;
  reg                     selected_ls_q;
  reg [`HS_PIPE_SZ-1:0]   pipe_retime_ls_enable_q;
  reg [`LS_PIPE_SZ-1:0]   pipe_retime_hs_enable_q;
  reg [1:0]               clk_div_q;

  wire                    retimed_ls_enable_w = pipe_retime_ls_enable_q[0];
  wire                    retimed_hs_enable_w = pipe_retime_hs_enable_q[0];
  wire                    cpuclk_w = ( |cpuclk_div_sel ) ? clk_div_q[0] : hsclk_in;

  assign clkout = (cpuclk_w & hs_enable_q) | (lsclk_in & ls_enable_q);
  assign lsclk_selected = selected_ls_q;
  assign hsclk_selected = hs_enable_q;

  // Selected LS signal must change on posedge of clock
  always @ (posedge lsclk_in or negedge rst_b)
    if ( ! rst_b )
      selected_ls_q <= 1'b1;
    else
      selected_ls_q <= !hsclk_sel & !retimed_hs_enable_w;

  always @ ( negedge cpuclk_w or negedge rst_b )
    if ( ! rst_b )
      hs_enable_q <= 1'b0;
    else
      hs_enable_q <= hsclk_sel & !retimed_ls_enable_w;

  always @ ( negedge lsclk_in or negedge rst_b )
    if ( ! rst_b )
      ls_enable_q <= 1'b1;
    else
      ls_enable_q <= !hsclk_sel & !retimed_hs_enable_w;

  always @ ( negedge  cpuclk_w or negedge rst_b ) begin
    if ( ! rst_b )
      pipe_retime_ls_enable_q <= {`HS_PIPE_SZ{1'b1}};
    else begin
      if ( ls_enable_q )
        pipe_retime_ls_enable_q <= {`HS_PIPE_SZ{1'b1}};
      else
        pipe_retime_ls_enable_q <= {!pipe_retime_hs_enable_q[0], pipe_retime_ls_enable_q[`HS_PIPE_SZ-1:1]};
    end
  end


  always @ ( negedge  lsclk_in or posedge hs_enable_q ) begin
    if ( hs_enable_q )
      pipe_retime_hs_enable_q <= {`LS_PIPE_SZ{1'b1}};
    else
      pipe_retime_hs_enable_q <= {hsclk_sel, pipe_retime_hs_enable_q[`LS_PIPE_SZ-1:1]};
   end


  always @ ( posedge hsclk_in  or negedge rst_b) begin
    if ( !rst_b )
      clk_div_q <= 0;
    else begin
      clk_div_q[0] <= ( cpuclk_div_sel == 2'b01 ) ? !clk_div_q[0] : clk_div_q[1];
      clk_div_q[1] <= !clk_div_q[0] ;
    end
  end

endmodule
