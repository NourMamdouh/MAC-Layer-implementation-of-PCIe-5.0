module BA_TOP #(
  DATA_WIDTH         = 'd8,
  SYMBOL_COUNT_WIDTH = 'd4, 
  BITS_COUNT_WIDTH   = 'd3
) (
  input  logic                               rx_clk, rx_rst, 
  input  logic                               enable,
  input  logic  [DATA_WIDTH -1 :0]           rx_data,
  input  logic                               Soft_RST_blocks,
  input  logic                               rst_BA,
  output logic                               reg_block_type,
  output logic                               elstc_buff_en, 
  output logic                               error,
  output logic  [SYMBOL_COUNT_WIDTH -1:0]    symbols_count
);
  
logic       flag,flag_en;
logic       cnt_bits_en,cnt_symbols_en;
logic       reint_cnt_bits, reint_cnt_symbols;
logic       rst_flag;
logic [2:0] bits_count;
  
BA_FSM #(
   .DATA_WIDTH(DATA_WIDTH),
   .SYMBOL_COUNT_WIDTH(SYMBOL_COUNT_WIDTH),
   .BITS_COUNT_WIDTH(BITS_COUNT_WIDTH)
   )u0_BA_FSM (
   .rx_clk(rx_clk),
   .rx_rst(rx_rst),
   .enable(enable),
   .flag(flag),
   .rx_data(rx_data),
   .symbols_count(symbols_count),
   .bits_count(bits_count),
   .cnt_bits_en(cnt_bits_en),
   .cnt_symbols_en(cnt_symbols_en),
   .reint_cnt_bits(reint_cnt_bits),
   .reint_cnt_symbols(reint_cnt_symbols),
   .reg_block_type(reg_block_type),
   .elstc_buff_en(elstc_buff_en),
   .Soft_RST_blocks(Soft_RST_blocks),
   .error(error),
   .flag_en(flag_en),
   .rst_flag(rst_flag),
   .rst_BA(rst_BA)
);

BA_flag_genarator #(
   .SYMBOL_COUNT_WIDTH(SYMBOL_COUNT_WIDTH)
   )u0_BA_flag_genarator(
      .rx_clk(rx_clk), 
      .rx_rst(rx_rst),
      .flag_en(flag_en),
      .symbols_count(symbols_count),
      .Soft_RST_blocks(Soft_RST_blocks),
      .flag(flag),
      .rst_flag(rst_flag)
);
  
  
BA_counters #(
   .SYMBOL_COUNT_WIDTH(SYMBOL_COUNT_WIDTH),
   .BITS_COUNT_WIDTH(BITS_COUNT_WIDTH)
   )u0_BA_counters(
      .rx_clk(rx_clk),
      .rx_rst(rx_rst),
      .cnt_bits_en(cnt_bits_en),
      .cnt_symbols_en(cnt_symbols_en),
      .reint_cnt_bits(reint_cnt_bits),
      .reint_cnt_symbols(reint_cnt_symbols),
      .bits_count(bits_count),
      .Soft_RST_blocks(Soft_RST_blocks),
      .symbols_count(symbols_count)
);
   
endmodule
  
