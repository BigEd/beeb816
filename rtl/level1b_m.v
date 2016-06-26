`timescale 1ns / 1ns

// Set next define to use latch on clock enable and allow more cycle time for
// the enable to be computed (usually choose this option unless you really
// need to be able to make sense of the timing reports...)
// `define CLOCK_SWITCH_USE_LATCH_D 1

// This retargets any interrups in native mode to high address area 0xFFxxxx
  `define REMAP_NATIVE_INTERRUPTS_D 1

// RAM_MAPPED_ON_BOOT_D needs SPLIT_MAP_D to be selected too and allows the CPLD
// to boot with the RAM mapping already enabled. This won't work with systems
// like the Oric which have IO space at the bottom of the address map, but
// is generally ok for the BBC and may fix Ed's flakey BBC.
`define RAM_MAPPED_ON_BOOT_D 1

`define MAP_CC_DATA_SZ     6
`define MAP_ROM_IDX        5
`define MAP_RAM_IDX        4
`define CLK_HSCLK_EN_IDX   3
`define CLK_HSCLK_INV_IDX  2
`define CLK_DIV_EN_IDX     1
`define CLK_DIV4NOT2_IDX   0

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

   reg [7:0] 	 cpu_hiaddr_lat_q;
   reg [7:0]     cpu_data_r;
           
   // This is the internal register controlling which features like high speed clocks etc are enabled
   reg [ `CPLD_REG_SEL_SZ-1:0] cpld_reg_select_q;

   // This will be a copy of the BBC ROM page register so we know which ROM is selected
   reg [`BBC_PAGEREG_SZ-1:0] bbc_pagereg_q;
   reg [`MAP_CC_DATA_SZ-1:0] map_data_q;  
   reg                       himem_vidram_access_lat_q;
   
   wire [ `CPLD_REG_SEL_SZ-1:0] cpld_reg_select_d;   
   wire [`BBC_PAGEREG_SZ-1:0] 	bbc_pagereg_d;


   wire [`MAP_CC_DATA_SZ-1:0]   map_data_d;
   wire [7:0]                   cpu_hiaddr_lat_d;         
   wire 			rdy_w;   
   wire 			cpu_ck_phi1_w;   
   wire 			cpu_ck_phi2_w;      
   wire 			hs_selected_w;
   wire 			ls_selected_w;      
   wire                         himem_vidram_access_d;   
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

   
   // Debug - drive useful signals to places where we can probe
   assign sda = hs_selected_w;
   assign scl = cpu_ck_phi1_w;   
   assign gpio = `GPIO_SZ'bz;
   
   assign cpu_ck_phi2_w = !cpu_ck_phi1_w ;   
   assign cpu_ck_phi2 =  cpu_ck_phi2_w ;   
   assign bbc_ck2_phi1 = ! bbc_ck2_phi0;
   assign bbc_ck2_phi2 = ( !bbc_ck2_phi1 ) & bbc_ck2_phi0;
   // rdy has a pull-up resistor in the CPU
   assign rdy = 1'bz;
   
   assign bbc_sync = vpa & vda;
   assign irqb = 1'bz;
   assign nmib = 1'bz;

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

   // Compute d inputs for the hiaddress latch assuming that the high address is always driven onto the databus
   // during PHI1. For reads we can assume that 'himem' is an alias of the highest address bit since all addresses
   // can be read at high speed. For writes though, the upper 16K of the overlaid 32K is _not_ writable at full speed
   // so we need the himem_vidram_access_d signal to detect that.
   assign himem_vidram_access_d = !cpu_data[7] & (map_data_q[`MAP_RAM_IDX] & !addr[15] & addr[14] & !rnw) ;

   wire                         remapped_rom_access_w ;   
   wire                         remapped_ram_access_w ;
   assign remapped_rom_access_w =  !cpu_data[7] & map_data_q[`MAP_ROM_IDX] & addr[15] & ((!addr[14] & (bbc_pagereg_q[`BBC_PAGEREG_SZ-1:0] == `BASICROM_NUMBER)) |
                                                                                         ( addr[14] & (!addr[13] | !addr[12] | !addr[11] | !addr[10] | (addr[9] & addr[8]))));
   assign remapped_ram_access_w =  !cpu_data[7] & map_data_q[`MAP_RAM_IDX] & !addr[15] ;   
   assign cpu_hiaddr_lat_d[7:1] = cpu_data[7:1] | { 7{remapped_ram_access_w | remapped_rom_access_w | native_mode_int_w} };
   
   // Remapped accesses all go too the range FE0000 - FEFFFF, so don't set the bottom bit for these
   assign cpu_hiaddr_lat_d[0] = cpu_data[0] | native_mode_int_w;
   
   // Need to force dummy accesses (read from ROM) in host whenever CPU is accessing HIMEM resources (no matter which clock is used)
   assign dummy_access_w = (cpu_hiaddr_lat_q[7] & !himem_vidram_access_lat_q) | !ls_selected_w ;   
   assign { bbc_addr15, bbc_addr14 } = ( dummy_access_w ) ? { 2'b10 } : { addr[15], addr[14] } ;
   
   // only allow the BBC_RNW to go low when accessing host resource in BBC_CK2_PHI2, 
   assign bbc_rnw = rnw | dummy_access_w | !(bbc_ck2_phi2 & bbc_ck2_phi0 )  ;   
   // Drive bbc_data only for write accesses to lomem
   assign bbc_data = ( resetb & !rnw & !dummy_access_w & (bbc_ck2_phi2 | bbc_ck2_phi0) ) ? cpu_data : { 8{1'bz}};
   assign cpu_data = cpu_data_r;   

   // Select the high speed clock only 
   // * on valid instruction fetches from himem, or
   // * on valid imm/data fetches from himem _if_ hs clock is already selected, or
   // * on invalid bus cycles if hs clock is already selected
   wire himem_w =  (cpu_hiaddr_lat_q[7] & !himem_vidram_access_lat_q);
   assign hisync_w = vpa & vda & himem_w;
   assign select_hs_w = map_data_q[`CLK_HSCLK_EN_IDX] & (( hisync_w ) |
			 ((vpa | vda ) & himem_w & hs_selected_w) |
			 (!vpa & !vda & hs_selected_w)
			 ) ;

   assign map_data_d = ( cpld_reg_select_q[`CPLD_REG_SEL_MAP_CC_IDX] & !rnw ) ? cpu_data[`MAP_CC_DATA_SZ-1:0] : map_data_q;
   assign bbc_pagereg_d = ( cpld_reg_select_q[`CPLD_REG_SEL_BBC_PAGEREG_IDX] & !rnw ) ? cpu_data[`BBC_PAGEREG_SZ-1:0] : bbc_pagereg_q;

   // drive cpu data if we're reading internal register or making a non dummy read from lomem
   always @ ( cpu_ck_phi2_w or rnw or
              cpld_reg_select_q or map_data_q or 
              cpu_hiaddr_lat_q[7]
              or bbc_data
              or bbc_pagereg_q)
     if ( cpu_ck_phi2_w & rnw  )
       begin
	  if (cpu_hiaddr_lat_q[7])
	    if ( cpld_reg_select_q[`CPLD_REG_SEL_MAP_CC_IDX]  )
              cpu_data_r = { {(8-`MAP_CC_DATA_SZ){1'b0}}, map_data_q};	      
            else //must be RAM access
              cpu_data_r = {8{1'bz}};
          else
            cpu_data_r = bbc_data;
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
   
   // NB Clock switch p2 stops the clock in the PHI1=0 PHI2=1 state - not the original intention...
   clock_switch_p2_m clock_switch_0_u (
				       .hs_ck_ip( hs_clk_w),
				       .ls_ck_ip(!bbc_ck2_phi0),
				       .select_hs_ip(select_hs_w),
				       .resetb(resetb),
				       .selected_hs_op(hs_selected_w),
				       .selected_ls_op(ls_selected_w),
				       .ck_op(cpu_ck_phi1_w)
				       );

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
   	  map_data_q <= map_data_d;
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
   always @ ( cpu_ck_phi1_w or resetb or cpu_hiaddr_lat_d or himem_vidram_access_d )
     if ( ! resetb )
       begin
          cpu_hiaddr_lat_q <= 8'b0;          
          himem_vidram_access_lat_q <= 1'b0;
       end   
     else if ( cpu_ck_phi1_w )
       begin
          cpu_hiaddr_lat_q <= cpu_hiaddr_lat_d;
          himem_vidram_access_lat_q <= himem_vidram_access_d;
       end

endmodule // level1b_m
