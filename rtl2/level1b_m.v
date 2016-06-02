`timescale 1ns / 1ns

`define GPIO_DIR_SZ        8
`define GPIO_DATA_SZ       7   
`define I2C_SZ             7   
`define CLK_HSCLK_EN_IDX   6
`define CLK_DIV_EN_IDX     5
`define CLK_DIV4NOT2_IDX   4
`define CLK_INVERT_IDX     3
`define I2C_SDA_IN_IDX     2   
`define I2C_SDA_OUT_IDX    1
`define I2C_SCL_IDX        0

//`define USE_FULL_CYCLE_D 1
`define GATE_CLK_WITH_RDY_D 1
`define ALLOW_HIMEM_IN_EMUL_D 1

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
   reg           rdy_lat_q;
   reg           gpio_dir_select_q ;
   reg           gpio_data_select_q ;
   reg           i2c_select_q ;
   reg           himem_q;
    		 

   integer       idx;           
   
   
   reg [`GPIO_DIR_SZ-1:0]   gpio_dir_q;
   reg [`GPIO_DATA_SZ-1:0]  gpio_data_q;
   reg [`GPIO_DATA_SZ-1:0]  gpio_r;  
   reg [`I2C_SZ-1:0]        gpio_i2c_q;
   reg [`I2C_SZ-1:0]        gpio_i2c_d;
   reg [`GPIO_DATA_SZ-1:0]  gpio_data_d;      

   
   wire [`GPIO_DIR_SZ-1:0]  gpio_dir_w;   
   wire                     cpu_ck_phi1_w;   
   wire                     cpu_ck_phi2_w;      
   wire                     himem_w;
   wire                     dummy_access_w;
   wire                     gpio_dir_select_d ;
   wire                     gpio_data_select_d ;
   wire                     i2c_select_d ;
   wire                     hs_clk_w;


`ifdef GATE_CLK_WITH_RDY_D
   wire                     gated_clk_phi1_w ;
   assign cpu_ck_phi2 =  cpu_ck_phi2_w | !rdy_lat_q ;
`else
   assign cpu_ck_phi2 =  cpu_ck_phi2_w ;   
`endif 		    

   // SDA and SCL are both open collector
   assign sda = ( gpio_i2c_q[`I2C_SDA_OUT_IDX] ) ? 1'bz : 1'b0 ;
   assign scl = ( gpio_i2c_q[`I2C_SCL_IDX] ) ? 1'bz : 1'b0 ;
   assign gpio = gpio_r ;
   assign cpu_ck_phi1_w =  gpio_i2c_q[`CLK_HSCLK_EN_IDX] ? hs_clk_w : ! bbc_ck2_phi0;
   
   assign cpu_ck_phi2_w = ! cpu_ck_phi1_w;

   
   assign bbc_ck2_phi1 = ! bbc_ck2_phi0;
   assign bbc_ck2_phi2 = ! bbc_ck2_phi1;

`ifdef GATE_CLK_WITH_RDY_D
   assign rdy = 1'bz;   
`else   
   // rdy is a pull-down
   assign rdy = ( rdy_lat_q ) ? 1'bz : 1'b0;
`endif
   
   assign bbc_sync = vpa & vda;
   assign irqb = 1'bz;
   assign nmib = 1'bz;
   assign ram_addr16 = cpu_hiaddr_lat_q[0];
   assign ram_addr17 = cpu_hiaddr_lat_q[1];
   assign ram_addr18 = cpu_hiaddr_lat_q[2];   
   
   // himem_w is an alias to signal any access to onboard IO or RAM
   assign himem_w = cpu_hiaddr_lat_q[7];
   always @ ( negedge cpu_ck_phi1_w or negedge resetb )
     if ( !resetb)
       himem_q <= 1'b0;
     else
       if ( rdy_lat_q )
`ifdef ALLOW_HIMEM_IN_EMUL_D	 
         himem_q <= cpu_data[7] | (!vpb &  !cpu_e);   
`else
         himem_q <= (cpu_data[7] | !vpb) & !cpu_e;
`endif
   
   reg [1:0] 		    slow_access_q;
   reg 			    rdy_s0_q;
   reg 			    slow_access_retime_q;   
   reg [7:0] 		    slowbus_q;


   wire rdy_s0_d_w = slow_access_retime_q | ( rdy_s0_q & himem_q);

   // BBC access finish on the rising edge of BBC PHI1 so need to flop this data for transfer to
   // the CPU later
   always @ ( posedge bbc_ck2_phi1 )
     slowbus_q <= bbc_data;

`ifdef USE_FULL_CYCLE_D   
   // Slow access needs to count two rising edges of the BBC PHI1 clock to signal completion
   // so that the valid address is stable for a full PHI1 + PHI2 clock period
   always @ ( posedge bbc_ck2_phi1 or posedge rdy_s0_q )
     if ( rdy_s0_q )       
       slow_access_q = 2'b00;
     else
       slow_access_q = { slow_access_q[0], 1'b1};
`else // USE ONLY half cycle for valid address so that the valid address is only
   // stable throughout BBC PHI2 (which should be enough for the Beeb system)
   always @ ( negedge bbc_ck2_phi1 or posedge rdy_s0_q )
     if ( rdy_s0_q )       
       slow_access_q[0] = 1'b0;
     else
       slow_access_q[0] = 1'b1;
   
   always @ ( posedge bbc_ck2_phi1 or posedge rdy_s0_q )
     if ( rdy_s0_q )       
       slow_access_q[1] = 1'b0;
     else
       slow_access_q[1] = slow_access_q[0];
`endif
   
   // Retiming of the rdy signal and completion of the slow access is done on
   // pos edge of CPU CK PHI1
   always @ ( posedge cpu_ck_phi1_w or posedge rdy_s0_q)
     if ( rdy_s0_q )
       begin
	  slow_access_retime_q = 1'b0;
       end   
     else
       begin
	  slow_access_retime_q = slow_access_q[1]; 
       end // else: !if( ! resetb )
   
   // Retiming of the rdy signal and completion of the slow access is done on
   // pos edge of CPU CK PHI1
   always @ ( posedge cpu_ck_phi1_w or negedge resetb)
     if ( ! resetb )
       begin
	  rdy_s0_q <= 1'b1;
       end   
     else
       begin
	  rdy_s0_q <= rdy_s0_d_w;	  
       end // else: !if( ! resetb )

   // Use a latch for the RDY output to CPU so that it changes during CPU CK PHI2
   always @ ( cpu_ck_phi2_w or resetb or rdy_s0_d_w )
     if ( !resetb )
       rdy_lat_q <= 1'b1;
     else if ( cpu_ck_phi2_w )
       rdy_lat_q <= rdy_s0_d_w;
   
   
   // All addresses starting 0b11 go to the on-board RAM
   assign ram_ceb = !( cpu_ck_phi2_w && (vda | vpa) && (cpu_hiaddr_lat_q[7:6] == 2'b11) );   
   // All addresses starting with 0b10 go to internal IO registers which update on the 
   // rising edge of cpu_ck_phi1 - use the cpu_data bus directly for the high address 
   // bits since it's stable by the end of phi1
   assign gpio_dir_select_d  = vda && ( cpu_data[7:6]== 2'b10) && ( addr[1:0] == 2'b00);
   assign gpio_data_select_d = vda && ( cpu_data[7:6]== 2'b10) && ( addr[1:0] == 2'b01);   
   assign i2c_select_d       = vda && ( cpu_data[7:6]== 2'b10) && ( addr[1:0] == 2'b10);

   // Compute GPIO output pin values bit by bit
   always @ ( gpio_data_q or gpio_dir_q or gpio )
     begin
        for (idx = 0 ; idx < `GPIO_DATA_SZ ; idx = idx + 1 ) 
          begin
             // DIR=1: input , DIR = 0: output
             if ( gpio_dir_q[idx] == 1'b0 )
               gpio_r[idx] <= gpio_data_q[idx];
             else
               gpio_r[idx] <= 1'bz;
          end
     end // always @ ( gpio0_data_q or gpio_dir_q or gpio )

   
   // latch the cpu databus as the high address bits while cpu_ck_phi1_w is high and
   // use vpb and e to force these so that they are always valid
   //
   // vpb e data_in    hi_addr
   //  1  1  abcd       0000  ie a low mem operation
   //  1  0  abcd       abcd     address as specified 
   //  0  1  abcd       1111     vpb forces access to FF_xxxx
   //  0  0  abcd       1111       "    "    "     "
   //
   // If RDY is low, the CPU won't drive the bus in PHI1 so don't update the
   // address latch
   
   always @ ( cpu_ck_phi1_w or resetb or cpu_data or cpu_e or vpb or rdy_lat_q)
     if ( ! resetb )
       cpu_hiaddr_lat_q <= 8'b0;
     else if ( cpu_ck_phi1_w )
       if ( rdy_lat_q )
`ifdef ALLOW_HIMEM_IN_EMUL_D	 
         cpu_hiaddr_lat_q <= cpu_data | ( { 8{!vpb & !cpu_e}});
`else
         cpu_hiaddr_lat_q <= ( cpu_data | { 8{!vpb}}) & {8{!cpu_e}};   
`endif
   
   
   // dummy access means that the Beeb makes a ROM read
   // assign dummy_access_w = ! ( !slow_access_q[1] & slow_access_q[0]) ;
   assign dummy_access_w = ! slow_access_q[0] ;      

   // Dummy access forces read from ROM
   assign {  bbc_addr15, bbc_addr14, bbc_rnw } = ( dummy_access_w) ? 3'b101 : { addr[15], addr[14], rnw };
   
   // Drive bbc_data only for write accesses to lomem
   assign bbc_data = ( !bbc_rnw ) ? cpu_data : { 8{1'bz}};  
   assign cpu_data = cpu_data_r;

   clock_divider24_m clock_div0_u (
				   .divider_en( gpio_i2c_q[`CLK_DIV_EN_IDX]),
				   .div4not2( gpio_i2c_q[`CLK_DIV4NOT2_IDX]),
				   .invert( gpio_i2c_q[`CLK_INVERT_IDX]),
				   .clkin(bbc_ck8),
				   .resetb(resetb),
				   .clkout(hs_clk_w)
				   );
   
   // drive cpu data if we're reading internal register or making a non dummy read from lomem
   always @ ( cpu_ck_phi2_w or rnw or gpio_data_q or gpio_dir_q 
              or gpio_i2c_q or gpio_data_select_q 
              or gpio_dir_select_q or i2c_select_q or himem_w or slowbus_q )     
     if ( cpu_ck_phi2_w & rnw  )
       begin
	  if (himem_w) 
            if ( gpio_data_select_q )
              cpu_data_r = { {(8-`GPIO_DATA_SZ){1'b0}}, gpio_data_q};          
            else if ( gpio_dir_select_q )
              cpu_data_r = { {(8-`GPIO_DIR_SZ){1'b0}}, gpio_dir_q};
            else if ( i2c_select_q )
              cpu_data_r = { {(8-`I2C_SZ){1'b0}}, gpio_i2c_q};
            else //must be RAM access
              cpu_data_r = {8{1'bz}};
          else 
            cpu_data_r = slowbus_q;
       end // if ( cpu_ck_phi1_w & rnw )   
     else 
       cpu_data_r = {8{1'bz}};
   
   // Calculate next state on bit-by-bit basis for the gpio_data register
   always @ ( gpio or gpio_data_q or gpio_dir_q or gpio_data_select_q or rnw or cpu_data )
     begin
        for (idx = 0 ; idx < `GPIO_DATA_SZ ; idx = idx + 1 )
          begin
             // Input bits update every cycle from IOs
             if ( gpio_dir_q[idx] == 1'b1 )
               gpio_data_d[idx] <= gpio[idx];         
             // If we're writing to an output bit then data comes from CPU bus
             else if ( gpio_data_select_q & !rnw )
               gpio_data_d[idx] <= cpu_data[idx];
             // Otherwise bits retain state
             else                 
               gpio_data_d[idx] <= gpio_data_q[idx];             
          end
     end // always @ ( gpio or gpio_data_q or gpio_dir_q )

   // Calculate next state for I2C bits
   always @ ( gpio_i2c_q or i2c_select_q or rnw or cpu_data or sda )
     begin
	// All bits are either written from CPU data or retain state
	gpio_i2c_d = ( i2c_select_q && !rnw ) ? cpu_data[`I2C_SZ-1:0] : gpio_i2c_q;
	// except for the SDA IN bit which just copies the state on SDA pin
	gpio_i2c_d[`I2C_SDA_IN_IDX]   = sda;
     end

   // Calculate next state for the GPIO DIR reg
   assign gpio_dir_w = ( gpio_dir_select_q & !rnw ) ? cpu_data[`GPIO_DIR_SZ-1:0] : gpio_dir_q;

   
        
   // Internal registers update on the rising edge of cpu_ck_phi1
   always @ ( posedge cpu_ck_phi1_w or negedge resetb )
     if ( !resetb )
       begin
          gpio_data_q <= { `GPIO_DATA_SZ{1'b0}};
          gpio_dir_q <= {`GPIO_DIR_SZ{1'b1}};
          gpio_i2c_q <= {`I2C_SZ{1'b0}};
       end
     else
       begin
          gpio_data_q <= gpio_data_d;
          gpio_i2c_q <= gpio_i2c_d;          
   	  gpio_dir_q <= gpio_dir_w;
       end // else: !if( !resetb )
   

   // Flop all the internal register select bits on falling edge of phi1
   // for use on rising edge of phi2
   always @ ( negedge cpu_ck_phi1_w or negedge resetb )
     if ( !resetb ) 
       begin
          gpio_dir_select_q = 1'b0;
          gpio_data_select_q = 1'b0;
          i2c_select_q = 1'b0;
       end
     else
       begin
          gpio_dir_select_q = gpio_dir_select_d;          
          gpio_data_select_q = gpio_data_select_d;          
          i2c_select_q = i2c_select_d;          
       end // else: !if( !resetb )
   
endmodule // level1b_m
