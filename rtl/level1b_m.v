`timescale 1ns / 1ns

// Interrupts are not handled in '816 mode


// Use data latches on CPU2BBC and/or BBC2CPU data transfers to improve hold times
`define USE_DATA_LATCHES_BBC2CPU 1
`define USE_DATA_LATCHES_CPU2BBC 1

// RAM_MAPPED_ON_BOOT_D allows the CPLD to boot with the RAM mapping already
// enabled. This won't work with systems like the Oric which have IO space
// at the bottom of the address map, but is generally ok for the BBC and may
// fix Ed's flakey BBC.

//`define RAM_MAPPED_ON_BOOT_D 1

`define MAP_CC_DATA_SZ     7
`define MAP_HSCLK_EN_IDX   6
`define MAP_ROM_IDX        5
`define MAP_RAM_IDX        4
`define CLK_CPUCLK_DIV_IDX_HI  1
`define CLK_CPUCLK_DIV_IDX_LO  0

`define BBC_PAGEREG_SZ     4    // only the bottom four ROM selection bits
`define CPLD_REG_SEL_SZ    2

`define CPLD_REG_SEL_MAP_CC_IDX 1
`define CPLD_REG_SEL_BBC_PAGEREG_IDX 0

// Address of ROM selection reg in BBC memory map
`define BBC_PAGED_ROM_SEL 16'hFE30
// Assume that BBC ROM is at slot FF ( or at least ends with LSBs set...)
`define BASICROM_NUMBER 4'b1111
`define GPIO_SZ 7

module level1b_m (
                  input [15:0]         addr,
                  input                resetb,
                  input                vpb,
                  input                cpu_e,
                  input                vda,
                  input                vpa,
                  input                bbc_ck2_phi0,
                  input                hsclk,
                  input                rnw,
                  inout [7:0]          cpu_data,
                  inout [7:0]          bbc_data,
                  inout                rdy,
                  inout                nmib,
                  inout                scl,
                  inout                sda,
                  inout                irqb,
                  inout [`GPIO_SZ-1:0] gpio,
                  output               ram_ceb,
                  output               ram_addr18,
                  output               ram_addr17,
                  output               ram_addr16,
                  output               bbc_sync,
                  output               bbc_addr15,
                  output               bbc_addr14,
                  output               bbc_rnw,
                  output               bbc_ck2_phi1,
                  output               bbc_ck2_phi2,
                  output               cpu_ck_phi2
		  );

  reg [7:0]                            cpu_hiaddr_lat_q;
  reg [7:0]                            cpu_data_r;
`ifdef USE_DATA_LATCHES_BBC2CPU
  reg [7:0]                            bbc_data_lat_q;
`endif
`ifdef USE_DATA_LATCHES_CPU2BBC
  reg [7:0]                            cpu_data_lat_q;
`endif
  // This is the internal register controlling which features like high speed clocks etc are enabled
  reg [ `CPLD_REG_SEL_SZ-1:0]          cpld_reg_select_q;
  // This will be a copy of the BBC ROM page register so we know which ROM is selected
  reg [`BBC_PAGEREG_SZ-1:0]            bbc_pagereg_q;
  reg [`MAP_CC_DATA_SZ-1:0]            map_data_q;
  reg                                  himem_vram_wr_lat_q;
  reg                                  remapped_rom_access_r ;
  reg                                  remapped_ram_access_r ;

  wire [ `CPLD_REG_SEL_SZ-1:0]         cpld_reg_select_d;
  wire [7:0]                           cpu_hiaddr_lat_d;
  wire                                 rdy_w;
  wire                                 cpu_ck_phi1_w;
  wire                                 cpu_ck_phi2_w;
  wire                                 hs_selected_w;
  wire                                 ls_selected_w;
  wire                                 himem_vram_wr_d;
  wire                                 dummy_access_w;
  wire                                 select_hs_w;
  wire                                 hs_clk_w;
  wire                                 native_mode_int_w;
  wire                                 himem_w;

  // Force keep intermediate nets to preserve strict delay chain for clocks
  (* KEEP="TRUE" *) wire ckdel_1_b, ckdel_3_b;
  (* KEEP="TRUE" *) wire ckdel_2, ckdel_4;
  (* KEEP="TRUE" *) wire cpuckdel_1_b, cpuckdel_2;
  (* KEEP="TRUE" *) wire cpuckdel_3_b, cpuckdel_4;

  INV    ckdel1   ( .I(bbc_ck2_phi0), .O(ckdel_1_b));
  INV    ckdel2   ( .I(ckdel_1_b),    .O(ckdel_2));
  INV    ckdel3   ( .I(ckdel_2),      .O(ckdel_3_b));
  INV    ckdel4   ( .I(ckdel_3_b),    .O(ckdel_4));

  INV    ckdel5   ( .I(cpuclk_w),     .O(cpuckdel_1_b));
  INV    ckdel6   ( .I(cpuckdel_1_b), .O(cpuckdel_2));
  INV    ckdel7   ( .I(cpuckdel_2),   .O(cpuckdel_3_b));
  INV    ckdel8   ( .I(cpuckdel_3_b), .O(cpuckdel_4));

  clkctrl U_0 (
               .hsclk_in(hsclk),
               .lsclk_in(ckdel_3_b),
               .rst_b(resetb),
               .hsclk_sel(select_hs_w),
               .cpuclk_div_sel(map_data_q[`CLK_CPUCLK_DIV_IDX_HI:`CLK_CPUCLK_DIV_IDX_LO]),
               .hsclk_selected(hs_selected_w),
               .lsclk_selected(ls_selected_w),
               .clkout(cpu_ck_phi1_w)
               );

  assign cpu_ck_phi2_w = !cpu_ck_phi1_w ;
  assign cpu_ck_phi2 =  cpu_ck_phi2_w ;
