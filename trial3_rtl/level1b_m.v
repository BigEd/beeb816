`timescale 1ns / 1ns

// Interrupts are not handled in '816 mode


// RAM_MAPPED_ON_BOOT_D allows the CPLD to boot with the RAM mapping already
// enabled. This won't work with systems like the Oric which have IO space
// at the bottom of the address map, but is generally ok for the BBC and may
// fix Ed's flakey BBC.

//`define RAM_MAPPED_ON_BOOT_D 1


`define MAP_HSCLK_SRST_B       7
`define MAP_HSCLK_ENABLE       6
`define MAP_ROM_IDX            5
`define MAP_RAM_IDX            4
`define CLK_HSCLK_DIV_IDX_HI   3
`define CLK_HSCLK_DIV_IDX_LO   2
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
  reg [7:0]                            cpu_hiaddr_raw_lat_q;
  reg [7:0]                            cpu_data_r;
  reg [7:0]                            bbc_data_lat_q;
  reg [ `CPLD_REG_SEL_SZ-1:0]          cpld_reg_select_q;
  reg                                  remapped_rom_access_r ;
  reg                                  remapped_ram_access_r ;
  // This will be a copy of the BBC ROM page register so we know which ROM is selected
  reg [`BBC_PAGEREG_SZ-1:0]            bbc_pagereg_q;
  // This is the internal register controlling which features like high speed clocks etc are enabled
  reg [7:0]                            map_data_q;
  reg                                  hsclk_sel_r;
  reg                                  hsclk_sel_q;

  wire [7:0]                           cpu_hiaddr_d;
  wire                                 rdy_w;
  wire                                 cpu_ck_phi1_w;
  wire                                 cpu_ck_phi2_w;
  wire                                 dummy_access_w;
  wire [ `CPLD_REG_SEL_SZ-1:0]         cpld_reg_select_d;
  wire                                 cpuclk_w;


  // Force keep intermediate nets to preserve strict delay chain for clocks
  (* KEEP="TRUE" *) wire ckdel_1_b, ckdel_3_b ;
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

  // CPU needs to be skewed late wrt the BBC clock
  assign bbc_ck2_phi1 = ckdel_1_b;
  assign bbc_ck2_phi2 = ckdel_2 ;
  assign cpu_ck_phi1_w = !cpuclk_w;
  assign cpu_ck_phi2_w = cpuclk_w;
  assign cpu_ck_phi2 =  cpu_ck_phi2_w ;

  assign bbc_sync = vpa & vda;
  assign rdy = 1'bz;
  assign irqb = 1'bz;
  assign nmib = 1'bz;
  assign sda = 1'bz;
  assign scl = 1'bz;
  // Bring out signals for observation on GPIO
  assign gpio = {
                  bbc_ck2_phi0,
                  hsclk,
                  cpuclk_w,
                  cpu_ck_phi2_w,
                  hsclk_sel_r,
                  hsclk_sel_q
                  };


  // Drive the all RAM address pins, allowing for 512K RAM connection
  assign ram_addr16 = cpu_hiaddr_lat_q[0] ;
  assign ram_addr17 = cpu_hiaddr_lat_q[1] ;
  assign ram_addr18 = cpu_hiaddr_lat_q[2] ;

  // All addresses starting 0b11 go to the on-board RAM
  assign ram_ceb = !( cpu_ck_phi2_w && (vda | vpa ) && (cpu_hiaddr_lat_q[7:6] == 2'b11) );

  // Force dummy read access when accessing himem explicitly but not for remapped RAM accesses which can still complete
  assign dummy_access_w = cpu_hiaddr_raw_lat_q[7] ;
  assign { bbc_addr15, bbc_addr14 } =  (dummy_access_w) ? 2'b10: { addr[15], addr[14] } ;
  assign bbc_rnw = rnw | dummy_access_w  ;
  assign bbc_data = ( !bbc_rnw & bbc_ck2_phi2 ) ? cpu_data :  8'bz;
  assign cpu_data = cpu_data_r;

  // All addresses starting with 0b10 go to internal IO registers which update on the
  // rising edge of cpu_ck_phi1 (falling edge of PHI2) - use the cpu_data bus directly
  // for the high address bits since it's stable by the end of phi1
  assign cpld_reg_select_d[`CPLD_REG_SEL_MAP_CC_IDX] = vda && ( cpu_data[7:6]== 2'b10) && ( addr[1:0] == 2'b11);
  assign cpld_reg_select_d[`CPLD_REG_SEL_BBC_PAGEREG_IDX] = vda && (cpu_data[7]== 1'b0) && ( addr == `BBC_PAGED_ROM_SEL );

  // HSCLK selection
  always @ ( * )
    begin
      if (map_data_q[`MAP_HSCLK_ENABLE] )
        begin
          if ( vpa & vda & rnw )                              // Switch on instruction fetch in high memory (remapped or native) or low memory
            hsclk_sel_r = cpu_hiaddr_lat_q[7];
          else if ( cpu_hiaddr_raw_lat_q[7] & (vda|vpa) )     // Stay in current clock for all (non-remapped) data accesses to high memory
            hsclk_sel_r = hsclk_sel_q; 
          else if ( cpu_hiaddr_lat_q[7] & rnw & (vda|vpa) )   // Stay in current clock for all remapped read accesses to high memory            
            hsclk_sel_r = hsclk_sel_q;
          else if ( cpu_hiaddr_lat_q[7] & !addr[14] & !addr[13] & (vda|vpa) )   // Stay in current clock for all remapped accesses to lowest 8K memory            
            hsclk_sel_r = hsclk_sel_q;          
          else if ( !vda & !vpa )                             // no clock change on 65816 mode internal cycles (vpa=vda=0)
            hsclk_sel_r = hsclk_sel_q;
          else                                                // Else default back to LS clock
            hsclk_sel_r = 1'b0;
        end
      else
        hsclk_sel_r = 1'b0;
    end // always @ ( * )

  // ROM remapping - use cpu_data[] to get high address bits during phi1
  always @ ( * )
    if (!cpu_data[7] & map_data_q[`MAP_ROM_IDX] & addr[15] & (vpa|vda))
      // Remap MOS from C000-FBFF only (exclude IO space and vectors)
      if ( addr[14] & !(&(addr[13:10])) & (vpa|vda))
        remapped_rom_access_r = 1;
      else if ( !addr[14] & (bbc_pagereg_q[`BBC_PAGEREG_SZ-1:0] == `BASICROM_NUMBER) & (vpa|vda))
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

  // Remapped memory goes to range FE0000-FEFFFF
  assign cpu_hiaddr_d = cpu_data | {{7{remapped_rom_access_r|remapped_ram_access_r}}, 1'b0};

  // drive cpu data if we're reading internal register or making a non dummy read from lomem
  always @ ( * )
    if ( cpu_ck_phi2_w & rnw )
      if (cpu_hiaddr_lat_q[7] & cpld_reg_select_q[`CPLD_REG_SEL_MAP_CC_IDX])
          cpu_data_r = map_data_q;
      else if (!cpu_hiaddr_lat_q[7])
        cpu_data_r = bbc_data_lat_q;
      else // Hi RAM access
        cpu_data_r = 8'bz;
    else
      cpu_data_r = 8'bz;

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
        map_data_q <= 7'b0;
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

  // HS clk is selected during phi2 so flop the signal at the end of the period
  always @ (posedge cpu_ck_phi1_w )
    if ( !resetb )
      hsclk_sel_q <= 1'b0;
    else
      hsclk_sel_q <= hsclk_sel_r;

  // Need an early copy of the high address bits before any remapping
  always @ ( * )
    if ( cpu_ck_phi1_w )
      cpu_hiaddr_raw_lat_q <= cpu_data;

  // Latch the high address bits at end of phi1 after any remapping
  always @ ( * )
    if ( cpu_ck_phi1_w )
      cpu_hiaddr_lat_q <= cpu_hiaddr_d;

  // Latches for the BBC data open during PHI2 to be stable beyond cycle end
  always @ ( * )
    if ( !bbc_ck2_phi1 )
      bbc_data_lat_q <= bbc_data;

  clkctrl2 U_0(
               .hsclk_in(hsclk),
               .lsclk_in(ckdel_4),
               .rst_b(resetb & map_data_q[`MAP_HSCLK_SRST_B]),
               .hsclk_sel(hsclk_sel_r),
               .hsclk_div_sel( map_data_q[`CLK_HSCLK_DIV_IDX_HI:`CLK_HSCLK_DIV_IDX_LO]),
               .cpuclk_div_sel(map_data_q[`CLK_CPUCLK_DIV_IDX_HI:`CLK_CPUCLK_DIV_IDX_LO]),
               .clkout(cpuclk_w)
               );

endmodule // level1b_m
