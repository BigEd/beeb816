`timescale 1ns / 1ns

module testbench();

// Number of GPIOs varies depending on how packed the CPLD is...   
`define GPIO_IMPL_SZ      2
   
// define the 4 possible bus actions    
`define ADDR_IFETCH  0
`define ADDR_IMMED   1
`define ADDR_DATA    2
`define ADDR_INVALID 3   

   integer idx;
   integer fail_count = 0;
   integer total_fail_count = 0;   

   task switch_sequence;
      begin
	 // should all be ls clock
	 dataread( `ADDR_IFETCH,  24'h000005 , 8'h05);
	 dataread( `ADDR_IFETCH,  24'h000006 , 8'h06);
	 dataread( `ADDR_DATA,  24'h000002 , 8'h02);
	 dataread( `ADDR_DATA,  24'h000003 , 8'h03);        
	 dataread( `ADDR_DATA,  24'hFF0101 , 8'hC1 );
	 dataread( `ADDR_DATA,  24'hFF0102 , 8'hC2 );
	 dataread( `ADDR_DATA,  24'h000003 , 8'h03);                
	 // now fetch from himem should force a switch
	 dataread( `ADDR_IFETCH,  24'hFF0000 , 8'hC0);
	 dataread( `ADDR_IFETCH,  24'hFF0001 , 8'hC1);
	 // read from himem should keep hs clk
	 dataread( `ADDR_DATA,  24'hFF0002 , 8'hC2);
	 dataread( `ADDR_DATA,  24'hFF0003 , 8'hC3);        
	 // write to  lomem should force a switch
	 datawrite( 24'h0000FF, 8'h0A);
	 dataread( `ADDR_DATA,  24'h0000FF , 8'h0A);        
	 dataread( `ADDR_DATA,  24'h00000A , 8'h0A);
	 dataread( `ADDR_DATA,  24'h00000B , 8'h0B);
	 // back to HS mem then lowmem
	 dataread( `ADDR_IFETCH,  24'hFF0000 , 8'hC0);
	 dataread( `ADDR_DATA,  24'h00000A , 8'h0A);        
      end
   endtask // switch_sequence
   
   
   task wait_on_rdy;
      // wait until rdy_w is set to a selected value. Proc will exit as soon
      // as rdy_w is high following a negedge on the tb_cpu_ck_phi2_w clock. i.e.
      // as soon as a phi2 phase has finished with rdy_w at the chosen
      // value    
      input value;
      begin
         while (rdy_w != value )
           @( negedge tb_cpu_ck_phi2_w);
      end 
   endtask // wait_on_negedge
   
   task datawrite;
      input [23:0]  addr;
      input [7:0]   data;
      
      // phase 1
      begin
         if  (rdy_w == 1'b0 )
           while (rdy_w != 1'b1 ) 
             @( negedge tb_cpu_ck_phi2_w);                    
         else
           @( negedge tb_cpu_ck_phi2_w ) ;
         
	 cpu_addr_r = addr;
         cpu_data_r = data;          
         vpa_r = 0;
         vda_r = 1;
         rnw_r = 1;

         @( posedge tb_cpu_ck_phi2_w)
           begin
	      
              rnw_r = 0;              
              #10
                // allow a little time for rdy_w to be deasserted if
                // a clock switch event occurs
              if ( rdy_w == 1'b0 )
                while ( rdy_w == 1'b0 )
                  @ (posedge tb_cpu_ck_phi2_w );
              
           end

         
      end
   endtask // endtask

   task verify_lomem;
      begin
	 for ( idx = 0 ; idx < ( 32*1024) ; idx = idx + 1 ) 
           if ( bbc_ram0_u.mem[ idx ] != {4'b0000, idx[3:0]} )
	     $display("RAM Error at address %d, expected %x actual %x", idx, idx[3:0], bbc_ram0_u.mem[idx]);     
      end
   endtask
   
      
     

   task dataread;
      input [ 31:0] mode;      
      input [ 23:0] addr;
      input [ 7:0]  expected_data;
      
      begin
         if  (rdy_w == 1'b0 )
           wait_on_rdy( 1'b1);

         
         @(negedge tb_cpu_ck_phi2_w)
           begin
	      #10;	      
              rnw_r = 1;
              cpu_addr_r = addr;
              if ( mode == `ADDR_IFETCH)
                begin
                   vpa_r = 1;
                   vda_r = 1;
                end
              else if ( mode == `ADDR_IMMED )
                begin
                   vpa_r = 1;
                   vda_r = 0;                   
                end
              else if ( mode == `ADDR_DATA )
                begin
                   vpa_r = 0;
                   vda_r = 1;                   
                end
              else
                begin
                   vpa_r = 0;
                   vda_r = 0;
                end              
           end


         
         @( posedge tb_cpu_ck_phi2_w )
           begin
              // allow a little time for rdy_w to be deasserted if
              // a clock switch event occurs
              #5
              if ( rdy_w == 1'b0 )
                while ( rdy_w == 1'b0)
                  @ ( posedge tb_cpu_ck_phi2_w);

              #30;
                
              if (expected_data !== 8'bx )
                if ( expected_data !== cpu_data_w)
                  begin
                     $display("Error: clock=0b%1b CPU databus mismatch, expected 0x%2x actual 0x%2x at time %t ", tb_cpu_ck_phi2_w, expected_data, cpu_data_w, $time);
                     fail_count = fail_count + 1;
                     total_fail_count = total_fail_count + 1;                     
                  end
              if ( (mode == `ADDR_IFETCH ) && !(sync_w== 1'b1))
                $display("Error: Sync signal should be 1 for instruction fetches at time %t ", $time);
              else if (!( mode == `ADDR_IFETCH) && (sync_w == 1'b1))
                begin
                   $display( "%x %x", mode, sync_w);
                   
                   $display("Error: Sync signal should be 0 for all non-instruction fetches at time %t ", $time);
                end
           end
      end
      
   endtask // endtask
   

   // register declarations
   
   reg [23:0] cpu_addr_r;
   reg 	      resetb_r;
   reg 	      vpb_r;
   reg 	      e_r;
   reg 	      vda_r;
   reg 	      vpa_r;
   reg 	      bbc_ck2_phi0_r;
   reg 	      bbc_ck8_r;
   reg 	      rnw_r;
   reg [7:0]  cpu_data_r;
   reg [7:0]  bbc_data_r;
   reg [`GPIO_IMPL_SZ-1:0]  gpio_r;
   

   // wires and combinatorial assigments
   wire [15:0] cpu_addr_w = cpu_addr_r[15:0];
   wire        resetb_w = resetb_r;   
   wire        vpb_w = vpb_r;   
   wire        e_w = e_r;
   wire        vda_w = vda_r;
   wire        vpa_w = vpa_r;
   wire        bbc_ck2_phi0_w = bbc_ck2_phi0_r;
   wire        bbc_ck8_w = bbc_ck8_r;
   wire        rnw_w = rnw_r;
   wire [7:0]  cpu_data_w ;
   wire [7:0]  bbc_data_w ;   
   wire        nmib_w = 1'bz;
   wire        irqb_w = 1'bz;
   wire [18:0] ram_addr_w;
   wire [15:0] bbc_addr_w;
   wire        bbc_rnw_w;      
   wire        bbc_ceb_w;
   wire        bbc_ck2_phi1_w;
   wire        bbc_ck2_phi2_w;   
   wire        tb_cpu_ck_phi2_w;
   wire        cpu_ck_phi1_w = !tb_cpu_ck_phi2_w;
   wire        sync_w;
   wire        rdy_w;
   wire        scl_w;
   wire        sda_w;
   wire [6:0]  gpio_w ;


   assign gpio_w = { {( 6-`GPIO_IMPL_SZ){1'b0}}, gpio_r};
            
   // rdy and I2C ports need a pull-up
   assign (weak1,strong0) rdy_w = 1;
   assign (weak1,strong0) sda_w = 1;
   assign (weak1,strong0) scl_w = 1;   
   
   assign ram_addr_w[15:0] = cpu_addr_w[15:0];
   assign bbc_addr_w[13:0] = cpu_addr_w[13:0];   

   // CPU (testbench) drives bus in PHI1 and when writing
   assign cpu_data_w = (cpu_ck_phi1_w & rdy_w) ? cpu_addr_r[23:16] : ((!rnw_w ) ? cpu_data_r : 8'bz);
   
   

// Host is represented by a 64K RAM which is always enabled and can
// drive the data bus during BBC phi2 only. Dummy accesses will be
// performed on this device when himem is being accessed
ram_64kx8_m bbc_ram0_u  (
  .addr( bbc_addr_w),
  .data( bbc_data_w),
  .ceb ( bbc_ck2_phi1_w ),
  .rnw ( bbc_rnw_w),
  .oeb ( bbc_ck2_phi1_w)
  );

// On board memory wired up as in the schematic
ram_512kx8_m card_ram0_u  (
  .addr( ram_addr_w),
  .data( cpu_data_w),
  .ceb ( ram_ceb_w ),
  .rnw ( rnw_w),
  .oeb ( ram_ceb_w)
  );
   
  
level1b_m dut0_u (
  .addr(cpu_addr_w[15:0]),
  .resetb(resetb_w),
  .gpio(gpio_w),
  .vpb(vpb_w),
  .cpu_e(e_w),
  .vda(vda_w),
  .vpa(vpa_w),
  .bbc_ck2_phi0(bbc_ck2_phi0_w),
  .bbc_ck8(bbc_ck8_w),
  .rnw(rnw_w),
  .cpu_data(cpu_data_w),
  .bbc_data(bbc_data_w),
  .rdy(rdy_w),
  .nmib(nmib_w),
  .scl(scl_w),
  .sda(sda_w),
  .irqb(irqb_w),
  .ram_ceb(ram_ceb_w),
  .ram_addr18(ram_addr_w[18]),		  
  .ram_addr17(ram_addr_w[17]),
  .ram_addr16(ram_addr_w[16]), 	 
  .bbc_sync(sync_w),
  .bbc_addr15(bbc_addr_w[15]),
  .bbc_addr14(bbc_addr_w[14]),
  .bbc_rnw(bbc_rnw_w),
  .bbc_ck2_phi1(bbc_ck2_phi1_w),
  .bbc_ck2_phi2(bbc_ck2_phi2_w),		  
  .cpu_ck_phi2(tb_cpu_ck_phi2_w)
  );



   
   initial
     begin
        $dumpvars;
        
	// initialize everything
        bbc_ck2_phi0_r = 0;
	e_r = 1; // kick off in emulation mode
	rnw_r = 1;
	vpa_r = 0;
	vda_r = 0;
	vpb_r = 1; // active low!        
	resetb_r = 0;
	cpu_addr_r = 23'b0;
        gpio_r = {`GPIO_IMPL_SZ{1'bz}};
	#100 resetb_r = 1;


        // try some lo mem accesses
        $display( "***********************************************");        
        $display( "Sequence of lomem accesses in emulation mode");
        fail_count = 0;        
        dataread( `ADDR_IFETCH,  24'h000000 , 8'h00);
        dataread( `ADDR_IFETCH,  24'h000001 , 8'h01);
        dataread( `ADDR_IFETCH,  24'h000002 , 8'h02);
        dataread( `ADDR_IFETCH,  24'h000003 , 8'h03);        
        dataread( `ADDR_DATA, 24'h000100 , 8'h00);
        dataread( `ADDR_DATA, 24'h000101 , 8'h01);
        dataread( `ADDR_DATA, 24'h000102 , 8'h02);
        $display( "-----------------------------------------------");        
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");
        $display( "***********************************************");                
        $display( "Sequence of himem accesses in emulation mode");
        fail_count = 0;                
        dataread( `ADDR_IFETCH,  24'hFF000A , 8'hCA);
        dataread( `ADDR_IFETCH,  24'hFF000B , 8'hCB);
        dataread( `ADDR_IFETCH,  24'hFF000C , 8'hCC); 
        dataread( `ADDR_DATA, 24'hFF0101 , 8'hC1);
        dataread( `ADDR_DATA, 24'hFF0102 , 8'hC2);
	verify_lomem;
	
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");        
        $display( "***********************************************");        
        $display( "Sequence of lomem accesses in native mode");        
        e_r = 0;
        fail_count = 0;                        
        dataread( `ADDR_IFETCH,  24'h000000 , 8'h00);
        dataread( `ADDR_IFETCH,  24'h000001 , 8'h01);
        dataread( `ADDR_IFETCH,  24'h000002 , 8'h02);
        dataread( `ADDR_IFETCH,  24'h000003 , 8'h03);        
        dataread( `ADDR_DATA, 24'h000100 ,8'h00);
        dataread( `ADDR_DATA, 24'h000101 ,8'h01);
        dataread( `ADDR_DATA, 24'h000102 ,8'h02);
        $display( "-----------------------------------------------");        
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");                
        $display( "***********************************************");        
        $display( "Sequence of himem accesses in native mode");
        fail_count = 0;                        
        dataread( `ADDR_IFETCH,  24'hFF000A , 8'hCA);
        dataread( `ADDR_IFETCH,  24'hFF000B , 8'hCB);
        dataread( `ADDR_IFETCH,  24'hFF000C , 8'hCC); 
        dataread( `ADDR_DATA, 24'hFF0101 ,8'hC1);
        dataread( `ADDR_DATA, 24'hFF0102 ,8'hC2);
        $display( "-----------------------------------------------");        
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");                        
        $display( "***********************************************");        
        $display ("Check that vpb=0 forces accesses from HIGH in native mode");
        vpb_r = 0;
        fail_count = 0;                        
        dataread( `ADDR_IFETCH,  24'h000000 , 8'hC0);
        dataread( `ADDR_IFETCH,  24'h000001 , 8'hC1);
        dataread( `ADDR_IFETCH,  24'h000002 , 8'hC2);
        dataread( `ADDR_IFETCH,  24'h000003 , 8'hC3);        
        dataread( `ADDR_DATA, 24'hFF0101 , 8'hC1 );
        dataread( `ADDR_DATA, 24'hFF0102 , 8'hC2 );
        $display( "-----------------------------------------------");        
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");                        
        $display( "***********************************************");        
        $display ("Check CPLD internal register read/write");        
        vpb_r = 1;
        fail_count = 0;                        
        datawrite( 24'h800000, 8'h55 );
        dataread( `ADDR_DATA, 24'h800000, 8'h55  &  {{ (8-`GPIO_IMPL_SZ){1'b0}},{`GPIO_IMPL_SZ{1'b1}}}  );
        datawrite( 24'h800000, 8'hAA );                
        dataread( `ADDR_DATA, 24'h800000, 8'hAA  &  {{ (8-`GPIO_IMPL_SZ){1'b0}},{`GPIO_IMPL_SZ{1'b1}}} ); 
        $display( "-----------------------------------------------");        
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");
        $display( "***********************************************");
        $display( " Check operation of GPIOs                      ");
        fail_count = 0;
        // Set all GPIOs to outputs
        datawrite( 24'h800000, 8'h00 );
        // Write value out
        datawrite( 24'h800001, 8'h55 );

        if ( gpio_w != 7'h55 )
          fail_count = fail_count+1;
        dataread( `ADDR_DATA,  24'hB00001 , 8'h55 &  {{ (8-`GPIO_IMPL_SZ){1'b0}},{`GPIO_IMPL_SZ{1'b1}}} );
        // Set all GPIOs to inputs
        datawrite( 24'h800000, 8'hFF );
        gpio_r = 7'h2A;
        // Need 1 cycle between switching direction and first sampled value on inputs
        dataread( `ADDR_DATA,  24'hB00001 , 8'hxx);
        dataread( `ADDR_DATA,  24'hB00001 , 8'h2A &  {{ (8-`GPIO_IMPL_SZ){1'b0}},{`GPIO_IMPL_SZ{1'b1}}}  );

        $display( "-----------------------------------------------");        
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");                        
        $display( "***********************************************");
        $display( " Check operation of I2C reg                    ");
        fail_count = 0;        
        // write and read back bottom 3 I2c bits - NB need a nop between writing the register and reading back from the pins
        datawrite( 24'h800002, 8'h0F );
        dataread(`ADDR_DATA,  24'hB00002 , 8'hxx);        
        dataread(`ADDR_DATA,  24'hB00002 , 8'h07);
        datawrite( 24'h800002, 8'h00 );
        dataread(`ADDR_DATA,  24'hB00002 , 8'hxx);                
        dataread(`ADDR_DATA,  24'hB00002 , 8'h00);                
        $display( "-----------------------------------------------");        
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");
        $display( "***********************************************");
        $display( " Enable High Speed clock (but not divider)     ");
        datawrite( 24'h800003, 8'h08 );	
        $display( " Check operation of Clock Switch again         ");        
        fail_count = 0;           
        e_r = 0;
	switch_sequence;
        $display( "-----------------------------------------------");        
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");                        
        $display( "***********************************************");
        $display( " Enable High Speed clock (and divider/2)     ");
        datawrite( 24'h800003, 8'h0A );	
        $display( " Check operation of Clock Switch again         ");
        
        fail_count = 0;           
        e_r = 0;
	switch_sequence;	
        $display( "-----------------------------------------------");        
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");
        $display( "***********************************************");                        
        $display( " Enable High Speed clock (and divider/4)     ");
        dataread(`ADDR_DATA,  24'h000002 , 8'hXX);                
        dataread(`ADDR_DATA,  24'h000002 , 8'hXX);                	
        datawrite( 24'h800003, 8'h0B );	
        $display( " Check operation of Clock Switch again         ");
        
        fail_count = 0;           
        e_r = 0;
	switch_sequence;
        dataread(`ADDR_DATA,  24'h000002 , 8'hXX);                
        dataread(`ADDR_DATA,  24'h000002 , 8'hXX);                		
        $display( "-----------------------------------------------");        
        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");                        
        $display( "===============================================");        
        if ( total_fail_count == 0 ) 
          $display("PASS - all tests ok");	
        else
          $display("FAIL - total failing checks %d", total_fail_count);
        $display( "===============================================");     
        $display(" End at time %t", $time );
	
        $finish;

     end


// write lsbs of each cell's address as data
   
   
   initial
     // Setup RAMs so that
     // BBC ROM holds 0011<lsbs>
     // BBC RAM holds 0000<lsbs>
     // himem   hold  1100<lsbs>
     begin
        for ( idx = 0 ; idx < ( 32*1024) ; idx = idx + 1 ) 
          bbc_ram0_u.mem[ idx ] = {4'b0000, idx[3:0]};     
        for ( idx = (32*1024) ; idx < ( 64*1024) ; idx = idx + 1 ) 
          bbc_ram0_u.mem[ idx ] = {4'b0011, idx[3:0]};     
        for ( idx = 0 ; idx < ( 512*1024) ; idx = idx + 1 ) 
          card_ram0_u.mem[ idx ] = {4'b1100, idx[3:0]};     
     end
   
   
   // Setup clocks - slow clock
   always 
     begin
	#1000 bbc_ck2_phi0_r = 0;
	#1000 bbc_ck2_phi0_r = 1;	
     end

   // fast clock asynchronous to slow clock
   always
     begin
	#59 bbc_ck8_r = 1;
        #59 bbc_ck8_r = 0;
     end

   
   
endmodule // testbench
