// clock_switch_p1_m.v
//
// This clock switch version in intended to receive the select_hs_ip signal while the clock is high and stop
// the clock in that high state. e.g. for use of the 6502 system, detect the need to switch in phi1 and stay
// in phi1 until the switch can be made.
//
//
//

module clock_switch_p1_m (		       
                       input hs_ck_ip,
                       input ls_ck_ip,
                       input select_hs_ip,
                       input resetb,
                       output selected_hs_op,
                       output selected_ls_op,                       
                       output ck_op
                       );

   reg hs_enable_lat_q,
       ls_enable_lat_q,
       hs_enable_q,
       retimed_hs_enable_q,       
       retimed_ls_enable_q;
   
   wire ck_w = (hs_ck_ip |  !hs_enable_lat_q ) & (ls_ck_ip | !ls_enable_lat_q);
   
   assign ck_op = ck_w;
   assign selected_hs_op = hs_enable_q;
   assign selected_ls_op = ls_enable_lat_q;

   // Record the enable signal in a latch and a flop for hs clock domain. Use the latch
   // to actually gate the clock itself to avoid any glitches due to the ck-q delay of a
   // flop. Use the flop to supply the state to the rest of the edge triggered logic.
   always @ ( negedge hs_ck_ip or negedge resetb )
     if ( ! resetb )
       hs_enable_q <= 1'b0;   
     else
       hs_enable_q <= select_hs_ip & !retimed_ls_enable_q;
   
   always @ ( hs_ck_ip or resetb or select_hs_ip or retimed_ls_enable_q)
     if ( ! resetb )
       hs_enable_lat_q <= 1'b0;   
     else if ( hs_ck_ip ) 
       hs_enable_lat_q <= select_hs_ip & !retimed_ls_enable_q;
   
   always @ ( ls_ck_ip or resetb or select_hs_ip or retimed_hs_enable_q)
     if ( ! resetb )
       ls_enable_lat_q <= 1'b0;   
     else if ( ls_ck_ip )
       ls_enable_lat_q <= !select_hs_ip & !retimed_hs_enable_q;

   
   // Retime the enable signals from one domain to the other.  
   always @ ( negedge  hs_ck_ip or posedge ls_enable_lat_q or negedge resetb)
     if ( ! resetb ) 
          retimed_ls_enable_q <= 1'b1;
     else if ( ls_enable_lat_q )
          retimed_ls_enable_q <= 1'b1;
     else
          retimed_ls_enable_q <= ls_enable_lat_q;

   // Need to use the hs_enable as an async signal here else
   // we might 'miss' the high enable for a single cycle and
   // get a truncated ls phi1 pulse
   always @ ( negedge  ls_ck_ip or posedge hs_enable_q or negedge resetb)
     if ( ! resetb ) 
       retimed_hs_enable_q <= 1'b0;
     else if ( hs_enable_q )
       retimed_hs_enable_q <= 1'b1;
     else
       retimed_hs_enable_q <= 1'b0;   

endmodule // clock_switch_m
