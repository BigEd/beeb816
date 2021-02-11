//
// Beeb816 Mark2B board
//
// ----------------------------------------------------------------------
// (C) 2021 Ed & Rich
// ----------------------------------------------------------------------

module beeb816_mk2b();

  // Wires declared as supply* will default to wide routing
  // when parsed through netlister.py
  supply0 GND;
  supply1 VDD_5V;
  supply1 VDD_SYS;  
  supply1 VDD_5V_IN;  
  supply1 VDD_3V3;

  // Netlister.py doesn't yet support Verilog bus notation so all
  // busses have to be bit blasted.
  wire     bbc_d0, bbc_d1, bbc_d2, bbc_d3, bbc_d4, bbc_d5, bbc_d6, bbc_d7;
  wire     bbc_a0, bbc_a1, bbc_a2, bbc_a3, bbc_a4, bbc_a5, bbc_a6, bbc_a7;
  wire     bbc_a8, bbc_a9, bbc_a10, bbc_a11, bbc_a12, bbc_a13, bbc_a14, bbc_a15;
  wire     bbc_rnw, ram_web, ram_oeb, bbc_rstb, bbc_irqb, bbc_nmib, bbc_rdy ;
  wire     bbc_sync, bbc_phi0, bbc_phi1, bbc_phi2, hsclk, cpu_phi2;

  wire     cpld_d0, cpld_d1, cpld_d2, cpld_d3, cpld_d4, cpld_d5, cpld_d6, cpld_d7;
  wire     cpld_rstb, cpld_irqb, cpld_nmib, cpld_rdy ;
  wire     cpld_phi0_filt, cpld_phi0;

  wire     cpu_d0, cpu_d1, cpu_d2, cpu_d3, cpu_d4, cpu_d5, cpu_d6, cpu_d7;
  wire     cpu_a0, cpu_a1, cpu_a2, cpu_a3, cpu_a4, cpu_a5, cpu_a6, cpu_a7;
  wire     cpu_a8, cpu_a9, cpu_a10, cpu_a11, cpu_a12, cpu_a13, cpu_a14, cpu_a15;
  wire     cpu_vpa, cpu_vda, cpu_vpb, cpu_e, cpu_rstb, cpu_irqb, cpu_nmib, cpu_rdy, cpu_rnw;

  wire     ram_a14, ram_a15, ram_a16, ram_a17, ram_a18;
  wire     ram_ceb;

  wire     dip0, dip1;  
  wire     tdo, tdi, tck, tms ;
  wire     tp0, tp1 ;

  // Radial electolytic, one each on the 5V and 3V3 supply
  cap22uf  CAP22UF_5V(.minus(GND),.plus(VDD_5V));
  cap22uf  CAP22UF_SYS(.minus(GND),.plus(VDD_SYS));

  // decoupling caps
//  cap100nf c100n_1 (.p0(GND), .p1(VDD_3V3));
  cap100nf c100n_2 (.p0(VDD_SYS), .p1(GND));
  cap100nf c100n_3 (.p0(GND), .p1(VDD_SYS));
  cap100nf c100n_4 (.p0(GND), .p1(VDD_3V3));
  cap100nf_smd c100n_10 (.p0(GND), .p1(VDD_3V3));
  cap100nf_smd c100n_11 (.p0(GND), .p1(VDD_3V3));
