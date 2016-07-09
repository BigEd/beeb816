
module clock_divider24_m(
                         input divider_en,
                         input div4not2,
                         input clkin,
                         input invert,
                         input resetb,
                         output clkout
                         );
   
   reg clkin_div4_q,
       clkin_div2_q;

   wire mux_clk_w = (div4not2)? clkin_div4_q : clkin_div2_q ;
   wire gated_clk_w = clkin & divider_en;
   
   
   assign clkout = ( (divider_en) ? invert ^ mux_clk_w : clkin ) ;
   


   always @ ( posedge gated_clk_w or negedge resetb )
     if ( !resetb)
       clkin_div2_q <= 1'b0;  
     else
       clkin_div2_q <= !clkin_div2_q;

   always @ ( posedge clkin_div2_q or negedge resetb )
     if ( !resetb)
       clkin_div4_q <= 1'b0;  
     else
       clkin_div4_q <= !clkin_div4_q;

   
endmodule // clock_divider24_m
