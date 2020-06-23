module as_edge_detect( clk, din, srst_b, dout);
  // edge detect for significantly slower async clock (HS CLK >=5x sampled clock)
  // When detecting a rising (falling) edge the reset state of the chain is all-ones (zeroes)
  input         din;
  input         clk;
  input         srst_b;
  output        dout;

  reg   r1_q, r2_q, r3_q;

`ifdef STOP_ON_PHI1_D
  assign dout = r3_q & !r2_q & srst_b;
  always @ ( negedge clk )
    if ( !srst_b)
      { r1_q, r2_q, r3_q} <= 3'b000;
    else
      { r1_q, r2_q, r3_q} <= {din, r1_q, r2_q};
`else
  assign dout = !r3_q & r2_q & srst_b;
  always @ ( negedge clk )
    if ( !srst_b)
      { r1_q, r2_q, r3_q} <= 3'b111;
    else
      { r1_q, r2_q, r3_q} <= {din, r1_q, r2_q};
`endif
endmodule
