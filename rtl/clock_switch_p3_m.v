// clock_switch_p3_m.v
//
// Assume that the select_hs_ip input is asserted during the low phase of the clock
//
// Need to _immediately_ prevent the output clock from going high with the next high phase
//
// Switch to the alternate clock when the original has been stopped 
//
//

module clock_switch_p3_m (
                       input hs_ck_ip,
                       input ls_ck_ip,
                       input select_hs_ip,
                       input resetb,
                       output selected_hs_op,
                       output selected_ls_op,                       
                       output ck_op
                       );

   `define HS_PIPE_SZ 3
   `define LS_PIPE_SZ 2
  
   reg [`LS_PIPE_SZ-1:0]  pipe_retime_ls_enable_q;
   reg [`HS_PIPE_SZ-1:0]  pipe_retime_hs_enable_q;
   
   reg                 hs_enable_lat_q;
   reg                 ls_enable_lat_q;   

   wire                retimed_hs_enable_w;
   wire                retimed_ls_enable_w;

   wire                hs_selected_w = pipe_retime_hs_enable_q[0]  & hs_enable_lat_q;
   wire                ls_selected_w = pipe_retime_ls_enable_q[0]  & ls_enable_lat_q;   
   
                
   
   assign ck_op = (hs_ck_ip &  hs_selected_w ) | (ls_ck_ip & ls_selected_w );

   assign selected_ls_op =  pipe_retime_ls_enable_q[0];
   assign selected_hs_op =  pipe_retime_hs_enable_q[0];
   
   // Respond immediately to the select_hs_ip to be able to switch the clock OFF in low phase               
   always @ ( hs_ck_ip or resetb or select_hs_ip )
     if ( !resetb )
       hs_enable_lat_q <= 1'b0;
     else if ( !hs_ck_ip )
       hs_enable_lat_q <= select_hs_ip;

   always @ ( ls_ck_ip or resetb or select_hs_ip )
     if ( !resetb )
       ls_enable_lat_q <= 1'b1;
     else if ( !ls_ck_ip )
       ls_enable_lat_q <= !select_hs_ip;

   
   // Retime the enable from the LS clock combined with the new HS clock enable - can't enable HS 'til LS is disabled
   always @ ( negedge  hs_ck_ip or negedge resetb ) 
     if ( ! resetb )
       pipe_retime_hs_enable_q <= {`HS_PIPE_SZ{1'b0}};
     else
       pipe_retime_hs_enable_q <= { ! pipe_retime_ls_enable_q[0] & hs_enable_lat_q , pipe_retime_hs_enable_q[`HS_PIPE_SZ-1:1]};          
   
   // Retime the enable from the HS clock combined with the new LS clock enable - can't enable LS 'til HS is disabled          
   always @ ( negedge  ls_ck_ip or negedge resetb ) 
     if ( ! resetb )
       pipe_retime_ls_enable_q <= {`LS_PIPE_SZ{1'b1}};
     else
       pipe_retime_ls_enable_q <= {! pipe_retime_hs_enable_q[0] & ls_enable_lat_q, pipe_retime_ls_enable_q[`LS_PIPE_SZ-1:1]};          
      
endmodule // clock_switch_m
