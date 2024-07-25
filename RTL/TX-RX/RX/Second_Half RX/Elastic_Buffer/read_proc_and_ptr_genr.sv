/*-----------------------------------------------------------------------------
This module is operating in the read clock domain (local clock) and has the following functions:
1- it calculate the binary and gray encoded read pointers 
2- deassert the valid signal whenever the buffer is empty 
-----------------------------------------------------------------------------*/
   
module read_proc_and_ptr_genr #( 
  ADDR_WIDTH = 2'b11 , 
  PTR_WIDTH = 3'b100 
)(
  input   logic                      local_clk,
  input   logic                      local_rst,
  input   logic  [PTR_WIDTH -1 :0]   r_gray_wptr,
  input   logic                      higher_gen_en,
  input   logic                      LTSSM_rst,
  output  logic                      empty,
  output  logic  [PTR_WIDTH -1:0]    gray_rptr,
  output  logic  [ADDR_WIDTH -1:0]   raddr
);

logic [PTR_WIDTH -1:0] rptr;  

assign empty = ((gray_rptr == r_gray_wptr));

always @ (posedge local_clk or negedge local_rst) begin
  if(!local_rst) begin
    rptr <= 'b0;
    raddr <= 'b0;
  end else if (LTSSM_rst) begin
    rptr <= 'b0;
    raddr <= 'b0;
  end else if (!empty && higher_gen_en) begin
    raddr <= raddr +1'b1;
    rptr <= rptr +1'b1;          
  end
end
                  
  
always_comb begin 
  case (rptr)
  4'b0000: gray_rptr <= 4'b0000 ;
  4'b0001: gray_rptr <= 4'b0001 ;
  4'b0010: gray_rptr <= 4'b0011 ;
  4'b0011: gray_rptr <= 4'b0010 ;
  4'b0100: gray_rptr <= 4'b0110 ;
  4'b0101: gray_rptr <= 4'b0111 ;
  4'b0110: gray_rptr <= 4'b0101 ;
  4'b0111: gray_rptr <= 4'b0100 ;
  4'b1000: gray_rptr <= 4'b1100 ;
  4'b1001: gray_rptr <= 4'b1101 ;
  4'b1010: gray_rptr <= 4'b1111 ;
  4'b1011: gray_rptr <= 4'b1110 ;
  4'b1100: gray_rptr <= 4'b1010 ;
  4'b1101: gray_rptr <= 4'b1011 ;
  4'b1110: gray_rptr <= 4'b1001 ;
  4'b1111: gray_rptr <= 4'b1000 ;
  endcase
end
   
endmodule
