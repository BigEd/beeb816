module clkctrl(
                input       hsclk_in,
                input       lsclk_in,
                input       rst_b,
                input       hsclk_sel,
                input [1:0] cpuclk_div_sel,
                output      clkout
                );

  reg                     hsclk_by2_q, hsclk_by4_q, hsclk_by8_q;
  reg                     cpuclk_r;

  async_switch     as_switch_u (
                                .lsclk(lsclk_in),
                                .hsclk(cpuclk_r),
                                .hsen(hsclk_sel),
                                .reset_b(rst_b),
                                .clkout(clkout)
                                );
  
  always @ ( * )
    case (cpuclk_div_sel)
      2'b00 : cpuclk_r = hsclk_in;
      2'b01 : cpuclk_r = hsclk_by2_q;
      2'b10 : cpuclk_r = hsclk_by4_q;
      2'b11 : cpuclk_r = hsclk_by8_q;
      default: cpuclk_r = 1'bx;      
    endcase
        
  always @ ( posedge hsclk_in or negedge rst_b)
    if ( !rst_b )
      hsclk_by2_q <= 1'b0;
    else
      hsclk_by2_q <= !hsclk_by2_q;
  
  always @ ( posedge hsclk_by2_q or negedge rst_b)
    if ( !rst_b )
      hsclk_by4_q <= 1'b0;
    else
      hsclk_by4_q <= !hsclk_by4_q;
  
  always @ ( posedge hsclk_by4_q or negedge rst_b)
    if ( !rst_b )
      hsclk_by8_q <= 1'b0;
    else
      hsclk_by8_q <= !hsclk_by8_q;
  
endmodule


