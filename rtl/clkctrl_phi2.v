// Switch stops the clock in the PHI2 state

// Size of clock delay pipe - needs to be 0 for the Master but 2 or 3 for BBC /Elk depending on xtal
`define CLKDEL_PIPE_SZ 3

// Select this to use the /2 and /3 rather than /2 and /4
//`define USE_DIVIDER_234

// Use this to get a latch on the HS clock enable rather than a FF
//`define USE_LATCH_ENABLE 1

`ifdef USE_DIVIDER_234
  `define USE_LATCH_ENABLE 1
`endif


module clkctrl_phi2(
               input       hsclk_in,
               input       lsclk_in,
               input       rst_b,
               input       hsclk_sel,
               input       delay_sel,
               input       cpuclk_div_sel,
               output      hsclk_selected,
               output      lsclk_selected,
               output      clkout
               );

  reg                      hs_enable_q, ls_enable_q;
  reg                      selected_ls_q;
  reg                      selected_hs_q;
  reg                      retimed_ls_enable_q;
  reg                      retimed_hs_enable_q;
  reg [`CLKDEL_PIPE_SZ-1:0] del_q;

  // Force Keep clock nets to prevent ISE merging divider logic into other equations and
  // causing timing issues
  (* KEEP="TRUE" *) wire  cpuclk_w;
  (* KEEP="TRUE" *) wire  lsclk_del_w;
  // Faster XTAL speeds need a longer delay line
  assign lsclk_del_w = (delay_sel) ? del_q[0] : del_q[1];
  assign clkout = (cpuclk_w & hs_enable_q) | (lsclk_del_w & ls_enable_q);
  assign lsclk_selected = selected_ls_q;
  assign hsclk_selected = selected_hs_q;



`ifdef USE_DIVIDER_234
  clkdiv234 divider_u ( .clkin(hsclk_in),
                        .rstb(rst_b),
                        .div3(cpuclk_div_sel==1'b1),
                        .div2(cpuclk_div_sel==1'b0),
                        .div4(1'b0),
                        .clkout(cpuclk_w));
`else
  clkdiv24 divider_u ( .clkin(hsclk_in),
                       .rstb(rst_b),
                       .div4not2(cpuclk_div_sel),
                       .clkout(cpuclk_w));
`endif

  // Delay the host clock to match delays on the motherboard
  always @ (posedge hsclk_in) begin
    del_q <= { lsclk_in, del_q[`CLKDEL_PIPE_SZ-1:1]};
  end

  // Selected LS signal must change on posedge of clock
  always @ (posedge lsclk_del_w or negedge rst_b)
    if ( ! rst_b )
      selected_ls_q <= 1'b1;
    else
      selected_ls_q <= !hsclk_sel & !retimed_hs_enable_q;

  // Edge triggered FF for feedback to clock selection
  always @ ( posedge cpuclk_w or negedge rst_b )
    if ( ! rst_b )
      selected_hs_q <= 1'b0;
    else
      selected_hs_q <= hs_enable_q;

`ifdef USE_LATCH_ENABLE
  always @ ( cpuclk_w or rst_b )
    if ( !rst_b )
      hs_enable_q <= 1'b0;
    else if ( !cpuclk_w )
      hs_enable_q <= hsclk_sel & !retimed_ls_enable_q;
`else
  // Simulate a latch transparent on low cpuclk_w by oversampling
  // with hsclk_in - allowing max time for hsclk_sel to stabilize
  // before being used to gate the clock.
  always @ ( negedge hsclk_in or negedge rst_b )
    if ( !rst_b )
      hs_enable_q <= 1'b0;
    else if ( !cpuclk_w )
      hs_enable_q <= hsclk_sel & !retimed_ls_enable_q;
`endif // !`ifdef USE_LATCH_ENABLE

  always @ ( negedge lsclk_del_w or negedge rst_b )
    if ( ! rst_b )
      ls_enable_q <= 1'b1;
    else
      ls_enable_q <= !hsclk_sel & !retimed_hs_enable_q;

  always @ ( negedge  lsclk_del_w or posedge hs_enable_q )
    if ( hs_enable_q )
      retimed_hs_enable_q <= 1'b1;
    else
      retimed_hs_enable_q <= selected_hs_q;

  always @ ( negedge cpuclk_w )
    if (ls_enable_q)
      retimed_ls_enable_q <= 1'b1;
    else
      retimed_ls_enable_q <= selected_ls_q;


endmodule
