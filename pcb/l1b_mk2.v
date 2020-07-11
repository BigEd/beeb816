//
// level1b board
//
// Netlist for L1B PCB layout.
//
// ----------------------------------------------------------------------
// (C) 2009 Ed & Rich
// ----------------------------------------------------------------------

module l1b_mk1();

   // Wires declared as supply* will default to wide routing
   // when parsed through netlister.py
   supply0 VSS;
   supply1 VDD;

   // Netlister.py doesn't yet support Verilog bus notation so all
   // busses have to be bit blasted.
   wire    cpu_d0, cpu_d1, cpu_d2, cpu_d3, cpu_d4, cpu_d5, cpu_d6, cpu_d7;
   wire    bbc_d0, bbc_d1, bbc_d2, bbc_d3, bbc_d4, bbc_d5, bbc_d6, bbc_d7;
   wire    bbc_a0, bbc_a1, bbc_a2, bbc_a3, bbc_a4, bbc_a5, bbc_a6, bbc_a7;
   wire    bbc_a8, bbc_a9, bbc_a10, bbc_a11, bbc_a12, bbc_a13, bbc_a14, bbc_a15;
   wire    cpu_a0, cpu_a1, cpu_a2, cpu_a3, cpu_a4, cpu_a5, cpu_a6, cpu_a7, cpu_a8, cpu_a9,
           cpu_a10, cpu_a11, cpu_a12, cpu_a13, cpu_a14, cpu_a15;
   wire    cpu_vpa, cpu_vda, cpu_vpb, cpu_e, resetb, irqb, nmib;
   wire    bbc_rnw, cpu_rnw, ram_web ;
   wire    ram_a16, ram_a17, ram_a18;
   wire    ram_ceb;
   wire     lat_en;
   wire    rdy, bbc_sync;
   wire    bbc_phi0, bbc_phi1, bbc_phi2, hsclk, cpu_ck_phi2;
   wire    tdo, tdi, tck, tms;
   wire    gpio0, gpio1, gpio2, gpio3, gpio4, gpio5;

   // decoupling caps
   // Radial electolytic, one per board
   cap22uf  c22u_0(.minus(VSS),.plus(VDD));
   cap100nf c100n_1 (.p0( VSS ), .p1( VDD ));
   cap100nf c100n_2 (.p0( VSS ), .p1( VDD ));
   cap100nf c100n_3 (.p0( VDD ), .p1( VSS ));
   cap100nf c100n_4 (.p0( VSS ), .p1( VDD ));
   cap100nf c100n_5 (.p0( VSS ), .p1( VDD ));
   cap100nf c100n_6 (.p0( VSS ), .p1( VDD ));  

   // WDC 65816 CPU
   wdc65816 CPU (
            .vpb(cpu_vpb),
            .rdy(rdy),
            .abortb(VDD),
            .irqb(irqb),
            .mlb(),
            .nmib(nmib),
            .vpa(cpu_vpa),
            .vcc(VDD),
            .a0(cpu_a0),
            .a1(cpu_a1),
            .a2(cpu_a2),
            .a3(cpu_a3),
            .a4(cpu_a4),
            .a5(cpu_a5),
            .a6(cpu_a6),
            .a7(cpu_a7),
            .a8(cpu_a8),
            .a9(cpu_a9),
            .a10(cpu_a10),
            .a11(cpu_a11),
            .vss2(VSS),
            .a12(cpu_a12),
            .a13(cpu_a13),
            .a14(cpu_a14),
            .a15(cpu_a15),
            .d7(cpu_d7),
            .d6(cpu_d6),
            .d5(cpu_d5),
            .d4(cpu_d4),
            .d3(cpu_d3),
            .d2(cpu_d2),
            .d1(cpu_d1),
            .d0(cpu_d0),
            .rdnw(cpu_rnw),
            .e(cpu_e),
            .be(VDD),
            .phi2in(cpu_ck_phi2),
            .mx(),
            .vda(cpu_vda),
            .rstb(resetb)
            );

  // Alliance 512K x 8 SRAM - address pins wired to suit layout
  bs62lv4006  SRAM (
                    .a18(ram_a18),  .vcc(VDD),
                    .a16(ram_a16),  .a15(cpu_a15),
                    .a14(cpu_a14),  .a17(ram_a17),
                    .a12(cpu_a12),  .web(ram_web),
                    .a7(cpu_a11),   .a13(cpu_a13),
                    .a6(cpu_a10),   .a8(cpu_a8),
                    .a5(cpu_a6),    .a9(cpu_a9),
                    .a4(cpu_a4),    .a11(cpu_a0),
                    .a3(cpu_a2),    .oeb(ram_ceb),
                    .a2(cpu_a3),    .a10(cpu_a1),
                    .a1(cpu_a4),    .csb(ram_ceb),
                    .a0(cpu_a5 ),   .d7(cpu_d0),
                    .d0(cpu_d7),    .d6(cpu_d1),
                    .d1(cpu_d6),    .d5(cpu_d2),
                    .d2(cpu_d5),    .d4(cpu_d3),
                    .vss(VSS),      .d3(cpu_d4)
                    );

   // L1B CPLD in PLCC84 pin socket (can be 9572 or 95108)
  xc95108_pc84  CPLD (

                      // RHS
		      .p1(bbc_d4),
		      .p2(bbc_d3),
		      .p3(bbc_d2),
		      .p4(bbc_d1),
		      .p5(bbc_d0),
		      .p6(bbc_rnw),
		      .p7(bbc_sync),
		      .gnd1(VSS),
		      .gck1(hsclk),
		      .gck2(bbc_phi0),
		      .p11(bbc_phi2),

                      // TOP
		      .gck3(bbc_phi1),
		      .p13(rdy),
		      .p14(gpio5),
		      .p15(gpio4),
		      .gnd2(VSS),
		      .p17(gpio3),
		      .p18(gpio2),
		      .p19(gpio1),
		      .p20(gpio0),
		      .p21(ram_a18),
		      .vccio1(VDD),
		      .p23(ram_a17),
		      .p24(ram_a16),
		      .p25(ram_ceb),
		      .p26(ram_web),
		      .gnd3(VSS),
		      .tdi(tdi),
		      .tms(tms),
		      .tck(tck),
		      .p31(nmib),
		      .p32(irqb),

                      // LHS
		      .p33(cpu_vda),
		      .p34(cpu_vpb),
		      .p35(cpu_ck_phi2),
		      .p36(cpu_vpa),
		      .p37(cpu_rnw),
		      .vccint1(VDD),
		      .p39(cpu_e),
		      .p40(cpu_d0),
		      .p41(cpu_d1),
		      .gnd4(VSS),
		      .p43(cpu_d2),
		      .p44(cpu_d3),
		      .p45(cpu_d4),
		      .p46(cpu_d5),
		      .p47(cpu_d6),
		      .p48(cpu_d7),
		      .gnd5(VSS),
		      .p50(),
		      .p51(cpu_a15),
		      .p52(cpu_a14),
		      .p53(cpu_a13),

                      // Bottom
		      .p54(cpu_a12),
		      .p55(cpu_a11),
		      .p56(cpu_a10),
		      .p57(cpu_a9),
		      .p58(cpu_a8),
		      .tdo(tdo),
		      .gnd6(VSS),
		      .p61(cpu_a7),
		      .p62(cpu_a6),
		      .p63(cpu_a5),
		      .vccio2(VDD),
		      .p65(cpu_a4),
		      .p66(cpu_a3),
		      .p67(cpu_a2),
		      .p68(cpu_a1),
		      .p69(cpu_a0),
		      .p70(lat_en),
		      .p71(bbc_a8),
		      .p72(bbc_a9),
		      .vccint2(VDD),
		      .gsr(resetb),

                      // TOP
		      .p75(bbc_a10),
		      .gts1(bbc_a11),
		      .gts2(bbc_a12),
		      .vccint3(VDD),
		      .p79(bbc_a13),
		      .p80(bbc_a14),
		      .p81(bbc_a15),
		      .p82(bbc_d7),
		      .p83(bbc_d6),
		      .p84(bbc_d5)
                      );

  SN74373 IC2  (
                .oeb(VSS),        .vdd(VDD),
                .q0(bbc_a6),     .q7(bbc_a7),
                .d0(cpu_a6),     .d7(cpu_a7),
                .d1(cpu_a4),     .d6(cpu_a5),
                .q1(bbc_a4),     .q6(bbc_a5),
                .q2(bbc_a2),     .q5(bbc_a3),
                .d2(cpu_a2),     .d5(cpu_a3),
                .d3(cpu_a0),     .d4(cpu_a1),
                .q3(bbc_a0),     .q4(bbc_a1),
                .vss(VSS),       .le(lat_en)
                );



   // Socket for CMOS oscillator
   cmos_osc_14 OSC (
                    .gnd(VSS),
                    .vdd(VDD),
                    .en(VDD),
                    .clk(hsclk)
                    );

   // 40W Plug which connects via IDC cable and header into the
   // host computer's 6502 CPU socket
   skt6502_40w CON (
                    .vss(VSS),
                    .rdy(rdy),
                    .phi1out(bbc_phi1),
                    .irqb(irqb),
                    .nc1(),
                    .nmib(nmib),
                    .sync(bbc_sync),
                    .vcc(VDD),
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
                    .vss2(VSS),
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
                    .rstb(resetb)
                    );

  idc_hdr_10w    gpio(
                      .p1(VSS),   .p2(VSS),
                      .p3(gpio0), .p4(gpio1),
                      .p5(gpio2), .p6(gpio3),
                      .p7(gpio4), .p8(gpio5),
                      .p9(VSS),   .p10(VSS),
                      );


   // jtag header for in system programming (same pinout as MacMall Breakout board
   // so that we can use existing cable).
  hdr8way jtag (
                .p1(VSS),  .p2(VSS),
                .p3(tms),  .p4(tdi),
                .p5(tdo),  .p6(tck),
                .p7(VDD),  .p8(),
                );

   // Power header is convenient if we allow in system programming and pin out
   // compatible with MacMall connector.
   powerheader3 pwr(
                    .vdd1(VDD),
                    .vdd2(VDD),
                    .gnd(VSS)
                    );
endmodule
