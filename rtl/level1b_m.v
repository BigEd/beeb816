`timescale 1ns / 1ns

// Set next define to use latch on clock enable and allow more cycle time for
// the enable to be computed (usually choose this option unless you really
// need to be able to make sense of the timing reports...)
// `define CLOCK_SWITCH_USE_LATCH_D 1

// Set next define to latch only the incoming data from the BBC data bus - this
// should compensate for clock skew where the CPU clock is delayed compared with
// the motherboard
//`define LATCH_HOST_DATA_D 1

// This retargets any interrups in native mode to high address area 0xFFxxxx
  `define REMAP_NATIVE_INTERRUPTS_D 1

// PIPELINE_HS_SWITCH_D delays switching from low to high speed until at least two
// HIMEM instruction fetches are performed - ie never follow a lowmem access with a switch
// to high speed.
//  `define PIPELINE_HS_SWITCH_D 1

// SPLIT_MAP_D allows the top half and bottom half of the HOST address space to
// be mapped to HIMEM separately. Specifically for the BBC the top half is covered
// with ROM and the bottom half is RAM
//  `define SPLIT_MAP_D 1

// RAM_MAPPED_ON_BOOT_D needs SPLIT_MAP_D to be selected too and allows the CPLD
// to boot with the RAM mapping already enabled. This won't work with systems
// like the Oric which have IO space at the bottom of the address map, but
// is generally ok for the BBC and may fix Ed's flakey BBC.
//  `define RAM_MAPPED_ON_BOOT_D 1


// SLOW_VIDEO_RAM_D ensures that the lomem address range 00_4000 - 00_7FFF is written
// at low speed to be compatible with the BBC's video area (reads are at full speed)
`define SLOW_VIDEO_RAM_D 1

// ALLOW_512K_RAM_D is set by default to drive enough address bits. Omitting this saves 2 pins
// and associated logic resource if space is really tight
`define ALLOW_512K_RAM_D 1

`ifdef TARGET_9572_D
// Reduced spec so that we can fit the 9572 and still optimize for speed
`else
 `define ALLOW_GPIOS_D    1
 `define GPIO_DIR_SZ      2
 `define GPIO_DAT_SZ      2
 `define I2C_SZ           3
 `define I2C_SDA_IN_IDX   2   
 `define I2C_SDA_OUT_IDX  1
 `define I2C_SCL_IDX      0
`endif

// If we don't split the memory map then the enable for ROM and RAM is the same bit
`ifdef SPLIT_MAP_D
 `define MAP_CC_DATA_SZ     6
 `define MAP_ROM_IDX        5
 `define MAP_RAM_IDX        4
`else
  `define MAP_CC_DATA_SZ     5
  `define MAP_ROM_IDX        4
  `define MAP_RAM_IDX        4
 `endif
`define CLK_HSCLK_EN_IDX   3
`define CLK_HSCLK_INV_IDX  2
`define CLK_DIV_EN_IDX     1
`define CLK_DIV4NOT2_IDX   0

`define BBC_PAGEREG_SZ     2    // only use the bottom two ROM selection bits 

// Define a one-hot select register for the internal registers
`ifdef ALLOW_GPIOS_D
  `define CPLD_REG_SEL_SZ 5
  `define CPLD_REG_SEL_GPIO_DIR_IDX 4
  `define CPLD_REG_SEL_GPIO_DAT_IDX 3
  `define CPLD_REG_SEL_I2C_IDX 2
 `else
  `define CPLD_REG_SEL_SZ 2
 `endif

`define CPLD_REG_SEL_MAP_CC_IDX 1
`define CPLD_REG_SEL_BBC_PAGEREG_IDX 0

// Address of ROM selection reg in BBC memory map
`define BBC_PAGED_ROM_SEL 16'hFE30
// Assume that BBC ROM is at slot FF ( or at least ends with LSBs set...)
`define BASICROM_NUMBER 2'b11

