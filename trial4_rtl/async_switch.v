module async_switch (
                     input lsclk,
                     input hsclk,
                     input hsen,
                     input reset_b,
                     output clkout
                     );


  reg                       hsen_lat_q;
  reg [1:0]                 hsen_pipe_q;
  reg                       lsen_lat_q;
  reg [1:0]                 lsen_pipe_q;


`ifdef STOP_ON_PHI1_D

  assign clkout = (hsen_pipe_q[1] & hsclk & hsen_lat_q) | (lsen_pipe_q[1] & lsclk & lsen_lat_q);

  always @ ( * )
    if ( ! reset_b )
      hsen_lat_q <= 1'b0;
    else if (!hsclk)
      hsen_lat_q <= hsen;

  always @ ( * )
    if ( ! reset_b )
      lsen_lat_q <= 1'b1;
    else if (!lsclk )
      lsen_lat_q <= !hsen;

  always @ (negedge hsclk or negedge reset_b)
    if ( !reset_b )
      hsen_pipe_q[1:0] <= 2'b0;
    else
      hsen_pipe_q[1:0] <= { hsen_lat_q & hsen_pipe_q[0], hsen_lat_q & !lsen_pipe_q[0] } ;

  always @ (negedge lsclk or negedge reset_b)
    if ( !reset_b )
      lsen_pipe_q[1:0] <= 2'b11;
    else
      lsen_pipe_q[1:0] <= { lsen_lat_q & lsen_pipe_q[0], lsen_lat_q & !hsen_pipe_q[0] } ;
`else

  assign clkout = (!hsen_pipe_q[1] | hsclk | !hsen_lat_q) & (!lsen_pipe_q[1] | lsclk | !lsen_lat_q);

  always @ ( * )
    if ( !reset_b )
      hsen_lat_q <= 1'b0;
    else if (hsclk)
      hsen_lat_q <= hsen;

  always @ ( *)
    if ( !reset_b )
      lsen_lat_q <= 1'b1;
    else if (lsclk )
      lsen_lat_q <= !hsen;

  always @ (posedge hsclk or negedge reset_b )
    if ( !reset_b )
      hsen_pipe_q <= 2'b0;
    else
      hsen_pipe_q <= { hsen_lat_q & hsen_pipe_q[0], hsen_lat_q & !lsen_pipe_q[0] } ;

  always @ (posedge lsclk or negedge reset_b)
    if ( !reset_b )
      lsen_pipe_q <= 2'b11;
    else
      lsen_pipe_q <= { lsen_lat_q & lsen_pipe_q[0], lsen_lat_q & !hsen_pipe_q[0] } ;

`endif

endmodule
