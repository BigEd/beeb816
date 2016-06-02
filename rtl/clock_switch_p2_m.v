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
   
   reg selected_ls_q;

   wire retimed_hs_enable_w;
   wire retimed_ls_enable_w;   
   

`ifdef CLOCK_SWITCH_USE_LATCH_D
   reg selected_hs_q;
`endif
   

   wire ck_w = (hs_ck_ip & hs_enable_q ) | (ls_ck_ip & ls_enable_q);   
   assign ck_op = ck_w;


   assign selected_ls_op =  selected_ls_q;    
   // The 'status' returned needs to be edge triggered for use in a feedback loop
   always @ (posedge ls_ck_ip or negedge resetb) 
     if ( ! resetb )
       selected_ls_q <= 1'b0;
     else
       selected_ls_q <= !select_hs_ip & !retimed_hs_enable_w;
   
   
   // Create the clock enabling state with latches or flops as required
`ifdef CLOCK_SWITCH_USE_LATCH_D
   assign selected_hs_op = selected_hs_q;
   
   always @ (hs_ck_ip or resetb or select_hs_ip or retimed_ls_enable_w )
     if ( ! resetb )
       hs_enable_q <= 1'b0;   
     else if ( hs_ck_ip == 1'b0 )
       hs_enable_q <= select_hs_ip & !retimed_ls_enable_w;

   // The 'status' returned needs to be edge triggered for use in a feedback loop
   always @ (posedge hs_ck_ip or negedge resetb) 
     if ( ! resetb )
       selected_hs_q <= 1'b0;
     else
       selected_hs_q <= hs_enable_q & !retimed_ls_enable_w;
   
`else 
   assign selected_hs_op = hs_enable_q;

   always @ (negedge hs_ck_ip or negedge resetb )
     if ( ! resetb )
       hs_enable_q <= 1'b0;   
     else
       hs_enable_q <= select_hs_ip & !retimed_ls_enable_w;

`endif // !`ifdef CLOCK_SWITCH_USE_LATCH_D
   
   always @ (negedge ls_ck_ip or negedge resetb )
     if ( ! resetb )
       ls_enable_q <= 1'b1;   
     else
       ls_enable_q <= !select_hs_ip & !retimed_hs_enable_w;

`ifdef CLOCK_SWITCH_PIPELINED_RETIME_D
   // Pipe depth needs to be at least 3
   `define PIPE_SZ 2
   reg [`PIPE_SZ-1:0]  pipe_retime_ls_enable_q;
   reg [`PIPE_SZ-1:0]  pipe_retime_hs_enable_q;

   assign retimed_ls_enable_w = pipe_retime_ls_enable_q[0];   
   assign retimed_hs_enable_w = pipe_retime_hs_enable_q[0];                               
   
   always @ ( negedge  hs_ck_ip or posedge ls_enable_q or negedge resetb ) 
     if ( ! resetb )
       pipe_retime_ls_enable_q <= {`PIPE_SZ{1'b0}};
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
   
   
`else // !`ifdef CLOCK_SWITCH_PIPELINED_RETIME_D
   reg                 retimed_hs_enable_q;   
   reg                 retimed_ls_enable_q;   
   
   assign retimed_ls_enable_w = retimed_ls_enable_q;   
   assign retimed_hs_enable_w = retimed_hs_enable_q;                               
   
   // Retime the enable signals from one domain to the other.   
   always @ ( negedge  hs_ck_ip or posedge ls_enable_q or negedge resetb ) 
     if ( ! resetb )
       retimed_ls_enable_q <= 1'b0;
     else if ( ls_enable_q )
       retimed_ls_enable_q <= 1'b1;
     else
       retimed_ls_enable_q <= 1'b0;

  // Need to use the hs_enable as an async signal here else
  // we might 'miss' the high enable for a single cycle and
  // get a truncated ls phi1 pulse
  always @ ( negedge  ls_ck_ip or posedge hs_enable_q or negedge resetb )
    if ( !resetb)
      retimed_hs_enable_q <= 1'b0;
    else if ( hs_enable_q )
      retimed_hs_enable_q <= 1'b1;
    else
      retimed_hs_enable_q <= 1'b0;
`endif // !`ifdef CLOCK_SWITCH_PIPELINED_RETIME_D
   

endmodule // clock_switch_m
