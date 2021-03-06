//
// Beeb816 Buffer board
//

module bufboard();

  // Wires declared as supply* will default to wide routing
  // when parsed through netlister.py
  supply0 GND;
  supply1 VDD_5V;
  supply1 VDD_3V3;

  // Netlister.py doesn't yet support Verilog bus notation so all
  // busses have to be bit blasted.
  wire     bbc_d0, bbc_d1, bbc_d2, bbc_d3, bbc_d4, bbc_d5, bbc_d6, bbc_d7;
  wire     bbc_a0, bbc_a1, bbc_a2, bbc_a3, bbc_a4, bbc_a5, bbc_a6, bbc_a7;
  wire     bbc_a8, bbc_a9, bbc_a10, bbc_a11, bbc_a12, bbc_a13, bbc_a14, bbc_a15;
  wire     bbc_rnw, ram_web, ram_oeb, bbc_rstb, bbc_irqb, bbc_nmib, bbc_rdy ;
  wire     bbc_sync, bbc_phi0, bbc_phi1, bbc_phi2, hsclk, cpu_phi2;

  wire     tdo, tdi, tck, tms ;

  
  // Link to connect 5V to regulator input  - intercept to measure current or add alternative +5V supply
  hdr1x02   vdd_5v_lnk ( .p1(VDD_5V_IN),.p2(VDD_5V) );

  // 40W Plug which connects via IDC cable and header into the
  // host computer's 6502 CPU socket
  skt6502_40w_RA CON (
                   .vss(GND),
                   .rdy(bbc_rdy),
                   .phi1out(bbc_phi1),
                   .irqb(bbc_irqb),
                   .nc1(),
                   .nmib(bbc_nmib),
                   .sync(bbc_sync),
                   .vcc(VDD_5V_IN),
                   .a0(bbc_a0),
                   .a1(bbc_a1),
                   .a2(bbc_a2),
                   .a3(bbc_a3),
                   .a4(bbc_a4),
                   .a5(bbc_a5),
                   .a6(bbc_a6),
                   .a7(bbc_a7),
                   .a8(bbc_a8),
                   .a9(bbc_a9),
                   .a10(bbc_a10),
                   .a11(bbc_a11),
                   .vss2(GND),
                   .a12(bbc_a12),
                   .a13(bbc_a13),
                   .a14(bbc_a14),
                   .a15(bbc_a15),
                   .d7(bbc_d7),
                   .d6(bbc_d6),
                   .d5(bbc_d5),
                   .d4(bbc_d4),
                   .d3(bbc_d3),
                   .d2(bbc_d2),
                   .d1(bbc_d1),
                   .d0(bbc_d0),
                   .rdnw(bbc_rnw),
                   .nc2(),
                   .nc3(),
                   .phi0in(bbc_phi0),
                   .so(),
                   .phi2out(bbc_phi2),
                   .rstb(bbc_rstb)
                   );

  hdr2x04   tstpt(
                  .p1(GND),     .p2(GND),
                  .p3(tp0),     .p4(tp1),
                  .p5(VDD_3V3), .p6(VDD_3V3),
                  .p7(VDD_3V3), .p8(VDD_3V3),
                  );

  hdr1x04   gndpt(
                  .p1(GND),
                  .p2(GND),
                  .p3(GND),
                  .p4(GND)
                  );

  // jtag header for in system programming (same pinout as MacMall Breakout board
  // so that we can use existing cable).
  hdr8way jtag (
                .p1(GND),     .p2(GND),
                .p3(tms),     .p4(tdi),
                .p5(tdo),     .p6(tck),
                .p7(VDD_3V3), .p8(),
                );

endmodule
