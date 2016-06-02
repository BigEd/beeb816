// Clock_delay_sa_m.v
//
// Slice A of clock delay logic
//
//  ckin    
//                 |                         ___
//                 *------------------------|&  |---|>---*----[]
//                 |                     +-o|___|        |
//                 |   +-------------<|--|---------------+
//               __|___|__               |
//               \_1___0_/---------------*--------------------- bypass
//                   |
//                 ckout
//  
module clock_delay_sa_m (
			 input ck_ip,
			 input bypass_ip,
			 inout ck_del_bp,
			 output ck_op
			 );
   wire 			delayed_ck_w;

`ifdef SIMULATION_D
   assign #10 delayed_ck_w = ck_del_bp;
`else  
   BUF   buf_0_u ( .I(ck_del_bp), .O(delayed_ck_w));
`endif
		   
   assign ck_del_bp = ck_ip & !bypass_ip;
   assign ck_op = ( bypass_ip ) ? ck_ip : delayed_ck_w;
   
endmodule // clock_delay_sa_m