//  assign bbc_ck2_phi1 = cpu_ck_phi1_w;
//  assign bbc_ck2_phi2 = !cpu_ck_phi1_w;
  assign bbc_ck2_phi1 = ckdel_3_b;
  assign bbc_ck2_phi2 = ckdel_4;

  assign bbc_sync = vpa & vda;
  assign rdy = 1'bz;
  assign irqb = 1'bz;
  assign nmib = 1'bz;
  assign sda = 1'bz;
  assign scl = 1'bz;
  // Bring out signals for observation on GPIO
  assign gpio = {`GPIO_SZ{1'bz}};

`ifdef REMAP_NATIVE_INTERRUPTS_D
  // Native mode interrupts will be redirected to himem
  assign native_mode_int_w = !vpb & !cpu_e ;
`else
  assign native_mode_int_w = 1'b0;
`endif

  // Drive the all RAM address pins, allowing for 512K RAM connection
  assign ram_addr16 = cpu_hiaddr_lat_q[0] ;
  assign ram_addr17 = cpu_hiaddr_lat_q[1] ;
  assign ram_addr18 = cpu_hiaddr_lat_q[2] ;

  // All addresses starting 0b11 go to the on-board RAM
  assign ram_ceb = !( cpu_ck_phi2_w && (vda | vpa ) && (cpu_hiaddr_lat_q[7:6] == 2'b11) );

  // All addresses starting with 0b10 go to internal IO registers which update on the
  // rising edge of cpu_ck_phi1 - use the cpu_data bus directly for the high address
  // bits since it's stable by the end of phi1
  assign cpld_reg_select_d[`CPLD_REG_SEL_MAP_CC_IDX] = vda && ( cpu_data[7:6]== 2'b10) && ( addr[1:0] == 2'b11);
  assign cpld_reg_select_d[`CPLD_REG_SEL_BBC_PAGEREG_IDX] = vda && (cpu_data[7]== 1'b0) && ( addr == `BBC_PAGED_ROM_SEL );
  // Force dummy read access when accessing himem explicitly but not for remapped RAM accesses which can still complete

  assign { bbc_addr15, bbc_addr14 } = ( dummy_access_w ) ? { 2'b10 } : { addr[15], addr[14] } ;
  assign bbc_rnw = rnw | dummy_access_w ;
`ifdef USE_DATA_LATCHES_CPU2BBC
  assign bbc_data = ( !bbc_rnw & cpu_ck_phi2_w ) ? cpu_data_lat_q : { 8{1'bz}};
`else
  assign bbc_data = ( !bbc_rnw & cpu_ck_phi2_w ) ? cpu_data : { 8{1'bz}};
`endif
  assign cpu_data = cpu_data_r;

  // Assume only lowest 8K of RAM is not used for video
  assign himem_vram_wr_d = !cpu_data[7] & (map_data_q[`MAP_RAM_IDX] & !addr[15] & (addr[14]|addr[13]) & !rnw & (vpa|vda)) ;
  // Select the high speed clock only
  // * on valid instruction fetches from himem, or
  // * on valid imm/data fetches from himem _if_ hs clock is already selected, or
  // * on invalid bus cycles if hs clock is already selected
  assign himem_w =  (cpu_hiaddr_lat_q[7] & !himem_vram_wr_lat_q);
  wire  hisync_w = vpa & vda & himem_w;
  assign select_hs_w = map_data_q[`MAP_HSCLK_EN_IDX] & (( hisync_w ) |
                                                        ((vpa | vda ) & himem_w & hs_selected_w) |
                                                        (!vpa & !vda & hs_selected_w)
                                                        ) ;
  assign dummy_access_w = (cpu_hiaddr_lat_q[7] & !himem_vram_wr_lat_q) | !ls_selected_w ;

  // ROM remapping
  always @ ( * )
    if (!cpu_data[7] & map_data_q[`MAP_ROM_IDX] & addr[15] & (vpa|vda))
      // Remap MOS from C000-FBFF only (exclude IO space and vectors)
      if ( addr[14] & !(&(addr[13:10])))
        remapped_rom_access_r = 1;
      else if ( !addr[14] & (bbc_pagereg_q[`BBC_PAGEREG_SZ-1:0] == `BASICROM_NUMBER))
        remapped_rom_access_r = 1;
      else
        remapped_rom_access_r = 0;
    else
      remapped_rom_access_r = 0;

  // RAM remapping - remap all of 32K RAM for reads and writes while CPU runs at BBC clock speed,
  // but HS clock switching will need to care for which RAM is being used for video when writing
  always @ ( * )
    if (!cpu_data[7] & map_data_q[`MAP_RAM_IDX] & !addr[15] & (vpa|vda))
      remapped_ram_access_r = 1;
    else
      remapped_ram_access_r = 0;

  assign cpu_hiaddr_lat_d[7:1] = cpu_data[7:1] | { 7{remapped_ram_access_r | remapped_rom_access_r | native_mode_int_w} };

  // Remapped accesses all go too the range FE0000 - FEFFFF, so don't set the bottom bit for these
  assign cpu_hiaddr_lat_d[0] = cpu_data[0] | native_mode_int_w;

  // drive cpu data if we're reading internal register or making a non dummy read from lomem
  always @ ( * )
    if ( cpu_ck_phi2_w & rnw  )
      begin
	if (cpu_hiaddr_lat_q[7])
	  if ( cpld_reg_select_q[`CPLD_REG_SEL_MAP_CC_IDX]  )
            cpu_data_r = { {(8-`MAP_CC_DATA_SZ){1'b0}}, map_data_q};
          else //must be RAM access
            cpu_data_r = {8{1'bz}};
        else
`ifdef USE_DATA_LATCHES_BBC2CPU
          cpu_data_r = bbc_data_lat_q;
`else
          cpu_data_r = bbc_data;
`endif
      end // if ( cpu_ck_phi1_w & rnw )
    else
      cpu_data_r = {8{1'bz}};

  // -------------------------------------------------------------
  // All inferred flops and latches below this point
  // -------------------------------------------------------------

  // Internal registers update on the rising edge of cpu_ck_phi1
  always @ ( posedge cpu_ck_phi1_w or negedge resetb )
    if ( !resetb )
      begin
`ifdef RAM_MAPPED_ON_BOOT_D
        map_data_q[`MAP_ROM_IDX]      <= 1'b0;
        map_data_q[`MAP_RAM_IDX]      <= 1'b1;
        map_data_q[`CLK_HSCLK_EN_IDX] <= 1'b0;
        map_data_q[`CLK_HSCLK_INV_IDX]<= 1'b0;
        map_data_q[`CLK_DIV_EN_IDX]   <= 1'b0;
        map_data_q[`CLK_DIV4NOT2_IDX] <= 1'b0;
`else
        map_data_q <= {`MAP_CC_DATA_SZ{1'b0}};
`endif
        bbc_pagereg_q <= {`BBC_PAGEREG_SZ{1'b0}};
      end
    else
      begin
        if (  cpld_reg_select_q[`CPLD_REG_SEL_MAP_CC_IDX] & !rnw )
   	  map_data_q <= cpu_data;
        else if (cpld_reg_select_q[`CPLD_REG_SEL_BBC_PAGEREG_IDX] & !rnw )
          bbc_pagereg_q <= cpu_data;
      end // else: !if( !resetb )


  // Flop all the internal register select bits on falling edge of phi1
  // for use on rising edge of phi2
  always @ ( negedge cpu_ck_phi1_w or negedge resetb )
    if ( !resetb )
      cpld_reg_select_q = { `CPLD_REG_SEL_SZ{1'b0}};
    else
      cpld_reg_select_q = cpld_reg_select_d ;

  // Latches for the high address bits open during PHI1
  always @ ( * )
    if ( ! resetb )
      begin
        cpu_hiaddr_lat_q <= 8'b0;
        himem_vram_wr_lat_q <= 1'b0;
      end
    else if ( cpu_ck_phi1_w )
      begin
        cpu_hiaddr_lat_q <= cpu_hiaddr_lat_d;
        himem_vram_wr_lat_q <= himem_vram_wr_d;
      end

`ifdef USE_DATA_LATCHES_BBC2CPU
  // Latches for the BBC data open during PHI2 to be stable beyond cycle end
  always @ ( * )
    if ( !bbc_ck2_phi1 )
      bbc_data_lat_q <= bbc_data;
`endif

`ifdef USE_DATA_LATCHES_CPU2BBC
  always @ ( * )
    if ( cpu_ck_phi2_w )
      cpu_data_lat_q <= cpu_data;
`endif


endmodule // level1b_m
