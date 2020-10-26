//
// Option2 PCB respin
//
// level1b board
//
// Netlist for L1B PCB layout.
//
// ----------------------------------------------------------------------
// (C) 2009,2020 Ed & Rich
// ----------------------------------------------------------------------

module l1b_mk2();

   // Wires declared as supply* will default to wide routing
   // when parsed through netlister.py
   supply0 GND;
   supply1 VDD;

   // Netlister.py doesn't yet support Verilog bus notation so all
   // busses have to be bit blasted.
  wire     cpu_d0, cpu_d1, cpu_d2, cpu_d3, cpu_d4, cpu_d5, cpu_d6, cpu_d7;
  wire     bbc_d0, bbc_d1, bbc_d2, bbc_d3, bbc_d4, bbc_d5, bbc_d6, bbc_d7;
  wire     bbc_a0, bbc_a1, bbc_a2, bbc_a3, bbc_a4, bbc_a5, bbc_a6, bbc_a7;
  wire     bbc_a8, bbc_a9, bbc_a10, bbc_a11, bbc_a12, bbc_a13, bbc_a14, bbc_a15;
  wire     cpu_a0, cpu_a1, cpu_a2, cpu_a3, cpu_a4, cpu_a5, cpu_a6, cpu_a7, cpu_a8, cpu_a9,
           cpu_a10, cpu_a11, cpu_a12, cpu_a13, cpu_a14, cpu_a15;
  wire     cpu_vpa, cpu_vda, cpu_vpb, cpu_e, resetb, irqb, nmib;
  wire     bbc_rnw, cpu_rnw, ram_web, ram_oeb ;
  wire     ram_a14, ram_a15, ram_a16, ram_a17, ram_a18;
  wire     ram_ceb;
  wire     lat_en;
  wire     rdy, bbc_sync;
  wire     bbc_phi0, bbc_phi1, bbc_phi2, hsclk, cpu_phi2;
  wire     tdo, tdi, tck, tms, tdi_int;
  wire     bbc_phi0_filt;  
  wire     j0, j1;
  wire     dec_fe4x;
  wire     dec_shadow_reg;
  wire     dec_rom_reg;
  // decoupling caps
  // Radial electolytic, one per board
  cap22uf  c22u_0 (.minus(GND),.plus(VDD));
  cap100nf c100n_1 (.p0(GND), .p1(VDD));
  cap100nf c100n_2 (.p0(VDD), .p1(GND));
  cap100nf c100n_3 (.p0(GND), .p1(VDD));
  cap100nf c100n_4 (.p0(VDD), .p1(GND));
  cap100nf c100n_5 (.p0(GND), .p1(VDD));
  cap100nf_smd c100n_10 (.p0(GND), .p1(VDD));
  cap100nf_smd c100n_11 (.p0(GND), .p1(VDD));
  cap100nf_smd c100n_12 (.p0(GND), .p1(VDD));  
  
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
                .be(VDD),
                .phi2in(cpu_phi2),
                .mx(),
                .vda(cpu_vda),
                .rstb(resetb)
                );
  
  
  
  smallcap c100pf_LPF (
                       .p1(bbc_phi0_filt),
                       .p0(GND)                       
                       );
  
  resistor r47_LPF(
                   .p0(bbc_phi0_filt),
                   .p1(bbc_phi0)                   
                   );
  
  
  
  // Alliance 512K x 8 SRAM - address pins wired to suit layout
  bs62lv4006  SRAM (
                    .a18(ram_a18),  .vcc(VDD),
                    .a16(ram_a16),  .a15(ram_a15),
                    .a14(ram_a14),  .a17(ram_a17), 
                    .a12(cpu_a13),  .web(ram_web),
                    .a7(cpu_a12),   .a13(cpu_a0),
                    .a6(cpu_a11),   .a8(cpu_a1),
                    .a5(cpu_a10),   .a9(cpu_a2),
                    .a4(cpu_a4),    .a11(cpu_a3),
                    .a3(cpu_a6),    .oeb(ram_oeb),
                    .a2(cpu_a7),    .a10(cpu_a5),
                    .a1(cpu_a8),    .csb(ram_ceb),
                    .a0(cpu_a9),    .d7(cpu_d0),
                    .d0(cpu_d5),    .d6(cpu_d1),
                    .d1(cpu_d6),    .d5(cpu_d2),
                    .d2(cpu_d7),    .d4(cpu_d3),
                    .vss(GND),      .d3(cpu_d4)
                   );

   // L1B CPLD in PLCC84 pin socket (can be 9572 or 95108)
  xc95108_pc84  CPLD (

                      // RHS (lower)
		      .p75(bbc_d7),
		      .gts1(bbc_d6),
		      .gts2(bbc_d5),
		      .vccint3(VDD),
		      .p79(bbc_a14),
		      .p80(bbc_d4),
		      .p81(bbc_a13),
		      .p82(bbc_a12),
		      .p83(bbc_a15),
		      .p84(bbc_d3)                      
                      // RHS (upper)
		      .p1(bbc_d2),
		      .p2(bbc_d1),
		      .p3(bbc_d0),
		      .p4(bbc_sync),
		      .p5(bbc_rnw),
		      .p6(bbc_phi1),
		      .p7(tp0),
		      .gnd1(GND),
		      .gck1(bbc_phi0_filt),
		      .gck2(hsclk),
		      .p11(tp1),

                      // TOP
		      .gck3(bbc_phi2),
		      .p13(rdy),
		      .p14(j1),
		      .p15(j0),
		      .gnd2(GND),
		      .p17(),
		      .p18(ram_ceb),
		      .p19(ram_oeb),
		      .p20(ram_a14),
		      .p21(ram_a15),
		      .vccio1(VDD),
		      .p23(ram_a18),
		      .p24(ram_a17),
		      .p25(ram_a16),
		      .p26(ram_web),
		      .gnd3(GND),
		      .tdi(tdi),
		      .tms(tms),
		      .tck(tck),
		      .p31(nmib),
		      .p32(irqb),

                      // LHS
		      .p33(cpu_vda),
		      .p34(cpu_vpb),
		      .p35(cpu_vpa),
		      .p36(cpu_phi2),
		      .p37(cpu_e),
		      .vccint1(VDD),
		      .p39(cpu_rnw),
		      .p40(cpu_d0),
		      .p41(cpu_d1),
		      .gnd4(GND),
		      .p43(cpu_d2),
		      .p44(cpu_d3),
		      .p45(cpu_d4),
		      .p46(cpu_d5),
		      .p47(cpu_d6),
		      .p48(cpu_d7),
		      .gnd5(GND),
		      .p50(cpu_a0),
		      .p51(cpu_a1),
		      .p52(cpu_a2),
		      .p53(cpu_a3),

                      // Bottom
		      .p54(cpu_a4),
		      .p55(cpu_a5),
		      .p56(cpu_a6),
		      .p57(cpu_a7),
		      .p58(cpu_a8),
		      .tdo(tdi_int),
		      .gnd6(GND),
		      .p61(cpu_a9),
		      .p62(cpu_a10),
		      .p63(cpu_a11),
		      .vccio2(VDD),
		      .p65(cpu_a12),
		      .p66(cpu_a13),
		      .p67(cpu_a14),
		      .p68(cpu_a15),
		      .p69(lat_en),
		      .p70(dec_rom_reg),
		      .p71(dec_shadow_reg),
		      .p72(dec_fe4x),
		      .vccint2(VDD),
		      .gsr(resetb),

                     );


  // 9572 CPLD 
  xc9572pc44  CPLD2 (
                    .p1(dec_fe4x),
	            .p2(dec_shadow_reg),
	            .p3(dec_rom_reg),
	            .p4(lat_en),
	            .gck1(cpu_a15),
	            .gck2(cpu_a14),
	            .gck3(cpu_a13),
	            .p8(cpu_a12),
	            .p9(cpu_a11),
	            .gnd1(GND),
	            .p11(cpu_a10),
	            .p12(cpu_a9),
	            .p13(cpu_a8),
	            .p14(cpu_a7),
	            .tdi(tdi_int),
	            .tms(tms),
	            .tck(tck),
	            .p18(cpu_a6),
	            .p19(cpu_a5),
	            .p20(cpu_a4),
	            .vccint1(VDD),
	            .p22(cpu_a3),
	            .gnd2(GND),
	            .p24(cpu_a2),
	            .p25(cpu_a1),
	            .p26(cpu_a0),
	            .p27(bbc_a10),
	            .p28(bbc_a11),
	            .p29(bbc_a9),
	            .tdo(tdo),
	            .gnd3(GND),
	            .vccio(VDD),
	            .p33(bbc_a8),
	            .p34(bbc_a7),
	            .p35(bbc_a6),
	            .p36(bbc_a5),
	            .p37(bbc_a4),
	            .p38(bbc_a3),
	            .gsr(bbc_a2),
	            .gts2(bbc_a1),
	            .vccint2(VDD),
	            .gts1(j1),
	            .p43(j0),
	            .p44(bbc_a0),
                    );


   // Socket for CMOS oscillator
   cmos_osc_14 OSC (
                    .gnd(GND),
                    .vdd(VDD),
                    .en(VDD),
                    .clk(hsclk)
                   );

   // 40W Plug which connects via IDC cable and header into the
   // host computer's 6502 CPU socket
   skt6502_40w CON (
                    .vss(GND),
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
                    .rstb(resetb)
                   );

  hdr2x05   tstpt(
                  .p1(GND),   .p2(GND),
                  .p3(tp0), .p4(tp1),
                  .p5(GND), .p6(GND),
                  .p7(j0), .p8(j1),
                  .p9(VDD),   .p10(VDD),
                  );

  hdr1x02   tclk(
                 .p1(bbc_phi0_filt),
                 .p2(GND)
                 );
  
  

   // jtag header for in system programming (same pinout as MacMall Breakout board
   // so that we can use existing cable).
  hdr8way jtag (
                .p1(GND),  .p2(GND),
                .p3(tms),  .p4(tdi),
                .p5(tdo),  .p6(tck),
                .p7(VDD),  .p8(),
               );

endmodule
