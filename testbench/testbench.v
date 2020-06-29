`timescale 1ns / 1ns


primitive INV (O, I);  
  output O;
  input  I;
  
  table
    //I : O
    ?   :   x;
    1   :   0;
    0   :   1;
  endtable
endprimitive

module testbench();
  

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
	 // Reads from remapped RAM can be with HS or LS clock
	 dataread( `ADDR_IFETCH,  24'h000005 , 8'hC5);
	 dataread( `ADDR_IFETCH,  24'h000006 , 8'hC6);
	 dataread( `ADDR_DATA,  24'h000002 , 8'hC2);
	 dataread( `ADDR_DATA,  24'h000003 , 8'hC3);
        // Reads from native RAM
	 dataread( `ADDR_DATA,  24'hFF0101 , 8'hC1 );
	 dataread( `ADDR_DATA,  24'hFF0102 , 8'hC2 );
	 dataread( `ADDR_DATA,  24'h000003 , 8'hC3);
        // Writes to remapped RAM must force a switch  and stay there 'til a new IFETCH 
	 datawrite( 24'h00400A, 8'h0A);	 
         datawrite( 24'h00400B, 8'h0B);
	 dataread( `ADDR_DATA,  24'h00400A , 8'h0A );    // Read back via remapped RAM
	 dataread( `ADDR_DATA,  24'h00400B , 8'h0B );        
	 // now fetch from himem should force a switch
	 dataread( `ADDR_IFETCH,  24'hFF0000 , 8'hC0);
	 dataread( `ADDR_IFETCH,  24'hFF0001 , 8'hC1);
	 // read from himem should keep hs clk
	 dataread( `ADDR_DATA,  24'hFF0002 , 8'hC2);
	 dataread( `ADDR_DATA,  24'hFF0003 , 8'hC3);
	 dataread( `ADDR_DATA,  24'hFF0004 , 8'hC4);        
	 dataread( `ADDR_DATA,  24'hFF0005 , 8'hC5);                 
	 // write to fast portion (fully shadowed) lomem stays in high speed mode
	 datawrite( 24'h0000FF, 8'h0A);
	 dataread( `ADDR_DATA,  24'h0000FF , 8'h0A);        
	 // write to  slow lomem should force a switch
	 datawrite( 24'h0040FF, 8'h0A);
	 dataread( `ADDR_DATA,  24'h0040FF , 8'h0A);
	 datawrite( 24'h0040FF, 8'h0B);
	 dataread( `ADDR_DATA,  24'h0040FF , 8'h0B);                
	 datawrite( 24'h00400B, 8'h0C);
	 dataread( `ADDR_DATA,  24'h00400B , 8'h0C);
	 // back to HS mem then lowmem
	 dataread( `ADDR_IFETCH,  24'hFF0000 , 8'hC0);
	dataread( `ADDR_DATA,  24'h00000A , 8'hCA); // Via remapped RAM
         dataread( `ADDR_IFETCH,  24'hFF0000 , 8'hC0);
	 dataread( `ADDR_DATA,  24'h00000A , 8'hCA);    // Via remapped RAM
         dataread( `ADDR_IFETCH,  24'hFF0000 , 8'hC0);
	 // write to  should force a switch
	 datawrite( 24'h0080FF, 8'h0A);
	 // now fetch from himem should force a switch
	 dataread( `ADDR_IFETCH,  24'hFF0000 , 8'hC0);
	 dataread( `ADDR_IFETCH,  24'hFF0001 , 8'hC1);   
         
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
      // RNW must become active before rising PHI2
      #20 rnw_r = 0;
      
      @( posedge tb_cpu_ck_phi2_w)
        begin
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
           begin
              $display("Info: dataread() waiting on RDY") ;              
              wait_on_rdy( 1'b1);
           end
         

         
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
   reg 	      hsclk_r;
   reg 	      rnw_r;
   reg [7:0]  cpu_data_r;
   reg [7:0]  bbc_data_r;
   

   // wires and combinatorial assigments
   wire [15:0] cpu_addr_w = cpu_addr_r[15:0];
   wire        resetb_w = resetb_r;   
   wire        vpb_w = vpb_r;   
   wire        e_w = e_r;
   wire        vda_w = vda_r;
   wire        vpa_w = vpa_r;
   wire        bbc_ck2_phi0_w = bbc_ck2_phi0_r;
   wire        hsclk_w = hsclk_r;
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
   wire [6:0]  gpio_w;
   reg         scl_r;
   

            
   // rdy and I2C ports need a pull-up
   assign (weak1,strong0) rdy_w = 1;
   assign (weak1,strong0) sda_w = 1;
   always @ ( sda_w ) 
     scl_r <= #15 sda_w;
   assign (weak1,strong0) scl_w = scl_r;   
   
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
  .vda(vda_w),
  .vpa(vpa_w),
  .bbc_ck2_phi0(bbc_ck2_phi0_w),
  .hsclk(hsclk_w),
  .rnw(rnw_w),
  .cpu_data(cpu_data_w),
  .bbc_data(bbc_data_w),
`ifndef GATESIM_D                  
  .vpb(vpb_w),
  .cpu_e(e_w),
  .rdy(rdy_w),
  .nmib(nmib_w),
  .scl(scl_w),
  .sda(sda_w),
  .irqb(irqb_w),
`endif                  
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
	#100 resetb_r = 1;
        
        #200 ;
        
        // try some lo mem accesses
        $display( "***********************************************");        
        $display( "Sequence of lomem accesses in emulation mode");
        // make sure that lowmem is not mapped to high mem to start with ...
        datawrite( 24'h800003, 8'h00 );	        
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
//        $display ("Check that vpb=0 forces accesses from HIGH in native mode");
//        vpb_r = 0;
//        fail_count = 0;                        
//        dataread( `ADDR_IFETCH,  24'h000000 , 8'hC0);
//        dataread( `ADDR_IFETCH,  24'h000001 , 8'hC1);
//        dataread( `ADDR_IFETCH,  24'h000002 , 8'hC2);
//        dataread( `ADDR_IFETCH,  24'h000003 , 8'hC3);        
//        dataread( `ADDR_DATA, 24'hFF0101 , 8'hC1 );
//        dataread( `ADDR_DATA, 24'hFF0102 , 8'hC2 );
//        vpb_r = 1;
//        $display( "-----------------------------------------------");        
//        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");
//        $display( "***********************************************");
       $display( " Enable High Speed clock (divide by 4)     ");
       datawrite( 24'h800003, 8'hB0 );
       datawrite( 24'h800003, 8'hF0 );	       
       $display( " Check operation of Clock Switch again         ");        
       fail_count = 0;           
       e_r = 0;
       switch_sequence;
       $display( "-----------------------------------------------");        
       if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");                        
       $display( "***********************************************");
