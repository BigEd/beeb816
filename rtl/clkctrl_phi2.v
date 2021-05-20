// Switch stops the clock in the PHI2 state

// Size of clock delay pipe - needs to be 0 for the Master but 2 or 3 for BBC /Elk depending on xtal
`define CLKDEL_PIPE_SZ 3

// Select this to use a simple /2, /4 ripple counter divider
`define RIPPLE_DIVIDER
// Select this to use the /2 and /3 rather than /2 and /4 in the synchronous divider module
//`define USE_DIVIDER_23

// Use this to get a latch on the HS clock enable rather than a FF
//`define USE_LATCH_ENABLE 1
`ifdef USE_DIVIDER_23
  `define USE_LATCH_ENABLE 1
`endif

`define SINGLE_HS_RETIMER


module clkctrl_phi2(
               input  hsclk_in,
               input  lsclk_in,
               input  rst_b,
               input  hsclk_sel,
               input  delay_sel,
               input  cpuclk_div_sel,
               output hsclk_selected,
               output lsclk_selected,
               output clkout,              // Selected clock
               output fast_clkout          // RAW fast clock (divided down from HSCLK_IN)
               );

  reg                      hs_enable_q, ls_enable_q;
  reg                      selected_ls_q;
  reg                      selected_hs_q;
`ifdef SINGLE_HS_RETIMER
  reg                      retimed_ls_enable_q;
`else
  reg [1:0]                retimed_ls_enable_q;
`endif
  reg                      retimed_hs_enable_q;
  reg [`CLKDEL_PIPE_SZ-1:0] del_q;
  wire                     retimed_ls_enable_w;

  // Force Keep clock nets to prevent ISE merging divider logic into other equations and
  // causing timing issues
  (* KEEP="TRUE" *) wire  cpuclk_w;
  (* KEEP="TRUE" *) wire  lsclk_del_w;
  // Faster XTAL speeds need a longer delay line
  assign lsclk_del_w = (delay_sel) ? del_q[0] : del_q[1];
  assign clkout = (cpuclk_w & hs_enable_q) | (lsclk_del_w & ls_enable_q);
  assign lsclk_selected = selected_ls_q;
  assign hsclk_selected = selected_hs_q;
  assign fast_clkout = cpuclk_w;

`ifdef RIPPLE_DIVIDER
  reg                       ripple_div2_q;
  reg                       ripple_div4_q;
  always @ ( posedge hsclk_in )
    ripple_div2_q <= !ripple_div2_q;
  always @ ( posedge ripple_div2_q )
    ripple_div4_q <= !ripple_div4_q;
  assign cpuclk_w = ( cpuclk_div_sel) ? ripple_div4_q : ripple_div2_q;
`else
  clkdiv234 divider_u ( .clkin(hsclk_in),
                        .rstb(rst_b),
`ifdef USE_DIVIDER_23
                        .div4(1'b0),
                        .div3(cpuclk_div_sel==1'b1),
`else
                        .div4(cpuclk_div_sel==1'b1),
                        .div3(1'b0),
`endif
                        .div2(cpuclk_div_sel==1'b0),
                        .clkout(cpuclk_w));
`endif // !`ifdef RIPPLE_DIVIDER

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
  // Use a latch on the HS enable to allow maximum time for the
  // enable to stabilize before being used to gate the clock
  always @ ( cpuclk_w or rst_b )
    if ( !rst_b )
      hs_enable_q <= 1'b0;
    else if ( !cpuclk_w )
      hs_enable_q <= hsclk_sel & !retimed_ls_enable_w;
`else
  // Simulate a latch transparent on low cpuclk_w by oversampling
  // with hsclk_in - allows 1/2 hsclk cycle less time then using
  // an actual latch
  always @ ( negedge hsclk_in or negedge rst_b )
    if ( !rst_b )
      hs_enable_q <= 1'b0;
    else if ( !cpuclk_w )
      hs_enable_q <= hsclk_sel & !retimed_ls_enable_w;
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

`ifdef SINGLE_HS_RETIMER
  always @ ( negedge cpuclk_w or posedge ls_enable_q )
    if (ls_enable_q)
      retimed_ls_enable_q <= 1'b1;
    else
      retimed_ls_enable_q <= selected_ls_q;
  assign retimed_ls_enable_w = retimed_ls_enable_q;
`else
  // Use two FFs here for safety because reset might be deasserted at the same
  // time as a cpuclk_w negedge (both of which are on a hsclk posedge)
  always @ ( negedge cpuclk_w or posedge ls_enable_q )
    if (ls_enable_q)
      retimed_ls_enable_q <= 2'b11;
    else
      retimed_ls_enable_q <= {selected_ls_q, retimed_ls_enable_q[1]} ;
  assign retimed_ls_enable_w = retimed_ls_enable_q[0];
`endif // !`ifdef SINGLE_HS_RETIMER


endmodule
