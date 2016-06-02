
module ram_64kx8_m (              
       input [15:0] addr,
       inout [7:0] data,
       input ceb,
       input rnw,
       input oeb
);

reg [7:0] mem [ 64 * 1024:0 ];
integer idx;


// read operations are combinatorial
assign data = ( !ceb & rnw & !oeb ) ? mem[ addr ] : 8'bz ;

// write operations happen on posedge of ceb or rnw (whichever occurs first)
always @ ( posedge ceb or posedge rnw )  
       if ( ceb == 0 || rnw == 0)
          mem[ addr ] = data;       
endmodule
