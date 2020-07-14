
module ram_512kx8_m (              
       input [18:0] addr,
       inout [7:0] data,
       input ceb,
       input rnw,
       input oeb
);

  wire       write_pulse;
  wire [7:0] hold_data;
  reg [7:0]  mem [ 512 * 1024:0 ];
  
  integer    idx;
  
  // read operations are combinatorial
  assign data = ( !ceb & rnw & !oeb ) ? mem[ addr ] : 8'bz ;
  assign #10 hold_data = data;

  
  // write operations happen on posedge of ceb or rnw (whichever occurs first)
  always @ ( * )
    if ( !ceb & !rnw ) begin
      mem[ addr ] = hold_data;
      if ( addr == 18'h70000) 
        $display ("Writing to 0x7000");
    end
     
  
endmodule
