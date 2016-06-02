// clock_switch_m.v
//
//
// options:
//
// if CLOCK_SWITCH_USE_LATCH_D is set then the enabling is done using latches instead
// of FFs. The latches are open on the low state of the clock and are used to gate the
// net rising edge of the clock.
//
// Using latches instead of the default negative edge triggered flops gives more time for
// the incoming select_hs_ip signal to be computed, but it must be valid to the end of
// the second half of the clock cycle.
//
// Xilinx (and other STA tools) don't time latches as well as flops, so it's safer to
// use the default flops if the enable can be made to arrive early enough.
//

module clock_switch_m (
                       input hs_ck_ip,
                       input ls_ck_ip,
                       input select_hs_ip,
                       input resetb,
                       output selected_hs_op,
                       output selected_ls_op,                       
                       output ck_op
                       );

   reg hs_enable_q,
       ls_enable_q,
       retimed_hs_enable_q,
       retimed_ls_enable_q,
       selected_hs_q,
       selected_ls_q;

   wire ck_w = (hs_ck_ip & hs_enable_q ) | (ls_ck_ip & ls_enable_q);
   
   assign ck_op = ck_w;
//   assign selected_hs_op = selected_hs_q;
//   assign selected_ls_op = selected_ls_q;   
   assign selected_ls_op =  ls_enable_q;
   assign selected_hs_op =  hs_enable_q;   
   

   
   

   // The 'status' returned is always timed off the output clock
   always @ (posedge ck_w or negedge resetb) 
     if ( ! resetb )
       begin
          selected_hs_q <= 1'b0;
          selected_ls_q <= 1'b0;
       end
     else
       begin
          selected_hs_q <= hs_enable_q & !retimed_ls_enable_q;
          selected_ls_q <= ls_enable_q & !retimed_hs_enable_q;
       end
   
   
   // Create the clock enabling state with latches or flops as required
`ifdef CLOCK_SWITCH_USE_LATCH_D
   always @ (hs_ck_ip or resetb or select_hs_ip or retimed_ls_enable_q or retimed_hs_enable_q)
     if ( ! resetb )
       hs_enable_q <= 1'b0;   
     else if ( hs_ck_ip == 1'b0 )
       hs_enable_q <= select_hs_ip & !retimed_ls_enable_q;
   
   always @ (ls_ck_ip or resetb )
     if ( ! resetb )
       ls_enable_q <= 1'b0;   
     else if ( ls_ck_ip == 1'b0 )
       ls_enable_q <= !select_hs_ip & !retimed_hs_enable_q;
`else // !`ifdef CLOCK_SWITCH_USE_LATCH_D
   always @ (negedge hs_ck_ip or negedge resetb )
     if ( ! resetb )
       hs_enable_q <= 1'b0;   
     else
       hs_enable_q <= select_hs_ip & !retimed_ls_enable_q;
   
   always @ (negedge ls_ck_ip or negedge resetb )
     if ( ! resetb )
       ls_enable_q <= 1'b1;   
     else
       ls_enable_q <= !select_hs_ip & !retimed_hs_enable_q;
   
`endif // !`ifdef CLOCK_SWITCH_USE_LATCH_D

   // Retime the enable signals from one domain to the other.
   
   always @ ( negedge  hs_ck_ip or negedge resetb ) 
     if ( ! resetb )
       retimed_ls_enable_q <= 1'b0;
     else
       retimed_ls_enable_q <= ls_enable_q;

  // Need to use the hs_enable as an async signal here else
  // we might 'miss' the high enable for a single cycle and
  // get a truncated ls phi1 pulse
  always @ ( negedge  ls_ck_ip or posedge hs_enable_q or negedge resetb )
     if ( ! resetb )
       retimed_hs_enable_q <= 1'b0;       
     else if ( hs_enable_q )
       retimed_hs_enable_q <= 1'b1;
     else
       retimed_hs_enable_q <= hs_enable_q;

endmodule // clock_switch_m