//        $display( " Enable High Speed clock (divide by 8)     ");
//        datawrite( 24'h800003, 8'hB0 );
//        datawrite( 24'h800003, 8'hB1 );	
//        datawrite( 24'h800003, 8'hF1 );	       
//        $display( " Check operation of Clock Switch again         ");
//        
//        $display( "-----------------------------------------------");        
//        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");
//        $display( "***********************************************");                        
//        $display( " Check Video RAM mirroring and slow down    ");
//        fail_count = 0;           
//        e_r = 0;
//        datawrite( 24'h800003, 8'hB1 );	
//        dataread( `ADDR_IFETCH,  24'hFF0001 , 8'hC1);        
//        dataread(`ADDR_DATA,  24'h000002 , 8'hXX);                
//        dataread(`ADDR_DATA,  24'h000002 , 8'hXX);
//        // Reads from video RAM come from upper RAM
//        dataread(`ADDR_DATA,  24'hFF4000 , 8'hC0);
//        dataread(`ADDR_DATA,  24'hFF4001 , 8'hC1);
//        // writes go to lower RAM at low speed
//        datawrite( 24'h006010, 8'hAA );	
//        datawrite( 24'h006011, 8'h55 );
//        dataread(`ADDR_DATA,  24'h006010 , 8'hAA);
//        dataread(`ADDR_DATA,  24'h006011 , 8'h55);
//        datawrite( 24'h800003, 8'hB0 );	
//        $display( " Check operation of Clock Switch again         ");
//         
//        fail_count = 0;           
//        e_r = 0;
//	switch_sequence;	
//        $display( "-----------------------------------------------");        
//        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");
//        $display( "***********************************************");                        
//        $display( " Enable High Speed clock (and divider/4)     ");
//        dataread(`ADDR_DATA,  24'h000002 , 8'hXX);                
//        dataread(`ADDR_DATA,  24'h000002 , 8'hXX);                	
//        datawrite( 24'h800003, 8'h0B );	
//        $display( " Check operation of Clock Switch again         ");
//        
//        fail_count = 0;           
//        e_r = 0;
//	switch_sequence;
//        dataread(`ADDR_DATA,  24'h000002 , 8'hXX);                
//        dataread(`ADDR_DATA,  24'h000002 , 8'hXX);                		
//        $display( "-----------------------------------------------");        
//        if ( fail_count == 0 ) $display("PASS"); else $display("FAIL");                        
//        $display( "===============================================");        
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

   always
     begin
	#100 hsclk_r = 1;
        #100 hsclk_r = 0;
     end

   
   
endmodule // testbench
