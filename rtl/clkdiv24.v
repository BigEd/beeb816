/*
 * clkdiv24
 *
 * Divide by 2, or 4 with a 50:50 mark space ratio
 *
 */

module clkdiv24 (
                 input      clkin,
                 input      rstb,
                 input      div4not2,
                 output reg clkout
                 );
  
  reg [1:0]                 p_d;
  reg [1:0]                 p_q;
  
  
  always @  ( * ) begin
    clkout = p_q[0];
    p_d[1] = !p_q[0];    
    if (div4not2) 
      p_d[0] = p_q[1];
    else 
      p_d[0] = !p_q[0];
  end
  
  always @ ( posedge clkin or negedge rstb )
    if ( !rstb )
      p_q <= 2'b00;
    else
      p_q <= p_d;
  
endmodule
