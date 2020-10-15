`timescale 1ns / 1ns

// Minimum boot configuration in emulation mode only
// ---------------------------------------------------------------------------
// Optional switches:
//
// Use latches from BBC databus to CPU
`define USE_DATA_LATCHES_BBC2CPU 1
//
// Use latches from CPU databus to BBC
`define USE_DATA_LATCHES_CPU2BBC 1
//
// Define just one of these to get minimum PHI0->PHI2 delay or
// additional delay in increments of 2 inverter delays
//`define DELAY1 1
//`define DELAY2 1
//`define DELAY3 1
`ifndef DELAY2
  `ifndef DELAY3
    `define DELAY1 1
  `endif
`endif
// --------------------------------------------------------------------------
module level1b_mk2_m (
                      input [15:0]  cpu_adr,
                      input         resetb,
                      input         cpu_vpb,
                      input         cpu_e,
                      input         cpu_vda,
                      input         cpu_vpa,
                      input         bbc_phi0,
                      input         hsclk,
                      input         cpu_rnw,
                      inout [7:0]   cpu_data,
                      inout [7:0]   bbc_data,
                      inout [5:0]   gpio,
                      inout         rdy,
                      inout         nmib,
                      inout         irqb,
                      output        lat_en,
                      output        ram_web,
                      output        ram_ceb,
                      output        ram_oeb,
                      output        ram_adr18,
                      output        ram_adr17,
                      output        ram_adr16,
                      output        bbc_sync,
                      output [15:8] bbc_adr,
                      output        bbc_rnw,
                      output        bbc_phi1,
                      output        bbc_phi2,
                      output        cpu_phi2
                      );

`ifdef USE_DATA_LATCHES_BBC2CPU
  reg [7:0]                         bbc_data_lat_q;
`endif
`ifdef USE_DATA_LATCHES_CPU2BBC
  reg [7:0]                         cpu_data_lat_q;
`endif

  // Force keep intermediate nets to preserve strict delay chain for clocks
  (* KEEP="TRUE" *) wire ckdel_1_b;
  (* KEEP="TRUE" *) wire ckdel_2;
  (* KEEP="TRUE" *) wire ckdel_3_b;
  (* KEEP="TRUE" *) wire ckdel_4;
  (* KEEP="TRUE" *) wire ckdel_5_b;
  (* KEEP="TRUE" *) wire ckdel_6;
  INV    ckdel1   ( .I(bbc_phi0),  .O(ckdel_1_b));
  INV    ckdel2   ( .I(ckdel_1_b), .O(ckdel_2));
  INV    ckdel3   ( .I(ckdel_2),   .O(ckdel_3_b));
  INV    ckdel4   ( .I(ckdel_3_b), .O(ckdel_4));
  INV    ckdel5   ( .I(ckdel_4),   .O(ckdel_5_b));
  INV    ckdel6   ( .I(ckdel_5_b), .O(ckdel_6));

  // Pick clock delays from delay chain as required
`ifdef DELAY1  
  assign bbc_phi1 = ckdel_1_b;
  assign bbc_phi2 = ckdel_2;
`endif  
`ifdef DELAY2
  assign bbc_phi1 = ckdel_3_b;
  assign bbc_phi2 = ckdel_4;
`endif
`ifdef DELAY3
  assign bbc_phi1 = ckdel_5_b;
  assign bbc_phi2 = ckdel_6;
`endif

  // Lock CPU to BBC clock for min boot
  assign cpu_phi2 = bbc_phi2;

  assign bbc_sync = cpu_vpa & cpu_vda;
  assign rdy = 1'bz;
  assign irqb = 1'bz;
  assign nmib = 1'bz;

  // Drive the all SRAM high address pins but keep it inactive
  assign { ram_adr16, ram_adr17, ram_adr18, gpio[2], gpio[1]}  = 0 ;
  assign { ram_ceb, gpio[0], ram_web}  = 3'b111;

  // Address latch to BBC always open (active high) for low bits, and upper bits driven from CPLD
  assign lat_en = 1'b1;
  assign bbc_adr = cpu_adr[15:8];
  assign bbc_rnw = cpu_rnw ;


  assign gpio[5] = ( !cpu_rnw & bbc_phi2); // Active HIGH tristate enable for CPLD->BBC databus
  assign gpio[4] = (  cpu_rnw & cpu_phi2); // Active HIGH tristate enable for CPLD->CPU databus
  
`ifdef USE_DATA_LATCHES_CPU2BBC
  assign bbc_data = ( !cpu_rnw & bbc_phi2) ? cpu_data_lat_q : { 8{1'bz}};
`else
  assign bbc_data = ( !cpu_rnw & bbc_phi2) ? cpu_data : { 8{1'bz}};
`endif

`ifdef USE_DATA_LATCHES_BBC2CPU
  assign cpu_data = ( cpu_rnw & cpu_phi2 ) ? bbc_data_lat_q : {8{1'bz}};
`else
  assign cpu_data = ( cpu_rnw & cpu_phi2 ) ? bbc_data : {8{1'bz}};
`endif

`ifdef USE_DATA_LATCHES_BBC2CPU
  // Latches for the BBC data open during PHI2 to be stable beyond cycle end
  always @ ( * )
    if ( bbc_phi2 )
      bbc_data_lat_q <= bbc_data;
`endif
  
`ifdef USE_DATA_LATCHES_CPU2BBC
  always @ ( * )
    if ( cpu_phi2 )
      cpu_data_lat_q <= cpu_data;
`endif
endmodule // level1b_m
