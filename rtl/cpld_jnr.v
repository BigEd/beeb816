`timescale 1ns / 1ns

`define ELK_PAGED_ROM_SEL 16'hFE05
`define PAGED_ROM_SEL 16'hFE30
`define BPLUS_SHADOW_RAM_SEL 16'hFE34

module cpld_jnr (
                 input [15:0]  cpu_adr,
                 input [1:0]   j,
                 input         lat_en,
                 output        dec_shadow_reg,
                 output        dec_rom_reg,
                 output        dec_fe4x,
                 output [11:0] bbc_adr
		 );

  wire                         elk_mode_w;
  wire                         beeb_mode_w;
  wire                         bplus_mode_w;
  wire                         master_mode_w;

  reg [11:0]                   bbc_adr_lat_q;

  // Decode jumpers on J[1:0]
  assign beeb_mode_w = (j==2'b00);
  assign bplus_mode_w = (j==2'b01);
  assign elk_mode_w = (j==2'b10);
  assign master_mode_w = (j==2'b11);

  assign bbc_adr = bbc_adr_lat_q;
  assign dec_shadow_reg = (bplus_mode_w) ? (cpu_adr==`BPLUS_SHADOW_RAM_SEL) : 1'b0;
  assign dec_rom_reg = (elk_mode_w)? (cpu_adr==`ELK_PAGED_ROM_SEL) : (cpu_adr==`PAGED_ROM_SEL);
  assign dec_fe4x = (cpu_adr[15:4]==12'hFE4);

  always @ ( * )
    if ( lat_en  )
      bbc_adr_lat_q <= cpu_adr[11:0];


endmodule
