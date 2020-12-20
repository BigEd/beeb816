
`timescale 1ns / 1ns

`define ELK_PAGED_ROM_SEL 16'hFE05
`define PAGED_ROM_SEL 16'hFE30
`define BPLUS_SHADOW_RAM_SEL 16'hFE34

// Decode jumpers on J[1:0]
`define BEEB_MODE   (j==2'b00)
`define BPLUS_MODE  (j==2'b01)
`define ELK_MODE    (j==2'b10)
`define MASTER_MODE (j==2'b11)
module cpld_jnr (
                 input [15:0]  cpu_adr,
                 input [1:0]   j,
                 input         lat_en,
                 output        dec_shadow_reg,
                 output        dec_rom_reg,
                 output        dec_fe4x,
                 output [11:0] bbc_adr
		 );

  reg [11:0]                   bbc_adr_lat_q;

  assign bbc_adr = bbc_adr_lat_q;
  assign dec_shadow_reg = (`BPLUS_MODE) ? (cpu_adr==`BPLUS_SHADOW_RAM_SEL) : 1'b0;
  assign dec_rom_reg = (`ELK_MODE)? (cpu_adr==`ELK_PAGED_ROM_SEL) : (cpu_adr==`PAGED_ROM_SEL);

  // Flag FE4x (VIA) accesses and also all &FC, &FD expansion pages 
  assign dec_fe4x = (cpu_adr[15:4]==12'hFE4) || (cpu_adr[15:9]==7'b1111_110);

  always @ ( * )
    if ( lat_en  )
      bbc_adr_lat_q <= cpu_adr[11:0];

endmodule
