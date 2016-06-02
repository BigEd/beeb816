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
   wire    a0, a1, a2, a3, a4, a5, a6, a7, a8, a9,
           a10, a11, a12, a13, a14, a15;
   wire    vpa, vda, vpb, e, rdnw, rstb, irqb, nmib;
   wire    bbc_a15, bbc_a14, bbc_rdnw;
   wire    cpu_a16, cpu_a17, cpu_a18;   
   wire    ram_ceb;
   wire    rdy, sync;   
   wire    phi0, phi1, phi2, bbc_ck8, cpu_ck_phi2;
   wire    gpio0,gpio1,gpio2,gpio3,gpio4,gpio5,gpio6;   
   wire    tdo, tdi, tck, tms;
   wire    lnk1, lnk2;
   // Define wires for some spare pins to bring to the breakout socket
   wire    p26, p6, p7, gck3, gck2,  p11, scl, sda;

   
   // decoupling caps
   // Radial electolytic, one per board
   cap22uf cap22uf_0(.minus(VSS),.plus(VDD));

   // Multiple SMD decoupling caps for each IC   
   cap100nf_smd cap100nf_1 (.p0( VSS ), .p1( VDD ));
   cap100nf_smd cap100nf_3 (.p0( VSS ), .p1( VDD ));
   cap100nf_smd cap100nf_6 (.p0( VSS ), .p1( VDD ));
   cap100nf_smd cap100nf_7 (.p0( VSS ), .p1( VDD ));
   cap100nf_smd cap100nf_8 (.p0( VSS ), .p1( VDD ));
   cap100nf_smd cap100nf_9 (.p0( VSS ), .p1( VDD ));
   cap100nf_smd cap100nf_10 (.p0( VSS ), .p1( VDD ));      

   // Pull up resistors for I2C nets
   resistor sda_r4k7_pu( .p1( VDD ), .p0( sda ));
   resistor scl_r4k7_pu( .p1( VDD ), .p0( scl ));
   
   // WDC 65816 CPU
   wdc65816 IC1 (
            .vpb(vpb),
            .rdy(rdy),
            .abortb(VDD),
            .irqb(irqb),
            .mlb(),
            .nmib(nmib),
            .vpa(vpa),
            .vcc(VDD),
            .a0(a0),
            .a1(a1),
            .a2(a2),
            .a3(a3),
            .a4(a4),
            .a5(a5),
            .a6(a6),
            .a7(a7),
            .a8(a8),
            .a9(a9),                        
            .a10(a10),                        
            .a11(a11),
            .vss2(VSS),
            .a12(a12),
            .a13(a13),
            .a14(a14),
            .a15(a15),
            .d7(cpu_d7),
            .d6(cpu_d6),
            .d5(cpu_d5),
            .d4(cpu_d4),
            .d3(cpu_d3),
            .d2(cpu_d2),
            .d1(cpu_d1),
            .d0(cpu_d0),
            .rdnw(rdnw),
            .e(e),
            .be(VDD),
            .phi2in(cpu_ck_phi2),
            .mx(),
            .vda(vda),
            .rstb(rstb)
            );


   // Link block - see Twiki for link settings for different RAM types.
   // Note that CPLD needs to be aware that different RAMs have A11/A17/WE*/CE2
   // on different pins, so although these are all driven by CPLD the CPLD needs to
   // know which is which
   hdr1x05  link_blk (
                      .p1(cpu_a17),
                      .p2(lnk1),
                      .p3(VDD),
                      .p4(lnk2),
                      .p5(a13),                        
                      );
   
   // RAM instance - socket can take different sizes in conjunction with link block
   bs62lv1027 IC2 (
                   .a0(a0),
                   .a1(a1),
                   .a2(a2),
                   .a3(a3),
                   .a4(a4),
                   .a5(a5),
                   .a6(a6),
                   .a7(a7),
                   .a8(a8), 
                   .a9(a9), 
                   .a10(a10), 
                   .a11(a11), 
                   .a12(a12), 
                   .a13(lnk2),
                   .a14(a14), 
                   .a15(a15), 
                   .a16(cpu_a16), 
                   .d7(cpu_d7),
                   .d6(cpu_d6),
                   .d5(cpu_d5),
                   .d4(cpu_d4),
                   .d3(cpu_d3),
                   .d2(cpu_d2),
                   .d1(cpu_d1),
                   .d0(cpu_d0),
                   .nc1(cpu_a18), // makes us compatible with 512KB RAM
                   .vss(VSS),
                   .vdd(VDD),
                   .ceb(ram_ceb),
                   .ce2(lnk1),// see link block for RAM selection
                   .web(rdnw),
                   .oeb(ram_ceb)
                   );

   // L1B CPLD in PLCC84 pin socket (can be 9572 or 95108)
   L1B_9572 IC3 (
                 .gpio0(gpio0),
                 .gpio1(gpio1),
                 .gpio2(gpio2),
                 .gpio3(gpio3),
                 .gpio4(gpio4),
                 .gpio5(gpio5),
                 .gpio6(gpio6),
		 .cpu_clk_phi2(cpu_ck_phi2),
		 .cpu_vpb(vpb),
		 .cpu_vpa(vpa),      
		 .cpu_vda(vda),
		 .bbc_ck8(bbc_ck8),                 
		 .bbc_ck_phi0(phi0),
		 .ram_addr16(cpu_a16),
		 .ram_addr17(cpu_a17),
		 .ram_addr18(cpu_a18),                                  
		 .ram_ceb(ram_ceb),
		 .rdy(rdy),
                 .sync(sync),                 
		 .bbc_ck_phi1(phi1),
		 .bbc_rdnw(bbc_rdnw),
		 .bbc_addr15(bbc_a15),
		 .bbc_data0(bbc_d0),
		 .bbc_data1(bbc_d1),
		 .bbc_data2(bbc_d2),
		 .bbc_data3(bbc_d3),
		 .bbc_data4(bbc_d4),
		 .bbc_data5(bbc_d5),
		 .bbc_data6(bbc_d6),
		 .bbc_data7(bbc_d7),                 
		 .cpu_data0(cpu_d0),
		 .cpu_data1(cpu_d1),
		 .cpu_data2(cpu_d2),
		 .cpu_data3(cpu_d3),
		 .cpu_data4(cpu_d4),
		 .cpu_data5(cpu_d5),
		 .cpu_data6(cpu_d6),
		 .rstb(rstb),
		 .cpu_data7(cpu_d7),
		 .cpu_addr15(a15),
		 .cpu_addr14(a14),
		 .cpu_addr13(a13),
		 .cpu_addr12(a12),
		 .cpu_addr11(a11),
		 .cpu_addr10(a10),                 
		 .cpu_addr9(a9),
		 .cpu_addr8(a8),                 
		 .cpu_addr7(a7),                 
		 .cpu_addr6(a6),
		 .cpu_addr5(a5),                                  
		 .cpu_addr4(a4),                                  
		 .cpu_addr3(a3),
		 .cpu_addr2(a2),                                                   
		 .cpu_addr1(a1),                                                   
		 .cpu_addr0(a0),                                                                    
		 .cpu_rdnw(rdnw),
		 .cpu_e(e),
                 // JTAG - not used so connect to ground which lets us power up inner ring
                 .tck(tck),
                 .tms(tms),
                 .tdi(tdi),
                 .tdo(tdo),
                 // Supplies
                 // this is a func pin sacrificed to allow wide power routing to the inner circle
                 .auxgnd1(VSS),                  
                 .gnd1(VSS),
                 .gnd2(VSS),
                 .gnd3(VSS),
                 .gnd4(VSS),
                 .gnd5(VSS),
                 .gnd6(VSS),                      
                 .auxvdd1(VDD),
                 .vccint1(VDD),
                 .vccint2(VDD),
                 .vccint3(VDD),                 
                 .vccio1(VDD),
                 .vccio2(VDD),
                 .gck3(gck3),
                 .gck2(gck2),
                 .sda(sda),
                 .scl(scl),
                 .bbc_ck_phi2(phi2),                 
                 .bbc_addr14(bbc_a14),
                 // spare pins routed to breakout board
                 .p26(p26),
                 .p6(p6),
                 .p7(p7),
                 .p11(p11)
                 );
   

   // Socket for CMOS oscillator
   cmos_osc_14 IC4 (
                    .gnd(VSS),
                    .vdd(VDD),
                    .en(VDD),
                    .clk(bbc_ck8)
                    );

   // Socket for various 8 pin I2C ICs (see twiki)
   PCF8581 IC5 (.a0(VSS),    .vdd(VDD),
                .a1(VSS),    .test(),
                .a2(VSS),    .scl(scl),
                .vss(VSS),   .sda(sda)
                );

   // 40W Plug which connects via IDC cable and header into the
   // host computer's 6502 CPU socket
   skt6502_40w CON1 (
                     .vss(VSS),
                     .rdy(rdy),
                     .phi1out(phi1),
                     .irqb(irqb),
                     .nc1(),
                     .nmib(nmib),
                     .sync(sync),
                     .vcc(VDD),
                     .a0(a0),
                     .a1(a1),
                     .a2(a2),
                     .a3(a3),
                     .a4(a4),
                     .a5(a5),
                     .a6(a6),
                     .a7(a7),
                     .a8(a8),
                     .a9(a9),                        
                     .a10(a10),                        
                     .a11(a11),
                     .vss2(VSS),
                     .a12(a12),
                     .a13(a13),
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
                     .rdnw(bbc_rdnw),
                     .nc2(),
                     .nc3(),
                     .phi0in(phi0),
                     .so(),
                     .phi2out(phi2),
                     .rstb(rstb)
                     );
   
   // 20W Expansion connector
   idc_hdr_20w  con3 (
                      .p1(VSS),    .p2(bbc_ck8),
                      .p3(phi2),   .p4(p6),
                      .p5(p7),     .p6(p11),
                      .p7(sda),    .p8(gck3),
                      .p9(gpio0),  .p10(scl),
                      .p11(gpio1), .p12(gck2),
                      .p13(gpio3), .p14(gpio2),
                      .p15(p26),   .p16(gpio4),
                      .p17(gpio6), .p18(gpio5),
                      .p19(VDD),   .p20(bbc_a14)
                      );

   // 2 Pin header as on Level1 prototype for bringing BBC clock in
   pcbheader2  con2 (
              .clkin(bbc_ck8)
              );

   // jtag header for in system programming (same pinout as MacMall Breakout board
   // so that we can use existing cable).
   hdr8way jtaghdr (
                    .p1(VSS),  .p2(VSS),
                    .p3(tms),  .p4(tdi),
                    .p5(tdo),  .p6(tck),
                    .p7(VDD),  .p8(),
                    );
   
   // Power header is convenient if we allow in system programming and pin out
   // compatible with MacMall connector.
   powerheader3 pwrhdr(
                       .vdd1(VDD),
                       .vdd2(VDD),
                       .gnd(VSS)
                       );
endmodule
