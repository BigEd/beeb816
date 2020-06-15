`timescale 1ns / 1ns
// Minimal boot where the Beeb816 runs only in 6502 mode with BBC clocks to debug an
// issue where Beeb816 does not work happily with the PiTubeDirect in a Pi 1B board

`define GPIO_SZ 7


module emu6502 (
    input [15:0] addr,
    input        resetb,
    input 	 vpb,
    input 	 cpu_e,
    input 	 vda,
    input 	 vpa,
    input 	 bbc_ck2_phi0,
    input 	 bbc_ck8,
    input 	 rnw,
    inout [7:0]  cpu_data,
    inout [7:0]  bbc_data,
    inout 	 rdy,
    inout        nmib,
    inout 	 scl,
    inout 	 sda,
    inout        irqb,
    inout [`GPIO_SZ-1:0]  gpio,
    output       ram_ceb,
    output 	 ram_addr18,
    output 	 ram_addr17,
    output 	 ram_addr16,
    output       bbc_sync,
    output 	 bbc_addr15,
    output 	 bbc_addr14,
    output 	 bbc_rnw,
    output 	 bbc_ck2_phi1,
    output 	 bbc_ck2_phi2,
    output 	 cpu_ck_phi2
		  );

   reg [7:0]     cpu_data_r;
   reg [7:0]     bbc_data_r;

   (* KEEP="TRUE" *) wire ckdel_1_b, ckdel_3_b ;
   (* KEEP="TRUE" *) wire ckdel_2, ckdel_4;

   INV    ckdel1   ( .I(bbc_ck2_phi0), .O(ckdel_1_b));
   INV    ckdel2   ( .I(ckdel_1_b),    .O(ckdel_2));
   INV    ckdel3   ( .I(ckdel_2),      .O(ckdel_3_b));
   INV    ckdel4   ( .I(ckdel_3_b),    .O(ckdel_4));

   assign bbc_ck2_phi1 = ckdel_1_b;
   assign bbc_ck2_phi2 = ckdel_2;

   assign cpu_ck_phi2  = ckdel_2;

   assign bbc_sync = vpa & vda;
   assign rdy = 1'bz;
   assign irqb = 1'bz;
   assign nmib = 1'bz;
   assign { bbc_addr15, bbc_addr14 } =  { addr[15], addr[14] } ;
   assign bbc_rnw = rnw ;
   assign bbc_data = ( !rnw & bbc_ck2_phi2 ) ? cpu_data : { 8{1'bz}};

   // Drive data to 65816 databus only on PHI2 read operations (but increase hold time)
   assign cpu_data = ( rnw & cpu_ck_phi2 ) ? bbc_data   : {8{1'bz}};

   // Disable fast on-board RAM
   assign ram_addr16 = 1'b0;
   assign ram_addr17 = 1'b0;
   assign ram_addr18 = 1'b0;
   assign ram_ceb = 1'b1;

//   // Latch the CPU DATA bus so it doesn't change on PHI1 as 816 muxes address onto it
//   always @ ( * )
//     if ( cpu_ck_phi2 )
//       cpu_data_r = cpu_data;
//
//   always @ ( * )
//     if ( ckdel_2 )
//       bbc_data_r = bbc_data;
//

endmodule
