module clkctrl(
                input       hsclk_in,
                input       lsclk_in,
                input       rst_b,
                input       hsclk_sel,
                input [1:0] cpuclk_div_sel,
                output      hsclk_selected,
                output      clkout
                );

  reg                     hsclk_by2_q, hsclk_by4_q, hsclk_by8_q;
  reg                     cpuclk_r;  
  reg                     hsen_q;
  reg [2:0]               hsen_pipe_q;
  reg                     lsen_q;
  reg [1:0]               lsen_pipe_q;
  wire                    lsclk_sel_w;
  
  assign           hsclk_selected = hsen_pipe_q[2];
  
  // hsen must be asserted while clock is low, sampled on rising edge and the clock stopped
  // in the high state for the changeover

  assign clkout = (!hsen_pipe_q[1] | cpuclk_r | !hsen_q) & (!lsen_pipe_q[1] | lsclk_in | !lsen_q);

  always @ ( * )
    case (cpuclk_div_sel)
      2'b00 : cpuclk_r = hsclk_in;
      2'b01 : cpuclk_r = hsclk_by2_q;
      2'b10 : cpuclk_r = hsclk_by4_q;
      2'b11 : cpuclk_r = hsclk_by8_q;
      default: cpuclk_r = 1'bx;      
    endcase
          
  always @ (posedge cpuclk_r or negedge rst_b )
    if ( !rst_b ) 
      { hsen_q, hsen_pipe_q } <= 4'b0;
    else
      begin
        hsen_pipe_q <= { hsen_q & hsen_pipe_q[1],hsen_q & hsen_pipe_q[0], hsen_q & !lsen_pipe_q[0] } ;
        hsen_q <= hsclk_sel;
      end

  always @ (posedge lsclk_in or negedge rst_b)
    if ( !rst_b )
      { lsen_q, lsen_pipe_q}  <= 3'b111;
    else
      begin
        lsen_pipe_q <= { lsen_q & lsen_pipe_q[0], lsen_q & !hsen_pipe_q[0] } ;
        lsen_q <= !hsclk_sel;
      end

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




