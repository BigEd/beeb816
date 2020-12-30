`timescale 1ns / 1ns
//
// Option2 PCB Respin - main CPLD code
//
// Depth of pipeline to delay switches to HS clock after an IO access. Need more cycles for
// faster clocks so ideally this should be linked with the divider setting. Over 16MHz needs
// 5 cycles but 13.8MHz seems ok with 4. Modified now to count SYNCs rather than cycles
`define IO_ACCESS_DELAY_SZ     3
//
// Define this to force-keep some clock nets to reduce design size
`define FORCE_KEEP_CLOCK 1

// Define to drive clocks to test points tp[1:0]
//`define OBSERVE_CLOCKS 1

// Set one of these to falling edge of RAMOEB by one buffer when running with fast SRAM
//`define DELAY_RAMOEB_BY_1
`define DELAY_RAMOEB_BY_2
//`define DELAY_RAMOEB_BY_3

// Defining this should improve speed at cost of additional FFs, but observed speed
// reduced in testing
//`define PIPELINE_ROM_CTRL 1

// Define this to add a simple deglitch circuit to the incoming BBC clock ahead of the
// clock switch
`define DEGLITCH_CLOCK_IN 1


// Define this to use fast reads/slow writes to Shadow as with the VRAM to simplify decoding
//`define CACHED_SHADOW_RAM 1
// Trial code to make VRAM area larger than default of 20K to simplify decoding(can be used with above)
`define VRAM_AREA_20K          (!cpu_data[7] & !cpu_adr[15] & (cpu_adr[14] | (cpu_adr[13]&cpu_adr[12])))
`define VRAM_AREA_24K          (!cpu_data[7] & !cpu_adr[15] & (cpu_adr[14] | cpu_adr[13]))
`define VRAM_AREA_32K          (!cpu_data[7] & !cpu_adr[15])
`define VRAM_AREA              `VRAM_AREA_20K

// Define this to have the host set the type field in the map register rather than define it by jumpers
// (And remember to remove the jumpers if setting this !)
// `define HOST_SET_OWN_TYPE 1

// Define this to always delay return to HS clock by the selected number of SYNC (fetches) and not
// just after accessing specific IO areas - causes slight performance loss of ~ 0.3% in CLOCKSP CA,
// but small reduction in overall CPLD resources (including decoding currently in cpld_jnr)
//`define ALWAYS_DELAY_SWITCH_TO_HS 1

