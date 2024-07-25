/*-----------------------------------------------------------------------------
This module is operating in the write domain (recovered clock domain); its functions are:
1- Generate the write pointer (binary and gray encoded)
2- Compare the read and write pointers to check if a skip need to be deleted 
 -----------------------------------------------------------------------------*/          

module wptr_generation #(
  THRESHOLD = 'd2, 
  PTR_WIDTH = 3'b100 , 
  ADDR_WIDTH =2'b11
)(
  input  logic                     rx_clk, rx_rst,
  input  logic                     write_en,
  input  logic                     LTSSM_rst, 
  input  logic [PTR_WIDTH -1 :0]   w_gray_rptr,
  input  logic [PTR_WIDTH -1 :0]   delayed_wptr,
  output logic [ADDR_WIDTH-1 :0]   waddr,
  output logic                     SKP_remv_rqst,
  output logic [PTR_WIDTH -1:0]    gray_wptr,
  output logic                     full,
  output logic [PTR_WIDTH -1:0]    wptr
);

logic  [PTR_WIDTH -1:0]  rptr; 
logic  [2:0]             ptr_diff;
  
always_comb begin
  if (delayed_wptr >= rptr) begin
    ptr_diff = delayed_wptr - rptr;
  end else begin 
    ptr_diff = delayed_wptr + 4'b1111 - rptr;
  end
end

//compare the read and write pointers 
assign SKP_remv_rqst =  (ptr_diff >= THRESHOLD)? 1'b1: 1'b0;

//calculation of waddr and wptr 
always_ff @(posedge rx_clk or negedge rx_rst) begin
  if (!rx_rst) begin 
    waddr <= 4'b0;
    wptr <= 5'b0;
  end else if (LTSSM_rst) begin
    waddr <= 4'b0;
    wptr <= 5'b0; 
  end else if (write_en) begin
    waddr <= waddr +1'b1;
    wptr <= wptr +1'b1;
  end
end

//binary to gray encoded conversion of wptr 
always_comb begin
  case (wptr)
  4'b0000: gray_wptr <= 4'b0000 ;
  4'b0001: gray_wptr <= 4'b0001 ;
  4'b0010: gray_wptr <= 4'b0011 ;
  4'b0011: gray_wptr <= 4'b0010 ;
  4'b0100: gray_wptr <= 4'b0110 ;
  4'b0101: gray_wptr <= 4'b0111 ;
  4'b0110: gray_wptr <= 4'b0101 ;
  4'b0111: gray_wptr <= 4'b0100 ;
  4'b1000: gray_wptr <= 4'b1100 ;
  4'b1001: gray_wptr <= 4'b1101 ;
  4'b1010: gray_wptr <= 4'b1111 ;
  4'b1011: gray_wptr <= 4'b1110 ;
  4'b1100: gray_wptr <= 4'b1010 ;
  4'b1101: gray_wptr <= 4'b1011 ;
  4'b1110: gray_wptr <= 4'b1001 ;
  4'b1111: gray_wptr <= 4'b1000 ;
  endcase
end

// gray encoded to binary conversion
always_comb begin
  case(w_gray_rptr)
  4'b0000: rptr <= 4'b0000 ;
  4'b0001: rptr <= 4'b0001 ;
  4'b0011: rptr <= 4'b0010 ;
  4'b0010: rptr <= 4'b0011 ;
  4'b0110: rptr <= 4'b0100 ;
  4'b0111: rptr <= 4'b0101 ;
  4'b0101: rptr <= 4'b0110 ;
  4'b0100: rptr <= 4'b0111 ;
  4'b1100: rptr <= 4'b1000 ;
  4'b1101: rptr <= 4'b1001 ;
  4'b1111: rptr <= 4'b1010 ;
  4'b1110: rptr <= 4'b1011 ;
  4'b1010: rptr <= 4'b1100 ;
  4'b1011: rptr <= 4'b1101 ;
  4'b1001: rptr <= 4'b1110 ;
  4'b1000: rptr <= 4'b1111 ;  
  endcase
end

assign full =( (rptr[3:0] == wptr[3:0]) && (rptr[4] != wptr[4] )) ;

endmodule

