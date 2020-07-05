//
// Switch between async clocks when both are low.
//

`define PIPE_SZ 2

module clkctrl_phi1(
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
  reg                     hs_enable_lat_q, ls_enable_lat_q;

  reg                     ls_enable_q;
  reg                     selected_hs_q;
  reg [`PIPE_SZ-1:0]      pipe_retime_ls_enable_q;
  reg [`PIPE_SZ-1:0]      pipe_retime_hs_enable_q;
  wire                    retimed_ls_enable_w = pipe_retime_ls_enable_q[0];
  wire                    retimed_hs_enable_w = pipe_retime_hs_enable_q[0];


  assign clkout = (cpuclk_r & hs_enable_lat_q & pipe_retime_hs_enable_q[0]) | (lsclk_in & ls_enable_lat_q & pipe_retime_ls_enable_q[0]);

  assign lsclk_selected = ls_enable_lat_q & pipe_retime_ls_enable_q[0];
  assign hsclk_selected = selected_hs_q;

  always @ ( * )
    case (cpuclk_div_sel)
      2'b00 : cpuclk_r = hsclk_in;
      2'b01 : cpuclk_r = hsclk_by2_q;
      2'b10 : cpuclk_r = hsclk_by4_q;
      2'b11 : cpuclk_r = hsclk_by8_q;
      default: cpuclk_r = 1'bx;
    endcase // case (cpuclk_div_sel)

  always @ ( * )
    if ( ! rst_b )
      hs_enable_lat_q <= 1'b0;
    else if ( !cpuclk_r )
      hs_enable_lat_q <= hsclk_sel & retimed_hs_enable_w;

  always @ ( * )
    if ( ! rst_b )
      ls_enable_lat_q <= 1'b1;
    else if ( !lsclk_in )
      ls_enable_lat_q <= !hsclk_sel & retimed_ls_enable_w;

  always @ (posedge cpuclk_r or negedge rst_b)
    if ( ! rst_b )
      selected_hs_q <= 1'b0;
    else
      selected_hs_q <= hsclk_sel & retimed_hs_enable_w;

  always @ ( negedge lsclk_in or negedge rst_b )
    if (! rst_b )
      ls_enable_q  <= 1'b1;
    else
      ls_enable_q <= ls_enable_lat_q;  
  
  always @ ( negedge  cpuclk_r or negedge rst_b )
    if ( ! rst_b )
      pipe_retime_hs_enable_q <= {`PIPE_SZ{1'b0}};
    else
      pipe_retime_hs_enable_q <= {hsclk_sel & !ls_enable_q ,  pipe_retime_hs_enable_q[1]};    

  always @ ( negedge  lsclk_in or negedge rst_b )
    if ( ! rst_b )
      pipe_retime_ls_enable_q <= {`PIPE_SZ{1'b1}};
    else
      pipe_retime_ls_enable_q <= {!hsclk_sel & !hs_enable_lat_q, pipe_retime_ls_enable_q[1]};

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
