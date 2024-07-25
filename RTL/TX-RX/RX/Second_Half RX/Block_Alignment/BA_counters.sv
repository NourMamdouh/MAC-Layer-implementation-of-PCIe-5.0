/*-----------------------------------------------------------------------------
This module is operating in the recovered clock domain and has the following functions:
1-  a bit level counter, has count eight times and then reinitialize by itself or receive
    a reint signal from the BA_FSM (used in the case of sync header, as 2 counts are needed).
2-  a symbol level counter that keeps track of the symbol count in the block, the counter is incremented 
    each time the bit counts is eight.
-----------------------------------------------------------------------------*/
module BA_counters #(
  SYMBOL_COUNT_WIDTH = 'd4, 
  BITS_COUNT_WIDTH = 'd3
) (
  input  logic                              rx_clk, rx_rst, 
  input  logic                              cnt_bits_en, 
  input  logic                              cnt_symbols_en,
  input  logic                              reint_cnt_bits,
  input  logic                              reint_cnt_symbols,
  input  logic                              Soft_RST_blocks,
  output logic  [BITS_COUNT_WIDTH -1 :0]    bits_count,
  output logic  [SYMBOL_COUNT_WIDTH -1 :0]  symbols_count
);

localparam last_bit = 3'd7;
logic  cnt_symbols_en_int;

assign cnt_symbols_en_int = (bits_count == last_bit);

//counter bit level
always_ff @(posedge rx_clk or negedge rx_rst) 
begin
  if (!rx_rst) begin
    bits_count <= 'b0;
  end 
  else if (Soft_RST_blocks) begin
    bits_count <= 'b0;
  end
  else if (cnt_bits_en) begin
    if (reint_cnt_bits)
      bits_count <= 'b0;
    else
	    bits_count <= bits_count + 1'b1;
  end      
end

// counter symbols  
always_ff @(posedge rx_clk or negedge rx_rst) 
begin
  if (!rx_rst)begin
    symbols_count <= 'b0;
  end
  else if (Soft_RST_blocks) begin
    symbols_count <= 'b0;
  end
  else if (reint_cnt_symbols)
    symbols_count <= 'b0; 
  else if (cnt_symbols_en || cnt_symbols_en_int)
	  symbols_count <= symbols_count + 1'b1;
end 

endmodule 
