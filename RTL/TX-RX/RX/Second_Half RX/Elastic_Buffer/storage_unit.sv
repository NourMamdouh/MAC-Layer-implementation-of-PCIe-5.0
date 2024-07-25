/*-----------------------------------------------------------------------------
This module is operating in the write domain (recovered clock domain) 
and it represent the storage unit; the data is written in it or read out
according to the enable signals and the addresses given as input
-----------------------------------------------------------------------------*/ 
  
module storage_unit #( 
  BUFFER_WIDTH = 'd13, 
  ADDR_WIDTH = 'd3, 
  DEPTH= 'd8,
  SYMBOL_WIDTH = 'd8,
  COUNT_WIDTH = 'd4
) ( 
  input  logic                         rx_clk, rx_rst,local_clk,
  input  logic  [BUFFER_WIDTH-1 :0]    rx_data,
  input  logic  [ADDR_WIDTH -1:0]      waddr,
  input  logic  [ADDR_WIDTH -1:0]      raddr,
  input  logic                         LTSSM_rst,
  input  logic                         elstc_buff_en,
  input  logic                         write_en,
  input  logic                         empty,
  output logic  [SYMBOL_WIDTH-1 : 0]   output_symbol,
  output logic                         block_type,
  output logic                         valid,
  output logic  [COUNT_WIDTH-1 :0]     count
);

logic [BUFFER_WIDTH-1:0] MEM [DEPTH-1:0];
 
always_ff @(posedge rx_clk or negedge rx_rst) begin
  if (!rx_rst)
    for (int i =0; i <DEPTH; i++)
    MEM[i] <= 'b0;
  else if (LTSSM_rst) begin
      for (int i =0; i <DEPTH; i++)
      MEM[i] <= 'b0;
  end else if (write_en) begin
      MEM [waddr] <= rx_data;
  end	
end

always_comb begin
  {count, block_type, output_symbol} = MEM [raddr];

  if (!empty) begin
    valid = 1'b1;
  end else begin
    valid = 1'b0;
  end
end

endmodule 