//   cap100nf_smd c100n_12 (.p0(GND), .p1(VDD_3V3));

  // Current limiting resistors on all 5V inputs to the CPLD  
  vresistor r330_0 ( .p0(cpld_d0), .p1(bbc_d0) );
  vresistor r330_1 ( .p0(cpld_d1), .p1(bbc_d1) );
  vresistor r330_2 ( .p0(cpld_d2), .p1(bbc_d2) );
  vresistor r330_3 ( .p0(cpld_d3), .p1(bbc_d3) );
  vresistor r330_4 ( .p0(cpld_d4), .p1(bbc_d4) );
  vresistor r330_5 ( .p0(cpld_d5), .p1(bbc_d5) );
  vresistor r330_6 ( .p0(cpld_d6), .p1(bbc_d6) );
  vresistor r330_7 ( .p0(cpld_d7), .p1(bbc_d7) );
  vresistor r330_8 ( .p0(cpld_phi0),.p1(bbc_phi0) );
  vresistor r330_9 ( .p0(cpld_rstb), .p1(bbc_rstb) );
  vresistor r330_10 ( .p0(cpld_rdy), .p1(bbc_rdy) );
  vresistor r330_11 ( .p0(cpld_irqb), .p1(bbc_irqb) );
  vresistor r330_12 ( .p0(cpld_nmib), .p1(bbc_nmib) );
  // Pull-up on RDY from host into CPLD
  vresistor r47k ( .p0(VDD_3V3), .p1(cpld_rdy) );
  vresistor r10k_0 ( .p0(GND), .p1(dip0) );
  vresistor r10k_1 ( .p0(GND), .p1(dip1) );  
  
  // Link to connect filter cap to CPLD PHI0 input, may be required for Elk/Master
  hdr1x02   clklnk ( .p1(cpld_phi0),.p2(cpld_phi0_filt) );
  smallcap  c47pf  ( .p1(cpld_phi0_filt), .p0(GND) );

  // Link to connect 5V to regulator input  - intercept to measure current or add alternative +5V supply
  hdr1x02   vdd_5v_lnk ( .p1(VDD_5V_IN),.p2(VDD_5V) );

  // Link to determine VDD for CPU/RAM/Osc system - allow use of 5V for experiments
  hdr1x03   sysvdd_lnk(  .p1(VDD_3V3), .p2(VDD_SYS), .p3(VDD_5V));

  // Test point for incoming clock to CPLD
  hdr1x02   tclk( .p1(cpld_phi0), .p2(GND) );

  // DIP 2
  DIP2      dip(.sw0_a(dip0), .sw0_b(VDD_3V3),
                .sw1_a(dip1), .sw1_b(VDD_3V3));
    
  // 3V3 Regulator and caps
  MCP1700_3302E   REG3V3 ( .vin(VDD_5V), .gnd(GND), .vout(VDD_3V3));

  // Two ceramic caps to be placed v. close to regulator pins
  cap1uf          reg_cap0 (.p0(VDD_5V), .p1(GND));
  cap1uf          reg_cap1 (.p0(VDD_3V3), .p1(GND));

  // WDC 65816 CPU
  wdc65816 CPU (
                .vpb(cpu_vpb),
                .rdy(cpu_rdy),
                .abortb(VDD_SYS),
                .irqb(cpu_irqb),
                .mlb(),
                .nmib(cpu_nmib),
                .vpa(cpu_vpa),
                .vcc(VDD_SYS),
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
                .vss2(GND),
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
                .be(VDD_SYS),
                .phi2in(cpu_phi2),
                .mx(),
                .vda(cpu_vda),
                .rstb(cpu_rstb)
                );


  // Alliance 512K x 8 SRAM - address pins wired to suit layout
  bs62lv4006  SRAM (
                    .a18(ram_a18),  .vcc(VDD_SYS),
                    .a16(ram_a16),  .a15(ram_a15),
                    .a14(ram_a14),  .a17(ram_a17),
                    .a12(cpu_a0),   .web(ram_web),
                    .a7(cpu_a1),    .a13(cpu_a2),
                    .a6(cpu_a3),    .a8(cpu_a4),
                    .a5(cpu_a5),    .a9(cpu_a6),
                    .a4(cpu_a7),    .a11(cpu_a8),
                    .a3(cpu_a9),    .oeb(ram_oeb),
                    .a2(cpu_a10),   .a10(cpu_a12),
                    .a1(cpu_a11),   .csb(ram_ceb),
                    .a0(cpu_a13),   .d7(cpu_d0),
                    .d0(cpu_d5),    .d6(cpu_d1),
                    .d1(cpu_d6),    .d5(cpu_d2),
                    .d2(cpu_d7),    .d4(cpu_d3),
                    .vss(GND),      .d3(cpu_d4)
                   );

  // CPLD in TQFP100 package
  xc95144xl_tq100 CPLD (
                        .gts3(cpld_d3),
	                .gts4(bbc_a2),
	                .gts1(bbc_a1),
	                .gts2(cpld_d2),
	                .vddint1(VDD_3V3),
                        .p6(bbc_a0),
	                .p7(cpld_d1),
	                .p8(cpld_d0),
                        .p9(bbc_sync),
	                .p10(bbc_rnw),
	                .p11(cpld_nmib),
	                .p12(cpld_irqb),
	                .p13(bbc_phi1),
	                .p14(cpld_rdy),
	                .p15(bbc_phi2),
	                .p16(tp0),
	                .p17(tp1),
                        .p18(dip0),
	                .p19(dip1),
	                .p20(),
	                .gnd1(GND),
	                .gck1(hsclk),
	                .gck2(cpu_vpb),
	                .p24(cpu_rdy),
	                .p25(cpu_rstb),
	                .vddio1(VDD_3V3),
	                .gck3(cpu_phi2),
	                .p28(cpu_vda),
                        .p29(cpu_irqb),
	                .p30(cpu_nmib),
	                .gnd2(GND),
	                .p32(cpu_nmib),
	                .p33(cpu_e),
	                .p34(cpu_rnw),
	                .p35(cpu_vpa),
                        .p36(ram_a18),
                        .p37(ram_a16),
	                .vddio2(VDD_3V3),
	                .p39(ram_a15),
	                .p40(ram_a14),
	                .p41(ram_a17),
                        .p42(cpu_a0),
	                .p43(ram_web),
	                .gnd3(GND),
	                .tdi(tdi),
	                .p46(cpu_a1),
                        .tms(tms),
	                .tck(tck),
	                .p49(cpu_a2),
	                .p50(cpu_a3),
	                .vddio3(VDD_3V3),
	                .p52(cpu_a4),
	                .p53(ram_oeb),
	                .p54(cpu_a5),
                        .p55(cpu_a6),
	                .p56(ram_ceb),
	                .vddint2(VDD_3V3),
	                .p58(cpu_a7),
	                .p59(cpu_a8),
	                .p60(cpu_a9),
	                .p61(cpu_a10),
                        .gnd4(GND),
                        .p63(cpu_a11),
	                .p64(cpu_a12),
                        .p65(cpu_a15),
	                .p66(cpu_a13),
                        .p67(cpu_a14),
	                .p68(cpu_d0),
	                .gnd5(GND),
	                .p70(cpu_d1)
	                .p71(cpu_d2)
                        .p72(cpu_d3),
                        .p73(cpu_d4),
	                .p74(cpu_d5),
	                .gnd6(GND),
	                .p76(cpu_d6),
	                .p77(cpu_d7),
	                .p78(bbc_a11),
	                .p79(bbc_a12),
	                .p80(bbc_a10),
	                .p81(bbc_a13),
	                .p82(bbc_a9),
	                .tdo(tdo),
                        .gnd7(GND),
	                .p85(bbc_a14)
	                .p86(bbc_a8),
	                .p87(bbc_a15),
	                .vddio4(VDD_3V3),
                        .p89(bbc_a7),
                        .p90(cpld_d7),
	                .p91(bbc_a6),
	                .p92(cpld_d6),
	                .p93(bbc_a5),
	                .p94(cpld_d5),
	                .p95(bbc_a4),
	                .p96(cpld_d4),
	                .p97(bbc_a3),
	                .vddint4(VDD_3V3),
                        .gsr(cpld_rstb),
	                .gnd(GND)
                        );

  // Socket for CMOS oscillator
  cmos_osc_14 OSC (
                   .gnd(GND),
                   .vdd(VDD_SYS),
                   .en(VDD_SYS),
                   .clk(hsclk)
                   );

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

  // jtag header for in system programming (same pinout as MacMall Breakout board
  // so that we can use existing cable).
  hdr8way jtag (
                .p1(GND),     .p2(GND),
                .p3(tms),     .p4(tdi),
                .p5(tdo),     .p6(tck),
                .p7(VDD_3V3), .p8(),
                );

endmodule