// Define this to bring decoding back into the main CPLD (mainly for capacity evaluation). Note
// that the address lsb latches are still assumed external to keep the same pin out.
//`define LOCAL_DECODING 1
`ifdef LOCAL_DECODING
  `define ELK_PAGED_ROM_SEL 16'hFE05
  `define PAGED_ROM_SEL 16'hFE30
  `define BPLUS_SHADOW_RAM_SEL 16'hFE34
  `define DECODED_SHADOW_REG  ((`L1_BPLUS_MODE) ? (cpu_adr==`BPLUS_SHADOW_RAM_SEL) : 1'b0 )
  `define DECODED_ROM_REG     ((`L1_ELK_MODE)? (cpu_adr==`ELK_PAGED_ROM_SEL) : (cpu_adr==`PAGED_ROM_SEL))
  // Flag FE4x (VIA) accesses and also all &FC, &FD expansion pages
  `define DECODED_FE4X        ((cpu_adr[15:4]==12'hFE4) || (cpu_adr[15:9]==7'b1111_110))
`else
  `define DECODED_SHADOW_REG dec_shadow_reg
  `define DECODED_ROM_REG    dec_rom_reg
  `define DECODED_FE4X       dec_fe4x
`endif // !`ifdef LOCAL_DECODING

// Decode jumpers on J[1:0] or register bits
`ifdef HOST_SET_OWN_TYPE
  `define L1_BEEB_MODE   (map_data_q[`JUMPER_1_IDX:`JUMPER_0_IDX]==2'b00)
  `define L1_BPLUS_MODE  (map_data_q[`JUMPER_1_IDX:`JUMPER_0_IDX]==2'b01)
  `define L1_ELK_MODE    (map_data_q[`JUMPER_1_IDX:`JUMPER_0_IDX]==2'b10)
  `define L1_MASTER_MODE (map_data_q[`JUMPER_1_IDX:`JUMPER_0_IDX]==2'b11)
`else
  `define L1_BEEB_MODE   (j[1:0]==2'b00)
  `define L1_BPLUS_MODE  (j[1:0]==2'b01)
  `define L1_ELK_MODE    (j[1:0]==2'b10)
  `define L1_MASTER_MODE (j[1:0]==2'b11)
`endif

`define MAP_CC_DATA_SZ         8
`define SHADOW_MEM_IDX         7
`define JUMPER_1_IDX           6
`define JUMPER_0_IDX           5
`define MAP_ROM_IDX            4
`define MAP_MOS_IDX          `MAP_ROM_IDX
`define MAP_HSCLK_EN_IDX       2
`define CLK_CPUCLK_DIV_IDX_HI  1
`define CLK_CPUCLK_DIV_IDX_LO  0
`define BBC_PAGEREG_SZ         4    // only the bottom four ROM selection bits

`define CPLD_REG_SEL_SZ        3
`define CPLD_REG_SEL_BBC_SHADOW_IDX 2
`define CPLD_REG_SEL_MAP_CC_IDX 1
`define CPLD_REG_SEL_BBC_PAGEREG_IDX 0

module level1b_mk2_m (
                      input [15:0]   cpu_adr,
                      input          resetb,
                      input          cpu_vpb,
                      input          cpu_e,
                      input          cpu_vda,
                      input          cpu_vpa,
                      input          bbc_phi0,
                      input          hsclk,
                      input          cpu_rnw,
                      inout  [1:0]   j,
                      output [1:0]   tp,
                      input          dec_shadow_reg,
                      input          dec_rom_reg,
                      input          dec_fe4x,
                      inout [7:0]    cpu_data,
                      inout [7:0]    bbc_data,
                      inout          rdy,
                      inout          nmib,
                      inout          irqb,
                      output         lat_en,
                      output         ram_web,
                      output         ram_ceb,
                      output         ram_oeb,
                      output [18:14] ram_adr,
                      output         bbc_sync,
                      output [15:12] bbc_adr,
                      output         bbc_rnw,
                      output         bbc_phi1,
                      output         bbc_phi2,
                      output         cpu_phi2
		  );

  reg [7:0]                            cpu_hiaddr_lat_q;
  reg [7:0]                            cpu_data_r;
  reg                                  mos_vdu_sync_q;
  reg                                  himem_vram_wr_lat_q;
  reg                                  rom_wr_protect_lat_q;
  reg [7:0]                            bbc_data_lat_q;
  // This is the internal register controlling which features like high speed clocks etc are enabled
  reg [ `CPLD_REG_SEL_SZ-1:0]           cpld_reg_sel_q;
  wire [ `CPLD_REG_SEL_SZ-1:0]          cpld_reg_sel_d;
  // This will be a copy of the BBC ROM page register so we know which ROM is selected
  reg [`BBC_PAGEREG_SZ-1:0]            bbc_pagereg_q;
  reg [`MAP_CC_DATA_SZ-1:0]            map_data_q;
  reg                                  remapped_rom47_access_r ;
  reg                                  remapped_romCF_access_r ;
  reg                                  remapped_mos_access_r ;
  reg                                  remapped_ram_access_r ;
  reg                                  cpu_a15_lat_d;
  reg                                  cpu_a14_lat_d;
  reg                                  cpu_a15_lat_q;
  reg                                  cpu_a14_lat_q;
  reg [7:0]                            cpu_hiaddr_lat_d;
  reg [ `IO_ACCESS_DELAY_SZ-1:0]       io_access_pipe_q;
`ifdef PIPELINE_ROM_CTRL
  reg                                  map_rom_cf_q;
  reg                                  map_rom_47_q;
`endif
  wire                                 io_access_pipe_d;
  wire                                 himem_vram_wr_d;

`ifdef FORCE_KEEP_CLOCK
  (* KEEP="TRUE" *) wire               cpu_phi1_w;
  (* KEEP="TRUE" *) wire               cpu_phi2_w;
`else
  wire                                 cpu_phi1_w;
  wire                                 cpu_phi2_w;
`endif
  wire                                 hs_selected_w;
  wire                                 ls_selected_w;
  wire                                 dummy_access_w;
  wire                                 sel_hs_w;
  wire                                 native_mode_int_w;
  wire                                 himem_w;
  wire                                 hisync_w;
  wire                                 sw_rdy_w;
  wire [ `CPLD_REG_SEL_SZ-1:0]         cpld_reg_sel_w;
  wire                                 ckdel_w;

`ifdef HOST_SET_OWN_TYPE
  assign j = map_data_q[`JUMPER_1_IDX:`JUMPER_0_IDX];
`endif

  // Fast RAM mode set by jumper on tp[0] unless being use as a test point
`ifdef OBSERVE_CLOCKS
  assign tp = { sw_rdy_w, cpu_phi2 };
`endif

  
`ifdef DEGLITCH_CLOCK_IN
  // Deglitch PHI0 input for feeding to clock switch only
  (* KEEP="TRUE" *) wire ckdel_1_b;  
  (* KEEP="TRUE" *) wire ckdel_2;
  (* KEEP="TRUE" *) wire ckdel_3;
  (* KEEP="TRUE" *) wire ckdel_4;
  INV    ckdel0   ( .I(bbc_phi0), .O(ckdel_1_b));  
  INV    ckdel2   ( .I(ckdel_1_b), .O(ckdel_2));
  BUF    ckdel3   ( .I(ckdel_2), .O(ckdel_3));
  BUF    ckdel4   ( .I(ckdel_3), .O(ckdel_4));
  assign ckdel_w = !(ckdel_2 & ckdel_4);
`else
  // Force keep intermediate nets to preserve strict delay chain for clocks
  (* KEEP="TRUE" *) wire ckdel_1_b;
  (* KEEP="TRUE" *) wire ckdel_2;
  (* KEEP="TRUE" *) wire ckdel_3_b;
  INV    ckdel1   ( .I(bbc_phi0), .O(ckdel_1_b));
  INV    ckdel2   ( .I(ckdel_1_b), .O(ckdel_2));
  INV    ckdel3   ( .I(ckdel_2), .O(ckdel_3_b));
  assign ckdel_w = ckdel_3_b;
`endif

  clkctrl_phi2 U_0 (
                    .hsclk_in(hsclk),
                    .lsclk_in(ckdel_w),
                    .rst_b(resetb),
                    .hsclk_sel(sel_hs_w),
                    .cpuclk_div_sel(map_data_q[`CLK_CPUCLK_DIV_IDX_HI:`CLK_CPUCLK_DIV_IDX_LO]),
                    .hsclk_selected(hs_selected_w),
                    .lsclk_selected(ls_selected_w),
                    .rdy(sw_rdy_w),
                    .clkout(cpu_phi1_w)
                    );

  assign bbc_phi1 = ckdel_1_b;
  assign bbc_phi2 = !ckdel_1_b;

  assign cpu_phi2_w = !cpu_phi1_w ;
  assign cpu_phi2 =  cpu_phi2_w ;

  assign bbc_sync = cpu_vpa & cpu_vda;
  assign irqb = 1'bz;
  assign nmib = 1'bz;
  assign rdy = (sw_rdy_w) ? 1'bz : 1'b0;

  // Native mode interrupts will be redirected to himem
  assign native_mode_int_w = !cpu_vpb & !cpu_e ;
  // Drive the all RAM address pins, allowing for 512K RAM connection
  assign ram_adr = { cpu_hiaddr_lat_q[2:0], cpu_a15_lat_q, cpu_a14_lat_q } ;
  assign lat_en = !dummy_access_w;

`ifdef DELAY_RAMOEB_BY_1
  (* KEEP="TRUE" *) wire ramoeb_del_1;
  BUF    ramoedel1   ( .I(!cpu_rnw | cpu_phi1_w), .O(ramoeb_del_1));
  `define DELAYOEB ramoeb_del_1
`elsif DELAY_RAMOEB_BY_2
  (* KEEP="TRUE" *) wire ramoeb_del_1, ramoeb_del_2;
  BUF    ramoedel1   ( .I(!cpu_rnw | cpu_phi1_w), .O(ramoeb_del_1));
  BUF    ramoedel2   ( .I(ramoeb_del_1), .O(ramoeb_del_2));
  `define DELAYOEB ramoeb_del_2
`elsif DELAY_RAMOEB_BY_3
  (* KEEP="TRUE" *) wire ramoeb_del_1, ramoeb_del_2, ramoeb_del_3;
  BUF    ramoedel1   ( .I(!cpu_rnw | cpu_phi1_w), .O(ramoeb_del_1));
  BUF    ramoedel2   ( .I(ramoeb_del_1), .O(ramoeb_del_2));
  BUF    ramoedel3   ( .I(ramoeb_del_2), .O(ramoeb_del_3));
  `define DELAYOEB ramoeb_del_3
`else
  `define DELAYOEB 1'b0
`endif

  // All addresses starting 0b11 go to the on-board RAM and 0b10 to IO space, so check just bit 6
  // SRAM is enabled only in PHI2 for best operation with faster SRAM parts
  assign ram_ceb = cpu_phi1_w | !(cpu_hiaddr_lat_q[6] & (cpu_vda|cpu_vpa)) ;
  assign ram_web = cpu_rnw | cpu_phi1_w | rom_wr_protect_lat_q ;
  assign ram_oeb = !cpu_rnw | cpu_phi1_w | `DELAYOEB ;

  // All addresses starting with 0b10 go to internal IO registers which update on the
  // rising edge of cpu_phi1 - use the cpu_data bus directly for the high address
  // bits since it's stable by the end of phi1
  assign cpld_reg_sel_w = cpld_reg_sel_q;
  assign cpld_reg_sel_d[`CPLD_REG_SEL_MAP_CC_IDX] =  ( cpu_data[7:6]== 2'b10);
  assign cpld_reg_sel_d[`CPLD_REG_SEL_BBC_PAGEREG_IDX] = (cpu_data[7]== 1'b0) && `DECODED_ROM_REG ;
  assign cpld_reg_sel_d[`CPLD_REG_SEL_BBC_SHADOW_IDX] = (cpu_data[7]== 1'b0) && `DECODED_SHADOW_REG ;

  // Force dummy read access when accessing himem explicitly but not for remapped RAM accesses which can still complete
  assign bbc_adr = { (dummy_access_w) ? 4'b1100 : cpu_adr[15:12] };

  // Build delay chain for use with Electron to improve xtalk (will be bypassed for other machines)

  (* KEEP="TRUE" *) wire bbc_rnw_pre, bbc_rnw_del, bbc_rnw_del2;
  assign bbc_rnw_pre = cpu_rnw | dummy_access_w ;
  BUF    bbc_rnw_0( .I(bbc_rnw_pre), .O(bbc_rnw_del) );
  BUF    bbc_rnw_1( .I(bbc_rnw_del), .O(bbc_rnw_del2) );
  // Electron needs delay on RNW to reduce xtalk (ok for Beeb too)
  assign bbc_rnw = (`L1_ELK_MODE) ? (bbc_rnw_del2 | bbc_rnw_pre) : bbc_rnw_pre ;
  assign bbc_data = ( !bbc_rnw & bbc_phi2) ? cpu_data : { 8{1'bz}};
  assign cpu_data = cpu_data_r;

  // Identify Video RAM so that in non shadow mode VRAM writes can be slowed down
  assign himem_vram_wr_d = `VRAM_AREA ;

  // Check for write accesses to some of IO space (FE4x) in case we need to delay switching back to HS clock
  // so that min pulse widths to sound chip/reading IO are respected
  assign io_access_pipe_d = !cpu_hiaddr_lat_q[7] & `DECODED_FE4X & cpu_vda ;

  // Sel the high speed clock only
  // * on valid instruction fetches from himem, or
  // * on valid imm/data fetches from himem _if_ hs clock is already selected, or
  // * on invalid bus cycles if hs clock is already selected
  //
  // Option cached_shadow_ram can simplify the logic at the cost of making shadow and VRAM accesses both fast read/slow write
`ifdef CACHED_SHADOW_RAM
  assign himem_w =  cpu_hiaddr_lat_q[7] & (!himem_vram_wr_lat_q | cpu_rnw );
`else
  assign himem_w =  cpu_hiaddr_lat_q[7] & (!himem_vram_wr_lat_q | cpu_rnw | map_data_q[`SHADOW_MEM_IDX]);
`endif
  assign hisync_w = (cpu_vpa&cpu_vda) & cpu_hiaddr_lat_q[7];
  assign sel_hs_w = (( hisync_w & !io_access_pipe_q[0] ) |
                     ( himem_w & hs_selected_w) |
                     (!cpu_vpa & !cpu_vda & hs_selected_w)
                     ) ;

  assign dummy_access_w =  himem_w | !ls_selected_w ;

  // ROM remapping
  always @ ( * ) begin
    // Split ROM and MOS identification to allow them to go to different banks later
    remapped_mos_access_r = 0;
    remapped_rom47_access_r = 0;
    remapped_romCF_access_r = 0;
`ifdef PIPELINE_ROM_CTRL
    if (!cpu_data[7] & cpu_adr[15] & (cpu_vpa|cpu_vda) ) begin
      if (!cpu_adr[14]) begin
        remapped_romCF_access_r = map_rom_cf_q;
        remapped_rom47_access_r = map_rom_47_q;
      end
      // Remap MOS from C000-FBFF only (exclude IO space and vectors)
      else
        remapped_mos_access_r = !(&(cpu_adr[13:10])) & map_data_q[`MAP_ROM_IDX];
    end
`else
    if (!cpu_data[7] & cpu_adr[15] & (cpu_vpa|cpu_vda) & map_data_q[`MAP_ROM_IDX]) begin
       if (!cpu_adr[14]) begin
         remapped_romCF_access_r = (bbc_pagereg_q[3:2] == 2'b11) ;
         remapped_rom47_access_r = (bbc_pagereg_q[3:2] == 2'b01) ;
       end
       // Remap MOS from C000-FBFF only (exclude IO space and vectors)
       else
         remapped_mos_access_r = !(&(cpu_adr[13:10]));
     end
`endif
  end

  always @ ( * ) begin
      // Remap all of memory except VRAM area when in shadow mode and when a VDU access is in progress
      remapped_ram_access_r = !cpu_data[7] & !cpu_adr[15] & !(`VRAM_AREA  & mos_vdu_sync_q) ;
  end

  always @ ( * ) begin
    // Default assignments
    cpu_a15_lat_d = cpu_adr[15];
    cpu_a14_lat_d = cpu_adr[14];
    cpu_hiaddr_lat_d = cpu_data;

    // Native mode interrupts go to bank 0xFF (with other native 816 code)
    if ( native_mode_int_w )
      cpu_hiaddr_lat_d = 8'hFF;
    else begin
      // All remapped RAM/Mos accesses to 8'b1110x110
      if ( remapped_ram_access_r | remapped_mos_access_r) begin
        cpu_hiaddr_lat_d = 8'hFF;
        if ( remapped_mos_access_r)
          cpu_a14_lat_d = 1'b0;
      end
      // All remapped ROM slots 4-7 accesses to 8'b1110x100
      // All remapped ROM slots C-F accesses to 8'b1110x101
      if (remapped_rom47_access_r | remapped_romCF_access_r) begin
`ifdef PIPELINE_ROM_CTRL
        cpu_hiaddr_lat_d = { 6'b1111_11, map_rom_cf_q, map_rom_47_q};
`else
        cpu_hiaddr_lat_d = (remapped_rom47_access_r) ? 8'hFD: 8'hFE;
`endif
        cpu_a15_lat_d = bbc_pagereg_q[1];
        cpu_a14_lat_d = bbc_pagereg_q[0];
      end
    end
  end

  // drive cpu data if we're reading internal register or making a non dummy read from lomem
  always @ ( * )
    if ( cpu_phi2_w & cpu_rnw )
      begin
	if (cpu_hiaddr_lat_q[7]) begin
	  if (cpld_reg_sel_w[`CPLD_REG_SEL_MAP_CC_IDX] ) begin
            // Not all bits are used so assign default first, then individual bits
	    cpu_data_r = 8'b0  ;
	    cpu_data_r[`MAP_HSCLK_EN_IDX]      = map_data_q[`MAP_HSCLK_EN_IDX] ;
	    cpu_data_r[`SHADOW_MEM_IDX]        = map_data_q[`SHADOW_MEM_IDX];
`ifdef  HOST_SET_OWN_TYPE
            cpu_data_r[`JUMPER_1_IDX]          = map_data_q[`JUMPER_1_IDX];
            cpu_data_r[`JUMPER_0_IDX]          = map_data_q[`JUMPER_0_IDX];
`else
            cpu_data_r[`JUMPER_1_IDX]          = j[1];
            cpu_data_r[`JUMPER_0_IDX]          = j[0];
`endif
	    cpu_data_r[`MAP_ROM_IDX]           = map_data_q[`MAP_ROM_IDX];
	    cpu_data_r[`CLK_CPUCLK_DIV_IDX_HI] = map_data_q[`CLK_CPUCLK_DIV_IDX_HI];
	    cpu_data_r[`CLK_CPUCLK_DIV_IDX_LO] = map_data_q[`CLK_CPUCLK_DIV_IDX_LO];
          end
          else //must be RAM access
            cpu_data_r = {8{1'bz}};
        end
        else
          cpu_data_r = bbc_data_lat_q;
      end
    else
      cpu_data_r = {8{1'bz}};

  // -------------------------------------------------------------
  // All inferred flops and latches below this point
  // -------------------------------------------------------------
  // Internal registers update on the rising edge of cpu_phi1
  always @ ( negedge cpu_phi2_w or negedge resetb )
    if ( !resetb )
      begin
        map_data_q <= {`MAP_CC_DATA_SZ{1'b0}};
        bbc_pagereg_q <= {`BBC_PAGEREG_SZ{1'b0}};
      end
    else
      begin
        if (cpld_reg_sel_w[`CPLD_REG_SEL_MAP_CC_IDX] & !cpu_rnw) begin
          // Not all bits are used so assign explicitly
	  map_data_q[`MAP_HSCLK_EN_IDX]       <= cpu_data[`MAP_HSCLK_EN_IDX] ;
	  map_data_q[`SHADOW_MEM_IDX]         <= cpu_data[`SHADOW_MEM_IDX];
	  map_data_q[`MAP_ROM_IDX]            <= cpu_data[`MAP_ROM_IDX];
`ifdef HOST_SET_OWN_TYPE
	  map_data_q[`JUMPER_1_IDX]           <= cpu_data[`JUMPER_1_IDX];
	  map_data_q[`JUMPER_0_IDX]           <= cpu_data[`JUMPER_0_IDX];
`endif
	  map_data_q[`CLK_CPUCLK_DIV_IDX_HI]  <= cpu_data[`CLK_CPUCLK_DIV_IDX_HI];
	  map_data_q[`CLK_CPUCLK_DIV_IDX_LO]  <= cpu_data[`CLK_CPUCLK_DIV_IDX_LO];
        end
        else if (cpld_reg_sel_w[`CPLD_REG_SEL_BBC_PAGEREG_IDX] & !cpu_rnw )
          bbc_pagereg_q <= cpu_data;
        else if (cpld_reg_sel_w[`CPLD_REG_SEL_BBC_SHADOW_IDX] & !cpu_rnw )
          map_data_q[`SHADOW_MEM_IDX] <= cpu_data[`SHADOW_MEM_IDX];
      end // else: !if( !resetb )

  // Flop all the internal register sel bits on falling edge of phi1
  always @ ( posedge cpu_phi2_w or negedge resetb )
    if ( !resetb )
        cpld_reg_sel_q <= {`CPLD_REG_SEL_SZ{1'b0}};
    else
        cpld_reg_sel_q <= (rdy & cpu_vda) ? cpld_reg_sel_d : {`CPLD_REG_SEL_SZ{1'b0}};

`ifdef PIPELINE_ROM_CTRL
    always @ ( negedge cpu_phi2_w or negedge resetb )
      if ( !resetb )
        {map_rom_cf_q, map_rom_47_q}  <= 2'b00;
      else begin
        map_rom_cf_q <= map_data_q[`MAP_ROM_IDX] & (bbc_pagereg_q[3:2]==2'b11);
        map_rom_47_q <= map_data_q[`MAP_ROM_IDX] & (bbc_pagereg_q[3:2]==2'b01);
      end
`endif

  // Short pipeline to delay switching back to hs clock after an IO access to ensure any instruction
  // timed delays are respected. This pipeline is initialised to all 1's for force slow clock on startup
  // and will fill with the value of the HS clock enable register as instructions are executed.
  always @ ( negedge cpu_phi2_w or negedge resetb) begin
    if ( !resetb )
      io_access_pipe_q <= {`IO_ACCESS_DELAY_SZ{1'b1}};
    else begin
`ifdef ALWAYS_DELAY_SWITCH_TO_HS
      if (!cpu_hiaddr_lat_q[7] & (cpu_vda|cpu_vpa) & rdy)
        io_access_pipe_q <= {`IO_ACCESS_DELAY_SZ{1'b1}};
`else
      if (io_access_pipe_d )
        io_access_pipe_q <= {`IO_ACCESS_DELAY_SZ{1'b1}};
`endif
      else if ( cpu_vpa & cpu_vda & rdy )
        io_access_pipe_q <= { !map_data_q[`MAP_HSCLK_EN_IDX], io_access_pipe_q[`IO_ACCESS_DELAY_SZ-2:1] } ;
    end
  end

  // Instruction was fetched from VDU routines in MOS if
  // - in the range FFC000 - FFDFFF (if remapped to himem )
  // - OR in range 00C000 - 00DFFF if ROM remapping disabled.
  //
  // ie 11111111_110xxxxx  (decoded as 1xxx1111_110xxxx)
  //    00000000_110xxxxx  (decoded as 0xxxxxxx_110xxxx)
  //
  always @ ( negedge cpu_phi2_w )
    if ( cpu_vpa & cpu_vda ) begin
      if ( map_data_q[`SHADOW_MEM_IDX]) begin
        if ( map_data_q[`MAP_MOS_IDX])
          mos_vdu_sync_q <= ({cpu_hiaddr_lat_q[7],cpu_hiaddr_lat_q[3:0], cpu_adr[15:13]}==8'b1_1111_110);
        else
          mos_vdu_sync_q <= ({cpu_hiaddr_lat_q[7],cpu_adr[15:13]}==4'b0_110);
      end
      else
        // mos_vdu_sync_q always zerod in non-shadow mode
        mos_vdu_sync_q <= 1'b0;
    end

  // Latches for the high address bits open during PHI1
  always @ ( * )
    if ( rdy & !cpu_phi2_w )
      begin
        cpu_hiaddr_lat_q <= cpu_hiaddr_lat_d ;
        cpu_a15_lat_q <= cpu_a15_lat_d;
        cpu_a14_lat_q <= cpu_a14_lat_d;
        himem_vram_wr_lat_q <= himem_vram_wr_d;
        rom_wr_protect_lat_q <= remapped_mos_access_r|remapped_romCF_access_r ;
      end

  // Latches for the BBC data open during PHI2 to be stable beyond cycle end
  always @ ( * )
    if ( !bbc_phi1 )
      bbc_data_lat_q <= bbc_data;

endmodule // level1b_m
