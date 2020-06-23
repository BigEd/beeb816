module s_edge_detect( clk, din, srst_b, dout);
  // edge detect for slightly slower sync clock (sampling freq >= 2x sampled clock freq)
  // When detecting a rising (falling) edge the reset state of the chain is all-ones (zeroes)
  input         din;
  input         clk;
  input         srst_b;
  output        dout;
  reg   r1_q;

`ifdef STOP_ON_PHI1_D
  assign dout = r1_q & !din & srst_b;
  always @ ( negedge clk )
    if ( !srst_b)
      r1_q  <= 0;
    else
      r1_q  <= din;
`else
  assign dout = !r1_q & din & srst_b;
  always @ ( negedge clk )
    if ( !srst_b)
      r1_q  <= 1;
    else
      r1_q  <= din;
`endif
endmodule
