`timescale 1ns / 1ns
//
// Option2 PCB Respin - main CPLD code
//
// Interrupts are not handled in '816 mode so leave this undefined for now
//`ifdef REMAP_NATIVE_INTERRUPTS_D
// Depth of pipeline to delay switches to HS clock after an IO access. Need more cycles for
// faster clocks so ideally this should be linked with the divider setting. Over 16MHz needs
// 5 cycles but 13.8MHz seems ok with 4.
`define IO_ACCESS_DELAY_SZ     5
// Define this to get a clean deassertion/reassertion of RAM CEB but this limits some
// setup time from CEB low to data valid etc. Not an issue in a board with a faster
// SMD RAM so expect to set this in the final design, but omitting it can help with
// speed in the proto
//`define ASSERT_RAMCEB_IN_PHI2  1
//
// Define this for the Acorn Electron instead of BBC Micro
// `define ELECTRON 1
//
// Define this for BBC B+/Master Shadow RAM control
//`define MASTER_SHADOW_CTRL 1
//
// Use data latches on CPU2BBC and/or BBC2CPU data transfers to improve hold times
`define USE_DATA_LATCHES_BBC2CPU 1
//`define USE_DATA_LATCHES_CPU2BBC 1
//
// Put latches on adr bits 13..8 (already have explicit latches on 14 and 15)
//`define USE_ADR_LATCHES_CPU2BBC 1
//
// Define this to use fast reads/slow writes to Shadow as with the VRAM to simplify decoding
//`define CACHED_SHADOW_RAM 1
//`define DIRECT_DRIVE_A13_A8
//`define NO_SELECT_FLOPS 1
`define WRITE_PROTECT_REMAPPED_ROM 1
//
// Define this so that *TURBO enables both MOS and APPs ROMs
`define UNIFY_ROM_REMAP_BITS 1
//
// Define this to delay the BBC_RNW low going edge by 2 inverter delays
`define DELAY_RNW_LOW  1

`define MAP_CC_DATA_SZ         8
`define SHADOW_MEM_IDX         7
`define MAP_ROM_IDX            4
`ifdef UNIFY_ROM_REMAP_BITS
  `define MAP_MOS_IDX          `MAP_ROM_IDX
`else
  `define MAP_MOS_IDX            5
`endif
`define MAP_HSCLK_EN_IDX       2
`define CLK_CPUCLK_DIV_IDX_HI  1
`define CLK_CPUCLK_DIV_IDX_LO  0
`define BBC_PAGEREG_SZ         4    // only the bottom four ROM selection bits

`ifdef MASTER_SHADOW_CTRL
`define CPLD_REG_SEL_SZ        3
`define CPLD_REG_SEL_BBC_SHADOW_IDX 2
`else
`define CPLD_REG_SEL_SZ        2
`endif
`define CPLD_REG_SEL_MAP_CC_IDX 1
`define CPLD_REG_SEL_BBC_PAGEREG_IDX 0

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
