
module ram_512kx8_m (              
       input [18:0] addr,
       inout [7:0] data,
       input ceb,
       input rnw,
       input oeb
);

  wire       write_pulse;
  
  reg [7:0]  mem [ 512 * 1024:0 ];
  
  integer    idx;
  
  // read operations are combinatorial
  assign data = ( !ceb & rnw & !oeb ) ? mem[ addr ] : 8'bz ;
  
  // write operations happen on posedge of ceb or rnw (whichever occurs first)
  always @ ( * )
    if ( !ceb & !rnw )
      mem[ addr ] = data;
  
endmodule
