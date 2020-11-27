`timescale 1ns / 1ns

// Address of ROM selection reg in BBC memory map
`ifdef ELECTRON
  `define PAGED_ROM_SEL 16'hFE05
`else
  `define PAGED_ROM_SEL 16'hFE30
  // BBC B+ uses bit 7 of &FE34 for shadow RAM select
  `define SHADOW_RAM_SEL 16'hFE34
`endif

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
  assign dec_shadow_reg = (cpu_adr==`SHADOW_RAM_SEL);
  assign dec_rom_reg = (cpu_adr==`PAGED_ROM_SEL);
  assign dec_fe4x = (cpu_adr[15:4]==12'hFE4);
     
  always @ ( * )
    if ( lat_en  )
      bbc_adr_lat_q <= cpu_adr[11:0];


endmodule 
