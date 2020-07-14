
module ram_64kx8_m (              
       input [15:0] addr,
       inout [7:0] data,
       input ceb,
       input rnw,
       input oeb
);

reg [7:0] mem [ 64 * 1024:0 ];
integer idx;
wire [7:0] hold_data;
  

// read operations are combinatorial
assign data = ( !ceb & rnw & !oeb ) ? mem[ addr ] : 8'bz ;
assign #10 hold_data = data;
  
always @ ( * )  
       if ( ceb == 0 && rnw == 0)
          mem[ addr ] = hold_data;       
endmodule
