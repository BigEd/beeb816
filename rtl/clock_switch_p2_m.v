// clock_switch_p2_m.v
//
//
// options:
//
// if CLOCK_SWITCH_USE_LATCH_D is set then the enabling on the HS clock is done using latches instead
// of FFs. The latches are open on the low state of the clock and are used to gate the
// next rising edge of the clock.
//
// Enabling on the LS clock is always done via a FF, because it's easy to compute the HIMEM state in
// half the LS clock period.
//
// Switch stops the clock in the PHI2 state
//

module clock_switch_p2_m (
                       input hs_ck_ip,
                       input ls_ck_ip,
                       input select_hs_ip,
                       input resetb,
                       output selected_hs_op,
                       output selected_ls_op,                       
                       output ck_op
                       );

   reg hs_enable_q,
       ls_enable_q;
   
   reg selected_ls_q,
       selected_hs_q;   

   wire retimed_hs_enable_w;
   wire retimed_ls_enable_w;   
   

   wire ck_w = (hs_ck_ip & hs_enable_q ) | (ls_ck_ip & ls_enable_q);   
   assign ck_op = ck_w;

   assign selected_ls_op = selected_ls_q;
   assign selected_hs_op = selected_hs_q;
   
   // The 'status' returned needs to be edge triggered for use in a feedback loop
   always @ (posedge ls_ck_ip or negedge resetb) 
     if ( ! resetb )
       selected_ls_q <= 1'b0;
     else
       selected_ls_q <= !select_hs_ip & !retimed_hs_enable_w;

   always @ (posedge hs_ck_ip or negedge resetb) 
     if ( ! resetb )
       selected_hs_q <= 1'b0;
     else
       selected_hs_q <= select_hs_ip & !retimed_ls_enable_w;

   always @ ( negedge hs_ck_ip or negedge resetb )
     if ( ! resetb )
       hs_enable_q <= 1'b0;   
     else 
       hs_enable_q <= select_hs_ip & !retimed_ls_enable_w;

   always @ ( negedge ls_ck_ip or negedge resetb )
     if ( ! resetb )
       ls_enable_q <= 1'b1;   
     else 
       ls_enable_q <= !select_hs_ip & !retimed_hs_enable_w;

   `define PIPE_SZ 2
   reg [`PIPE_SZ-1:0]  pipe_retime_ls_enable_q;
   reg [`PIPE_SZ-1:0]  pipe_retime_hs_enable_q;

   assign retimed_ls_enable_w = pipe_retime_ls_enable_q[0];   
   assign retimed_hs_enable_w = pipe_retime_hs_enable_q[0];                               
   
   always @ ( negedge  hs_ck_ip or posedge ls_enable_q or negedge resetb ) 
     if ( ! resetb )
       pipe_retime_ls_enable_q <= {`PIPE_SZ{1'b1}};
     else if ( ls_enable_q )
       pipe_retime_ls_enable_q <= {`PIPE_SZ{1'b1}};
     else
       pipe_retime_ls_enable_q <= {1'b0, pipe_retime_ls_enable_q[`PIPE_SZ-1:1]};          
   
   always @ ( negedge  ls_ck_ip or posedge hs_enable_q or negedge resetb ) 
     if ( ! resetb )
       pipe_retime_hs_enable_q <= {`PIPE_SZ{1'b0}};
     else if ( hs_enable_q )
       pipe_retime_hs_enable_q <= {`PIPE_SZ{1'b1}};
     else
       pipe_retime_hs_enable_q <= {1'b0, pipe_retime_hs_enable_q[`PIPE_SZ-1:1]};          
   

endmodule // clock_switch_m
