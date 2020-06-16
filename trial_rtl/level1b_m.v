`timescale 1ns / 1ns

// Trial build with access to HIMEM, but no acceleration and no overlay of ROMs or low RAM into fast HIMEM
//
// Interrupts are not handled in '816 mode

`define GPIO_SZ 7

module level1b_m (
                  input [15:0]         addr,
                  input                resetb,
                  input                vpb,
                  input                cpu_e,
                  input                vda,
                  input                vpa,
                  input                bbc_ck2_phi0,
                  input                bbc_ck8,
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
           
  wire [7:0]                           cpu_hiaddr_lat_d;         
  wire                                 rdy_w;   
  wire                                 cpu_ck_phi1_w;   
  wire                                 cpu_ck_phi2_w;      
  wire                                 dummy_access_w;

     
  (* KEEP="TRUE" *) wire ckdel_1_b, ckdel_3_b ;
  (* KEEP="TRUE" *) wire ckdel_2, ckdel_4;
  
  INV    ckdel1   ( .I(bbc_ck2_phi0), .O(ckdel_1_b));
  INV    ckdel2   ( .I(ckdel_1_b),    .O(ckdel_2));
  INV    ckdel3   ( .I(ckdel_2),      .O(ckdel_3_b));
  INV    ckdel4   ( .I(ckdel_3_b),    .O(ckdel_4));
  
  //   assign cpu_ck_phi2_w = !cpu_ck_phi1_w ;
  assign cpu_ck_phi1_w = ckdel_1_b;  
  assign cpu_ck_phi2_w = ckdel_2 ;     
  assign cpu_ck_phi2 =  cpu_ck_phi2_w ;   
  
  assign bbc_ck2_phi1 = ckdel_1_b;
  assign bbc_ck2_phi2 = ckdel_2 ;

  assign bbc_sync = vpa & vda;
  assign rdy = 1'bz;  
  assign irqb = 1'bz;
  assign nmib = 1'bz;  
  assign sda = 1'bz;
  assign scl = 1'bz;  
  assign gpio = `GPIO_SZ'bz;
  
  // Drive the all RAM address pins, allowing for 512K RAM connection
  assign ram_addr16 = cpu_hiaddr_lat_q[0] ;
  assign ram_addr17 = cpu_hiaddr_lat_q[1] ;
  assign ram_addr18 = cpu_hiaddr_lat_q[2] ;   
  
  // All addresses starting 0b11 go to the on-board RAM
  assign ram_ceb = !( cpu_ck_phi2_w && (vda | vpa ) && (cpu_hiaddr_lat_q[7:6] == 2'b11) );

  // Force dummy read access to ROM when accessing himem only
  assign dummy_access_w = cpu_hiaddr_lat_q[7] ;
  assign { bbc_addr15, bbc_addr14 } = (dummy_access_w) ? 2'b10 : { addr[15], addr[14] } ;  
  assign bbc_rnw = rnw | dummy_access_w ;     
  assign bbc_data = ( !bbc_rnw & bbc_ck2_phi2 ) ? cpu_data :  8'bz;
  
  // Tristate databus in PHI1 or for writes or access to onboard mem
  assign cpu_data = (cpu_ck_phi1_w | !rnw | cpu_hiaddr_lat_q[7]) ? 8'bz : bbc_data;   
  
  // Latches for the high address bits open during PHI1
  always @ ( * )
    if ( ! resetb )
      cpu_hiaddr_lat_q <= 8'b0;          
    else if ( cpu_ck_phi1_w )
      cpu_hiaddr_lat_q <= cpu_data;
  

  
endmodule // level1b_m
