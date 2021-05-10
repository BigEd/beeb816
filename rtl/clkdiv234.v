/*
 * clkdiv234
 *
 * Divide by 2, 3 or 4, all with a 50:50 mark space ratio
 *
 */

module clkdiv234 (
                  input      clkin,
                  input      rstb,
                  input      div2,
                  input      div3,
                  input      div4,
                  output reg clkout
                  );



  reg [1:0]                  p_d;
  reg [1:0]                  p_q;
  reg                        n_q;


  always @  ( * ) begin
    if ( div3 ) begin
      p_d[1] = !p_q[0];
      p_d[0] = p_q[1] & !p_q[0];

      clkout = !(n_q & p_q[1]);
    end
    else if (div4) begin
      p_d[1] = !p_q[0];
      p_d[0] = p_q[1];

      clkout = p_q[0];
    end
    else begin
      p_d[1] = 1'bx;
      p_d[0] = !p_q[0];

      clkout = p_q[0];
    end
  end

  always @ ( posedge clkin or negedge rstb )
    if ( !rstb )
      p_q <= 2'b00;
    else
      p_q <= p_d;

  always @ ( negedge clkin)
    n_q <= p_q[1];

endmodule
