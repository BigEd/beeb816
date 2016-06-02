`define MAXDELAY 6
module clock_delay_m(
    input        ck_ip,     // incoming primary clock
    input 	 ext_ck_ip, // optionally delayed primary clock (or incrementally delayed clock)		    
    input 	 invert_ip, // invert output of this stage
    input 	 cksel_ip,  // 0 selected ck_ip; 1 selected delayed clock
    input 	 extdel_ip, // 1 selects ext_ck_ip, 0 ignores the external clock
    input [2:0]  intdel_ip, // 3 bit selection of delay line length
    input 	 rosc_ip,   // enable ring oscillator through delay line		     

    inout [`MAXDELAY-1:0]  stage_del_bp, // all output stages have to appear at a pin
    output       ck_op        // delayed clock for use in CPLD
		     );

   // ensure we have some delay in chain before allowing use of ringosc mode
   wire [`MAXDELAY-1:0] bypass_w;
   wire [`MAXDELAY:0] 	ck_del_w;
   wire 		osc_en_w;
 		
   assign osc_en_w = ( rosc_ip & intdel_ip[2] ) ; 
   assign ck_del_w[0] = ( osc_en_w ) ? !ck_del_w[`MAXDELAY] : ck_ip;

   assign ck_op = ( cksel_ip ) ? ( invert_ip ^ ck_del_w[`MAXDELAY]) : ( invert_ip ^ ck_ip ) ;

   assign bypass_w = ( intdel_ip == 3'h0) ? `MAXDELAY'b111111:
		     ( intdel_ip == 3'h1) ? `MAXDELAY'b111110:
		     ( intdel_ip == 3'h2) ? `MAXDELAY'b111100:
		     ( intdel_ip == 3'h3) ? `MAXDELAY'b111000:
		     ( intdel_ip == 3'h4) ? `MAXDELAY'b110000:
		     ( intdel_ip == 3'h5) ? `MAXDELAY'b100000:
		     ( intdel_ip == 3'h6) ? `MAXDELAY'b000000:
		     ( intdel_ip == 3'h7) ? `MAXDELAY'b000000:
		     `MAXDELAY'b111111;
   

   // Construct the delay line
   clock_delay_sa_m stage0 (
			    .ck_ip(ck_del_w[0]),
			    .bypass_ip(bypass_w[0]),
			    .ck_del_bp(stage_del_bp[0]),
			    .ck_op(ck_del_w[1])
			    );
   clock_delay_sa_m stage1 (
			    .ck_ip ( (extdel_ip)?ext_ck_ip : ck_del_w[1] ),
			    .bypass_ip(bypass_w[1]),
			    .ck_del_bp(stage_del_bp[1]),
			    .ck_op(ck_del_w[2])
			    );
   clock_delay_sa_m stage2 (
			    .ck_ip ( ck_del_w[2] ),
			    .bypass_ip(bypass_w[2]),
			    .ck_del_bp(stage_del_bp[2]),
			    .ck_op(ck_del_w[3])
			    );
   clock_delay_sa_m stage3 (
			    .ck_ip ( ck_del_w[3] ),
			    .bypass_ip(bypass_w[3]),
			    .ck_del_bp(stage_del_bp[3]),
			    .ck_op(ck_del_w[4])
			    );
   clock_delay_sa_m stage4 (
			    .ck_ip ( ck_del_w[4] ),
			    .bypass_ip(bypass_w[4]),
			    .ck_del_bp(stage_del_bp[4]),
			    .ck_op(ck_del_w[5])
			    );
   clock_delay_sa_m stage5 (
			    .ck_ip ( ck_del_w[5] ),
			    .bypass_ip(bypass_w[5]),
			    .ck_del_bp(stage_del_bp[5]),
			    .ck_op(ck_del_w[6])
			    );
    
		  
endmodule // clock_delay_m