module level1b_m (
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
    inout [6:0]  gpio,
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

   reg [7:0] 	 cpu_hiaddr_lat_q;
   reg [7:0]     cpu_data_r;
   reg [ `CPLD_REG_SEL_SZ-1:0] cpld_reg_select_q;


   reg [`BBC_PAGEREG_SZ-1:0] bbc_pagereg_q;
`ifdef ALLOW_GPIOS_D   
   reg [`GPIO_DIR_SZ-1:0]    gpio_dir_q;
   reg [`GPIO_DAT_SZ-1:0]    gpio_data_q;
   reg [`GPIO_DAT_SZ-1:0]    gpio_r;  
   reg [`GPIO_DAT_SZ-1:0]    gpio_data_d;
`endif
   
`ifdef LATCH_HOST_DATA_D
   reg [7:0]                 bbc_data_q;   
`endif
`ifdef PIPELINE_HS_SWITCH_D
   reg                       hisync_q;
`endif                      
   
   
   reg [`MAP_CC_DATA_SZ-1:0] map_data_q;  
   reg                       himem_bank01_write_q;
   
   wire [ `CPLD_REG_SEL_SZ-1:0] cpld_reg_select_d;   
   wire [`BBC_PAGEREG_SZ-1:0] 	bbc_pagereg_d;

`ifdef ALLOW_GPIOS_D      
   reg [`I2C_SZ-1:0]            i2c_q;
   reg [`I2C_SZ-1:0]            i2c_d;         
   wire [`GPIO_DIR_SZ-1:0]      gpio_dir_w;
`endif   
   wire [`MAP_CC_DATA_SZ-1:0]   map_data_w;
   wire [7:0]                   cpu_hiaddr_lat_d;         
   wire 			rdy_w;   
   wire 			cpu_ck_phi1_w;
   wire 			cpu_ck_phi2_w;      
   wire 			hs_selected_w;
   wire 			ls_selected_w;      
   wire                         himem_bank01_write_d;   
   wire 			dummy_access_w;
   wire 			select_hs_w;
   wire 			hs_clk_w;
   wire 			native_mode_int_w;
   wire                         hisync_w;   

`ifdef REMAP_NATIVE_INTERRUPTS_D   
   // Native mode interrupts will be redirected to himem
   assign native_mode_int_w = !vpb & !cpu_e ;   
`else
   assign native_mode_int_w = 1'b0;   
`endif

   
`ifdef ALLOW_GPIOS_D         
   // Only allocate the GPIO pins if we need them, otherwise pins go to a
   // default state and free up associated resource   
   
   // SDA and SCL are both open collector   
   assign sda = ( i2c_q[`I2C_SDA_OUT_IDX] ) ? 1'bz : 1'b0 ;
   assign scl = ( i2c_q[`I2C_SCL_IDX] ) ? 1'bz : 1'b0 ;
   assign gpio = gpio_r ;
`endif
   
   assign cpu_ck_phi2_w = ! cpu_ck_phi1_w;
   assign cpu_ck_phi2 =  cpu_ck_phi2_w ;   
   assign bbc_ck2_phi1 = ! bbc_ck2_phi0;
   // Tip from a thread in 6502.org to make an almost non-overlapping phi2 (not strictly req for Beeb)
   assign bbc_ck2_phi2 = ( !bbc_ck2_phi1 ) & bbc_ck2_phi0;
   // rdy has a pull-up resistor in the CPU
   assign rdy = 1'bz;   
   assign bbc_sync = vpa & vda;
   assign irqb = 1'bz;
   assign nmib = 1'bz;

// Only drive the all RAM address pins if we're allowing for 512K operation otherwise pins go to a
// default state and free up associated resource
   assign ram_addr16 = cpu_hiaddr_lat_q[0] ;

`ifdef ALLOW_512K_RAM_D   
   assign ram_addr17 = cpu_hiaddr_lat_q[1] ;
   assign ram_addr18 = cpu_hiaddr_lat_q[2];   
`endif
   
   // All addresses starting 0b11 go to the on-board RAM
   assign ram_ceb = !( cpu_ck_phi2_w && (vda | vpa ) && (cpu_hiaddr_lat_q[7:6] == 2'b11) );   
   // All addresses starting with 0b10 go to internal IO registers which update on the 
   // rising edge of cpu_ck_phi1 - use the cpu_data bus directly for the high address 
   // bits since it's stable by the end of phi1
`ifdef ALLOW_GPIOS_D         
   assign cpld_reg_select_d[`CPLD_REG_SEL_GPIO_DIR_IDX] = vda && ( cpu_data[7:6]== 2'b10) && ( addr[1:0] == 2'b00);
   assign cpld_reg_select_d[`CPLD_REG_SEL_GPIO_DAT_IDX] = vda && ( cpu_data[7:6]== 2'b10) && ( addr[1:0] == 2'b01);
   assign cpld_reg_select_d[`CPLD_REG_SEL_I2C_IDX] = vda && ( cpu_data[7:6]== 2'b10) && ( addr[1:0] == 2'b10);
`endif   
   assign cpld_reg_select_d[`CPLD_REG_SEL_MAP_CC_IDX] = vda && ( cpu_data[7:6]== 2'b10) && ( addr[1:0] == 2'b11);
   assign cpld_reg_select_d[`CPLD_REG_SEL_BBC_PAGEREG_IDX] = vda && (cpu_data[7]== 1'b0) && ( addr == `BBC_PAGED_ROM_SEL );      

   // Compute d inputs for the hiaddress latch assuming that the high address is always driven onto the databus
   // during PHI1. For reads we can assume that 'himem' is an alias of the highest address bit since all addresses
   // can be read at high speed. For writes though, the upper 16K of the overlaid 32K is _not_ writable at full speed
   // so we need the himem_bank01_write_d signal to detect that.
   assign himem_bank01_write_d = !cpu_data[7] & (map_data_q[`MAP_RAM_IDX] & !addr[15] & addr[14] & !rnw) ;

`ifdef SPLIT_MAP_D
   wire                         remapped_rom_access_w ;   
   wire                         remapped_ram_access_w ;
   assign remapped_rom_access_w =  !cpu_data[7] & map_data_q[`MAP_ROM_IDX] & addr[15] & ((!addr[14] & (bbc_pagereg_q[`BBC_PAGEREG_SZ-1:0] == `BASICROM_NUMBER)) |
                                                                                         ( addr[14] & (!addr[13] | !addr[12] | !addr[11] | !addr[10] | (addr[9] & addr[8]))));
   assign remapped_ram_access_w =  !cpu_data[7] & map_data_q[`MAP_RAM_IDX] & !addr[15] ;   
   assign cpu_hiaddr_lat_d[7:1] = cpu_data[7:1] | { 7{remapped_ram_access_w | remapped_rom_access_w | native_mode_int_w} };
`else
   // In the unified map we map
   // all RAM  - addr[15]==0
   // ROM FF   - addr[15:14] == 2'b10 AND paged ROM == FF
   // MOS except for top 1KB
   wire                         remapped_access_w ;
   assign remapped_access_w =  !cpu_data[7] &  map_data_q[`MAP_ROM_IDX] & 
                               ( !addr[15] | 
                                 (!addr[14] & (bbc_pagereg_q[`BBC_PAGEREG_SZ-1:0] == `BASICROM_NUMBER)) |
                                 ( addr[14] & ( !addr[13] | !addr[12] | !addr[11] | !addr[10] | (addr[9] & addr[8]))));
   assign cpu_hiaddr_lat_d[7:1] = cpu_data[7:1] | { 7{ remapped_access_w  | native_mode_int_w} };   
`endif
   
   // Remapped accesses all go too the range FE0000 - FEFFFF, so don't set the bottom bit for these
   assign cpu_hiaddr_lat_d[0] = cpu_data[0] | native_mode_int_w;


`ifdef ALLOW_GPIOS_D
   integer       idx;           
   
   // Compute GPIO output pin values bit by bit
   always @ ( gpio_data_q or gpio_dir_q or gpio )
     begin
        for (idx = 0 ; idx < `GPIO_DAT_SZ ; idx = idx + 1 ) 
          begin
             // DIR=1: input , DIR = 0: output
             if ( gpio_dir_q[idx] == 1'b0 )
               gpio_r[idx] <= gpio_data_q[idx ];
             else
               gpio_r[idx] <= 1'bz;
          end
     end // always @ ( gpio0_data_q or gpio_dir_q or gpio )
`endif
   
   // Need to force dummy accesses whenever Ls clock is not selected, but also when running off
   // ls clock and accessing himem (for data accesses for example)
`ifdef SLOW_VIDEO_RAM_D   
   assign dummy_access_w = (cpu_hiaddr_lat_q[7] & !himem_bank01_write_q) | !(ls_selected_w) ;
`else
   assign dummy_access_w = cpu_hiaddr_lat_q[7]  | !(ls_selected_w) ;   
`endif
   
   // Dummy access forces read from ROM
   assign { bbc_addr15, bbc_addr14 } = ( dummy_access_w ) ? { 2'b10 } : { addr[15], addr[14] } ;

   // only allow the BBC_RNW to go low when accessing host resource in BBC_CK2_PHI2 _AND_ when at least one of the clocks is enabled
   // but ensure that the data persists a little longer
   wire host_rnw_w;
   assign host_rnw_w = rnw | dummy_access_w ;
   assign bbc_rnw =  host_rnw_w | !(bbc_ck2_phi0 & bbc_ck2_phi2) | (!ls_selected_w & !hs_selected_w);   
   // Drive bbc_data only for write accesses to lomem
   assign bbc_data = ( !host_rnw_w & (bbc_ck2_phi0 | bbc_ck2_phi2)  ) ? cpu_data : { 8{1'bz}};
   assign cpu_data = cpu_data_r;   
   
   // drive cpu data if we're reading internal register or making a non dummy read from lomem
   always @ ( cpu_ck_phi2_w or rnw or
`ifdef ALLOW_GPIOS_D                    
              gpio_data_q or gpio_dir_q or
              i2c_q or
`endif              
              cpld_reg_select_q or map_data_q or 
              cpu_hiaddr_lat_q[7]
`ifdef LATCH_HOST_DATA_D
              or bbc_data_q
`else              
              or bbc_data
`endif              
              or bbc_pagereg_q)     
     if ( cpu_ck_phi2_w & rnw  )
       begin
	  if (cpu_hiaddr_lat_q[7])
	    if ( cpld_reg_select_q[`CPLD_REG_SEL_MAP_CC_IDX]  )
              cpu_data_r = { {(8-`MAP_CC_DATA_SZ){1'b0}}, map_data_q};	      
`ifdef ALLOW_GPIOS_D                  
            else if ( cpld_reg_select_q[`CPLD_REG_SEL_I2C_IDX] )
              cpu_data_r = { {(8-`I2C_SZ){1'b0}}, i2c_q};	 
            else if ( cpld_reg_select_q[`CPLD_REG_SEL_GPIO_DAT_IDX] )
              cpu_data_r = { {(8-`GPIO_DAT_SZ){1'b0}}, gpio_data_q};
            else if ( cpld_reg_select_q[`CPLD_REG_SEL_GPIO_DIR_IDX]  )
              cpu_data_r = { {(8-`GPIO_DIR_SZ){1'b0}}, gpio_dir_q};
`endif          
            else //must be RAM access
              cpu_data_r = {8{1'bz}};
          else
`ifdef LATCH_HOST_DATA_D
            cpu_data_r = bbc_data_q;            
`else            
            cpu_data_r = bbc_data;
`endif          
       end // if ( cpu_ck_phi1_w & rnw )   
     else 
       cpu_data_r = {8{1'bz}};
   

   clock_divider24_m clock_div0_u (
				   .divider_en( map_data_q[`CLK_DIV_EN_IDX]),
				   .div4not2( map_data_q[`CLK_DIV4NOT2_IDX]),
                                   .invert( map_data_q[`CLK_HSCLK_INV_IDX]),
				   .clkin(bbc_ck8),
				   .resetb(resetb),
				   .clkout(hs_clk_w)
				   );

   
   //
   // Select the high speed clock only 
   // * on valid instruction fetches from himem, or
   // * on valid imm/data fetches from himem _if_ hs clock is already selected, or
   // * on invalid bus cycles if hs clock is already selected
   //
   // when stopping in PHI2 we can take the high bit for the address and whether or not this is a write
   // to shadow RAM from the existing latches and cut out some decoding.

`ifdef SLOW_VIDEO_RAM_D
   wire himem_w =  (cpu_hiaddr_lat_q[7] & !himem_bank01_write_q);
`else
   wire himem_w =  cpu_hiaddr_lat_q[7] ;  
`endif
   
   assign hisync_w = vpa & vda & himem_w;
   
   
`ifdef PIPELINE_HS_SWITCH_D
   // When this define is set we only allow a switch to high speed on the second consecutive
   // HIMEM instruction fetch
   assign select_hs_w = map_data_q[`CLK_HSCLK_EN_IDX] & (( hisync_w & hisync_q) |
			 ((vpa | vda ) & himem_w & hs_selected_w) |
			 (!vpa & !vda & hs_selected_w)
			 ) ;
`else
   assign select_hs_w = map_data_q[`CLK_HSCLK_EN_IDX] & (( hisync_w) |
			 ((vpa | vda ) & himem_w & hs_selected_w) |
			 (!vpa & !vda & hs_selected_w)
			 ) ;
`endif
   
   clock_switch_p2_m clock_switch_0_u (
				       .hs_ck_ip( hs_clk_w),
				       .ls_ck_ip(!bbc_ck2_phi0),
				       .select_hs_ip(select_hs_w),
				       .resetb(resetb),
				       .selected_hs_op(hs_selected_w),
				       .selected_ls_op(ls_selected_w),
				       .ck_op(cpu_ck_phi1_w)
				       );


`ifdef ALLOW_GPIOS_D   
   // Calculate next state on bit-by-bit basis for the gpio_data register
   always @ ( gpio or gpio_data_q or gpio_dir_q or cpld_reg_select_q or rnw or cpu_data )
     begin
        for (idx = 0 ; idx < `GPIO_DAT_SZ ; idx = idx + 1 )
          begin
             // Input bits update every cycle from IOs
             if ( gpio_dir_q[idx] == 1'b1 )
               gpio_data_d[idx] <= gpio[idx];         
             // If we're writing to an output bit then data comes from CPU bus
             else if ( cpld_reg_select_q[`CPLD_REG_SEL_GPIO_DAT_IDX] & !rnw )
               gpio_data_d[idx] <= cpu_data[idx];
             // Otherwise bits retain state
             else                 
               gpio_data_d[idx] <= gpio_data_q[idx];             
          end
     end // always @ ( gpio or gpio_data_q or gpio_dir_q )

   // Calculate next state for I2C bits
   always @ ( i2c_q or cpld_reg_select_q or rnw or cpu_data or sda )
     begin
	// All bits are either written from CPU data or retain state
	i2c_d = ( cpld_reg_select_q[`CPLD_REG_SEL_I2C_IDX] && !rnw ) ? cpu_data[`I2C_SZ-1:0] : i2c_q;
	// except for the SDA IN bit which just copies the state on SDA pin
	i2c_d[`I2C_SDA_IN_IDX]   = sda;
     end
   
`endif //  `ifdef ALLOW_GPIOS_D
   


`ifdef ALLOW_GPIOS_D      
   // Calculate next state for the GPIO DIR reg
   assign gpio_dir_w = ( cpld_reg_select_q[`CPLD_REG_SEL_GPIO_DIR_IDX] & !rnw ) ? cpu_data[`GPIO_DIR_SZ-1:0] : gpio_dir_q;
`endif          
   assign map_data_w = ( cpld_reg_select_q[`CPLD_REG_SEL_MAP_CC_IDX] & !rnw ) ? cpu_data[`MAP_CC_DATA_SZ-1:0] : map_data_q;
   assign bbc_pagereg_d = ( cpld_reg_select_q[`CPLD_REG_SEL_BBC_PAGEREG_IDX] & !rnw ) ? cpu_data[`BBC_PAGEREG_SZ-1:0] : bbc_pagereg_q;
   

   // -------------------------------------------------------------
   // All inferred flops and latches below this point
   // -------------------------------------------------------------
        
   // Internal registers update on the rising edge of cpu_ck_phi1
   always @ ( posedge cpu_ck_phi1_w or negedge resetb )
     if ( !resetb )
       begin
`ifdef ALLOW_GPIOS_D             
          gpio_data_q<= {`GPIO_DAT_SZ{1'b0}};
          gpio_dir_q <= {`GPIO_DIR_SZ{1'b1}};
          i2c_q <= {`I2C_SZ{1'b0}};          
`endif
`ifdef PIPELINE_HS_SWITCH_D
          hisync_q <= 1'b0;
`endif
`ifdef SPLIT_MAP_D
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
`else
          map_data_q <= {`MAP_CC_DATA_SZ{1'b0}};          
`endif          
          bbc_pagereg_q <= {`BBC_PAGEREG_SZ{1'b0}};	  	  
       end
     else
       begin
`ifdef ALLOW_GPIOS_D                       
          gpio_data_q <= gpio_data_d;
   	  gpio_dir_q <= gpio_dir_w;
          i2c_q <= i2c_d;          
`endif
`ifdef PIPELINE_HS_SWITCH_D
          // Only change state on instruction fetches
          hisync_q <= (vpa & vda ) ? himem_w : hisync_q;          
`endif
   	  map_data_q <= map_data_w;
          bbc_pagereg_q <= bbc_pagereg_d;	  
       end // else: !if( !resetb )
   

   // Flop all the internal register select bits on falling edge of phi1
   // for use on rising edge of phi2
   always @ ( negedge cpu_ck_phi1_w or negedge resetb )
     if ( !resetb ) 
       cpld_reg_select_q = { `CPLD_REG_SEL_SZ{1'b0}};
     else
       cpld_reg_select_q = cpld_reg_select_d ;

   // Latches for the high address bits open during PHI1
   always @ ( cpu_ck_phi1_w or resetb or cpu_hiaddr_lat_d or himem_bank01_write_d )
     if ( ! resetb )
       begin
          cpu_hiaddr_lat_q <= 8'b0;          
          himem_bank01_write_q <= 1'b0;
       end   
     else if ( cpu_ck_phi1_w )
       begin
          cpu_hiaddr_lat_q <= cpu_hiaddr_lat_d;
          himem_bank01_write_q <= himem_bank01_write_d;
       end

// Optional code to always latch the incoming host computer data bus in case
// there is significant delay on the CPU clock compared with the motherboard
// clock. This will help on the MB->CPU transfers, but not much to be done
// going the other way.
`ifdef LATCH_HOST_DATA_D
   always @ ( bbc_ck2_phi0 or bbc_data)
     if ( bbc_ck2_phi0 )
       bbc_data_q <= bbc_data;     
`endif
   

endmodule // level1b_m
