module clkctrl(
               input       hsclk_in,
               input       lsclk_in,
               input       rst_b,
               input       hsclk_sel,
               input [1:0] hsclk_div_sel,
               input [1:0] cpuclk_div_sel,
               output      hsclk_selected,
               output      clkout
               );
  
  parameter       HSRUNNING=2'h0, WAITLSE=2'h1,LSRUNNING=2'h3,WAITHSE=2'h2;
  reg [1:0]               state_q, state_d;
  reg                     hsclk_by2_q, hsclk_by4_q, hsclk_by8_q;
  reg                     rst_resync0_qb, rst_resync1_qb;
  reg                     hsclk_sel_q ;

  wire                    lodetect_w;
  wire                    hidetect_w;
  
  wire                    cpuclk_w = (cpuclk_div_sel[1]) ? hsclk_by8_q : (cpuclk_div_sel[0]? hsclk_by8_q: hsclk_by4_q);
  wire                    hsclk_w  = (hsclk_div_sel[1]) ? hsclk_by4_q : (hsclk_div_sel[0]? hsclk_by2_q: hsclk_in);

  assign                  hsclk_selected = (state_q==HSRUNNING) || (state_q==WAITLSE); 

  as_edge_detect as_detect_u ( hsclk_w , lsclk_in, rst_resync1_qb & (state_q==WAITLSE), lodetect_w);
  s_edge_detect   s_detect_u ( hsclk_w , cpuclk_w, rst_resync1_qb & (state_q==WAITHSE), hidetect_w);
  
  always @ ( *  )
    case (state_q )
      HSRUNNING: state_d = (hsclk_sel_q)? HSRUNNING: WAITLSE;
      WAITLSE: state_d = ( lodetect_w ) ? LSRUNNING : WAITLSE;
      LSRUNNING: state_d = (!hsclk_sel_q)? LSRUNNING: WAITHSE;
      WAITHSE: state_d = ( hidetect_w ) ? HSRUNNING : WAITHSE;
    endcase

  assign clkout = (!(state_q==HSRUNNING) | !hsclk_sel_q | cpuclk_w ) &
                  (!(state_q==LSRUNNING) | hsclk_sel_q | lsclk_in);

  // Ensure clock enable changes only in static clock state  - stopping with clock high
  // so latch the select on rising edge of clock
  always @ ( posedge clkout )
      hsclk_sel_q <= hsclk_sel;

  always @ ( negedge hsclk_w )
    if ( !rst_resync1_qb )
      state_q <= LSRUNNING;
    else
      state_q <= state_d;

  always @ ( posedge hsclk_in )
    { rst_resync0_qb, rst_resync1_qb } <= {rst_b, rst_resync0_qb};

  always @ ( posedge hsclk_in  or negedge rst_resync1_qb)
    if ( !rst_resync1_qb )
      hsclk_by2_q <= 1'b0;
    else
      hsclk_by2_q <= !hsclk_by2_q;

  always @ ( posedge hsclk_by2_q  or negedge rst_resync1_qb )
    if ( !rst_resync1_qb )
      hsclk_by4_q <= 1'b0;
    else
      hsclk_by4_q <= !hsclk_by4_q;

  always @ ( posedge hsclk_by4_q  or negedge rst_resync1_qb )
    if ( !rst_resync1_qb )
      hsclk_by8_q <= 1'b0;
    else
      hsclk_by8_q <= !hsclk_by8_q;
  
  
endmodule


