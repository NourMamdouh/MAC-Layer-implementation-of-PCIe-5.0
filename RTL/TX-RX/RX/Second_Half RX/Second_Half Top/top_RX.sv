module top_RX #(
  serdes           = 0, 
  CNT_WIDTH        ='d4,
  DATA_WIDTH       ='d256,
  MAX_LANES        ='d32,
  SYNC_WIDTH       ='d2,
  BUFFER_WIDTH     ='d13,
  PTR_WIDTH        ='d4,
  ADDR_WIDTH       ='d3,
  DEPTH            ='d8,
  THRESHOLD        ='d2,
  SYMBOL_WIDTH     ='d8,
  BITS_COUNT_WIDTH ='d3
)(  
  input  logic                      local_clk, local_rst,
  input  logic                      rx_clk, rx_rst,
  input  logic [0:DATA_WIDTH -1]    rx_data,
  input  logic                      GEN,
  input  logic                      enable,
  input  logic [0:MAX_LANES-1]      PIPE_d_K,
  input  logic                      enable_ltssm,
  input  logic [0:MAX_LANES -1]     RX_Data_Valid,
  input  logic [0:MAX_LANES -1]     RXValid,
  input  logic [0:MAX_LANES -1]     RX_Start_Block,
  input  logic [0:SYNC_WIDTH-1]     RX_SYNC_Header [0:MAX_LANES-1], 
  input  logic                      Soft_RST_blocks,
  input  logic                      PIPE_CNT_rst,
  input  logic                      type_IDL_TS,
  input  logic                      rst_BA,
  output logic [0: DATA_WIDTH -1]   Des_Data_Out,
  output logic [0:MAX_LANES -1]     deskewed_RX_valid,
  output logic [0:MAX_LANES -1]     deskewed_RX_sync,
  output logic                      valid_deskew,
  output logic [CNT_WIDTH-1:0]      output_count [0:MAX_LANES-1],
  output logic [0:MAX_LANES -1]     BA_error,
  output logic                      Deskew_error
);


logic [0:DATA_WIDTH -1]     deskewed_RX_Data ;
logic [0:MAX_LANES -1]      valid_data;
logic [0:MAX_LANES -1]      valid;
logic [CNT_WIDTH -1:0]      count             [0:MAX_LANES -1];
logic [2:0]                 delay_select      [0:MAX_LANES -1];
logic [CNT_WIDTH -1:0]      deskewed_RX_count [0:MAX_LANES -1];
logic [CNT_WIDTH -1:0]      PIPE_count        [0:MAX_LANES -1];
logic [SYMBOL_WIDTH-1:0]    output_symbol     [0:MAX_LANES -1];
logic [CNT_WIDTH -1:0]      symbols_count     [0:MAX_LANES -1];
logic [0:MAX_LANES -1]      block_type;
logic [0:MAX_LANES -1]      advance ; 
logic [0:MAX_LANES -1]      LFSR_RST;
logic [0:DATA_WIDTH -1]     LFSR_Out_8;
logic [0:DATA_WIDTH -1]     LFSR_Out_8_gen3;  
logic [0:MAX_LANES -1]      descramblingEnable ;
logic [0:MAX_LANES -1]      reg_block_type;
logic [0:MAX_LANES -1]      elstc_buff_en;
logic [0:MAX_LANES -1]      full;
logic [0:DATA_WIDTH -1]     Descrambler_input;


assign Descrambler_input = (GEN == 1)?deskewed_RX_Data:rx_data;
assign output_count = ((GEN == 1) && (serdes == 1)) ? deskewed_RX_count : PIPE_count;

generate
  genvar i;
  if(serdes) begin    
    elstc_buff_TOP #(
      .BUFFER_WIDTH(BUFFER_WIDTH), 
      .DEPTH       (DEPTH),    
      .PTR_WIDTH   (PTR_WIDTH), 
      .ADDR_WIDTH  (ADDR_WIDTH), 
      .THRESHOLD   (THRESHOLD),
      .SYMBOL_WIDTH(SYMBOL_WIDTH), 
      .COUNT_WIDTH (CNT_WIDTH) 
    ) u0_elstc_buff_TOP(
      .rx_clk(rx_clk), 
      .rx_rst(rx_rst),
      .local_clk(local_clk), 
      .local_rst(local_rst),
      .rx_data({symbols_count[0],reg_block_type[0],rx_data[0:7]}),
      .LTSSM_rst(Soft_RST_blocks),
      .elstc_buff_en(elstc_buff_en[0]),
      .higher_gen_en(enable),
      .output_symbol(output_symbol[0]),
      .block_type(block_type[0]),
      .buff_count(count[0]),
      .valid(valid[0]), 
      .full(full[0]) 
    ); 

    BA_TOP #(
      .DATA_WIDTH(SYMBOL_WIDTH),         
      .SYMBOL_COUNT_WIDTH(CNT_WIDTH),
      .BITS_COUNT_WIDTH(BITS_COUNT_WIDTH)   
    )u0_BA_TOP (
      .rx_clk(rx_clk), 
      .rx_rst(rx_rst), 
      .enable(enable),
      .rx_data(rx_data[0:7]),
      .reg_block_type(reg_block_type[0]), 
      .elstc_buff_en(elstc_buff_en[0]), 
      .error(BA_error[0]),
      .Soft_RST_blocks(Soft_RST_blocks),  
      .symbols_count(symbols_count[0]),
      .rst_BA(rst_BA)
    );

    LFSR_8_gen3 lfsr_8_gen3(
      .seed(24'hFFFFFF), 
      .LFSR_RST(LFSR_RST[0]), 
      .rst(local_rst), 
      .back_pressure(!(valid_data[0] && deskewed_RX_valid[0])),
      .TX_CLK(local_clk), 
      .Data_Out(LFSR_Out_8_gen3[0:7]),
      .EN(enable),
      .advance(advance[0]),
      .GEN(GEN)
    );

    PIPE_Counter  #(
      .CNT_WIDTH(CNT_WIDTH) 
    ) PIPE_Counter_1(
	    .CLK(local_clk),
      .Hard_RST_L(local_rst),
      .PIPE_CNT_rst(PIPE_CNT_rst),
      .CNT_set(type_IDL_TS),
	    .i_CNT_EN(RX_Data_Valid[0] || RXValid[0]),		// to enable counting up by one when set
	    .o_CNT(PIPE_count[0])			//current count
    );

    LFSR_8  LF1(
      .rst(local_rst),
      .TX_CLK(local_clk),
      .LFSR_RST(LFSR_RST[0]),
      .GEN(GEN),
      .advance(advance[0]),
      .EN(RXValid[0]),
      .Data_Out(LFSR_Out_8[0:7])
    );

    Descrambler_Controler descrambler_control( 
      .CLK(local_clk),
      .RST_L(local_rst),
      .SyncHeader(deskewed_RX_sync[0]), 
      .PIPE_Data(Descrambler_input[0:7]), 
      .GEN(GEN),
	    .SC_LFSR_RST(LFSR_RST[0]),
	    .count(deskewed_RX_count[0]), 
	    .advance(advance[0]),
      .RX_Data_Valid(RX_Data_Valid[0]),
	    .descramblingEnable(descramblingEnable[0])
    );
  
	  Descrambler descrambler(
	    .RX_CLK(local_clk), 
	    .rst(local_rst),
	    .PIPE_SyncHeader(deskewed_RX_sync[0]),
	    .seed(24'hFFFFFF), 
	    .PIPE_Data(Descrambler_input[0:7]), 
      .PIPE_d_K(PIPE_d_K[0]), 
      .GEN(GEN),
	    .count(deskewed_RX_count[0]),
	    .LFSR_RST(LFSR_RST[0]),   
      .descramblingEnable(descramblingEnable[0]),   
      .LFSR_Out_8(LFSR_Out_8[0:7]),
      .LFSR_Out_8_gen3(LFSR_Out_8_gen3[0:7]),
	    .Des_Data_Out(Des_Data_Out[0:7])
    );

    lane_deskew lane_deskew (
      .skewed_RX_Data(output_symbol[0]), 
      .EN_LTSSM(enable_ltssm && 0), //****
      .valid_buffer(valid[0]),
      .GEN(GEN),
      .rst(local_rst), 
      .RX_CLK(local_clk), 
      .deskewed_RX_Data(deskewed_RX_Data[0 : 7]), 
      .count(count[0]),
      .block_type(block_type[0]),
      .deskewed_RX_count(deskewed_RX_count[0]),
      .deskewed_RX_sync(deskewed_RX_sync[0]),
      .deskewed_RX_valid(deskewed_RX_valid[0]),
      .Soft_RST_blocks(Soft_RST_blocks),
      .delay_select(delay_select[0]) 
    );

    for( i = 1 ; i < 32 ; i = i + 1)begin: sc_Gen3
    elstc_buff_TOP #(
      .BUFFER_WIDTH(BUFFER_WIDTH), 
      .DEPTH       (DEPTH),    
      .PTR_WIDTH   (PTR_WIDTH), 
      .ADDR_WIDTH  (ADDR_WIDTH), 
      .THRESHOLD   (THRESHOLD),
      .SYMBOL_WIDTH(SYMBOL_WIDTH), 
      .COUNT_WIDTH (CNT_WIDTH) 
    ) u0_elstc_buff_TOP(
      .rx_clk(rx_clk), 
      .rx_rst(rx_rst),
      .local_clk(local_clk), 
      .local_rst(local_rst),
      .rx_data({symbols_count[i],reg_block_type[i],rx_data[i*8 : ((i+1)*8)-1]}),
      .elstc_buff_en(elstc_buff_en[i]),
      .higher_gen_en(enable),
      .output_symbol(output_symbol[i]),
      .block_type(block_type[i]),
      .buff_count(count[i]),
      .valid(valid[i]), 
      .LTSSM_rst(Soft_RST_blocks),
      .full(full[i]) 
    ); 

    PIPE_Counter  #(
      .CNT_WIDTH(CNT_WIDTH) 
    ) PIPE_Counter_1(
	    .CLK(local_clk),
      .Hard_RST_L(local_rst),
      .PIPE_CNT_rst(PIPE_CNT_rst),
      .CNT_set(type_IDL_TS),
	    .i_CNT_EN(RX_Data_Valid[i] || RXValid[i]),		// to enable counting up by one when set
	    .o_CNT(PIPE_count[i])			//current count
    );

    BA_TOP #(
      .DATA_WIDTH(SYMBOL_WIDTH),         
      .SYMBOL_COUNT_WIDTH(CNT_WIDTH),
      .BITS_COUNT_WIDTH(BITS_COUNT_WIDTH)   
    )u0_BA_TOP (
      .rx_clk(rx_clk), 
      .rx_rst(rx_rst), 
      .enable(enable),
      .rx_data(rx_data[i*8 : ((i+1)*8)-1]),
      .reg_block_type(reg_block_type[i]), 
      .elstc_buff_en(elstc_buff_en[i]), 
      .error(BA_error[i]),
      .Soft_RST_blocks(Soft_RST_blocks),
      .symbols_count(symbols_count[i]),
      .rst_BA(rst_BA)
    );

    LFSR_8_gen3 lfsr_8_gen3(
      .seed(24'hFFFFFF),   
      .LFSR_RST(LFSR_RST[i]), 
      .rst(local_rst), 
      .back_pressure(!(valid_data[i] && deskewed_RX_valid[i])),
      .TX_CLK(local_clk), 
      .Data_Out(LFSR_Out_8_gen3[i*8 : ((i+1)*8)-1]),
      .EN(enable),
      .advance(advance[i]),
      .GEN(GEN)
    );

    LFSR_8  LF1(
      .rst(local_rst),
      .TX_CLK(local_clk),
      .LFSR_RST(LFSR_RST[i]),
      .GEN(GEN),
      .advance(advance[i]),
      .EN(RXValid[i]),
      .Data_Out(LFSR_Out_8[i*8 : ((i+1)*8)-1])
    );

    Descrambler_Controler descrambler_control( 
      .CLK(local_clk),
      .RST_L(local_rst),
      .SyncHeader(deskewed_RX_sync[i]), 
      .PIPE_Data(Descrambler_input[i*8 : ((i+1)*8)-1]), 
      .GEN(GEN),
	    .SC_LFSR_RST(LFSR_RST[i]),
	    .count(deskewed_RX_count[i]), 
	    .advance(advance[i]),
      .RX_Data_Valid(RX_Data_Valid[i]),
	    .descramblingEnable(descramblingEnable[i])
    );
  
	  Descrambler descrambler(
	    .RX_CLK(local_clk), 
	    .rst(local_rst),
	    .PIPE_SyncHeader(deskewed_RX_sync[i]),
	    .seed(24'hFFFFFF), 
	    .PIPE_Data(Descrambler_input[i*8 : ((i+1)*8)-1]), 
      .PIPE_d_K(PIPE_d_K[i]), 
      .GEN(GEN),
	    .count(deskewed_RX_count[i]),
	    .LFSR_RST(LFSR_RST[i]),   
      .descramblingEnable(descramblingEnable[i]),   
      .LFSR_Out_8(LFSR_Out_8[i*8 : ((i+1)*8)-1]),
      .LFSR_Out_8_gen3(LFSR_Out_8_gen3[i*8 : ((i+1)*8)-1]),
	    .Des_Data_Out(Des_Data_Out[i*8 : ((i+1)*8)-1])
    );

    lane_deskew lane_deskew (
      .skewed_RX_Data(output_symbol[i]), 
      .EN_LTSSM(enable_ltssm && 0 ), //****
      .valid_buffer(valid[i]),
      .GEN(GEN),
      .rst(local_rst), 
      .RX_CLK(local_clk), 
      .deskewed_RX_Data(deskewed_RX_Data[i*8 : ((i+1)*8)-1]), 
      .count(count[i]),
      .block_type(block_type[i]),
      .deskewed_RX_count(deskewed_RX_count[i]),
      .deskewed_RX_sync(deskewed_RX_sync[i]),
      .deskewed_RX_valid(deskewed_RX_valid[i]),
      .Soft_RST_blocks(Soft_RST_blocks),
      .delay_select(delay_select[i]) 
    );
    end

    lane_control lane_control (
      .skewed_RX_Data_1(output_symbol), 
      .rst(local_rst), 
      .RX_CLK(local_clk), 
      .Deskew_error(Deskew_error),
      .EN_LTSSM(enable_ltssm && 0 ), //****
      .valid_deskew(valid_deskew), 
      .valid_data(valid_data), 
      .block_type(block_type),
      .Soft_RST_blocks(Soft_RST_blocks),
      .delay_select(delay_select)
    );
  end
  else begin
    LFSR_8_gen3 lfsr_8_gen3(
      .seed(24'hFFFFFF), 
      .LFSR_RST(LFSR_RST[0]), 
      .rst(local_rst), 
      .back_pressure(!RX_Data_Valid[0]),
      .TX_CLK(local_clk), 
      .Data_Out(LFSR_Out_8_gen3[0:7]),
      .EN(enable),
      .advance(advance[0]),
      .GEN(GEN)
    );

    LFSR_8  LF1(
      .rst(local_rst),
      .TX_CLK(local_clk),
      .LFSR_RST(LFSR_RST[0]),
      .GEN(GEN),
      .advance(advance[0]),
      .EN(RXValid[0]),
      .Data_Out(LFSR_Out_8[0:7])
    );

    Descrambler_Controler descrambler_control( 
      .CLK(local_clk),
      .RST_L(local_rst),
      .SyncHeader(deskewed_RX_sync[0]), 
      .PIPE_Data(rx_data[0:7]), 
      .GEN(GEN),
	    .SC_LFSR_RST(LFSR_RST[0]),
	    .count(PIPE_count[0]), 
	    .advance(advance[0]),
      .RX_Data_Valid(RX_Data_Valid[0]),
	    .descramblingEnable(descramblingEnable[0])
    );
  
	  Descrambler descrambler(
	    .RX_CLK(local_clk), 
	    .rst(local_rst),
	    .PIPE_SyncHeader(deskewed_RX_sync[0]),
	    .seed(24'hFFFFFF), 
	    .PIPE_Data(rx_data[0:7]), 
      .PIPE_d_K(PIPE_d_K[0]), 
      .GEN(GEN),
	    .count(PIPE_count[0]),
	    .LFSR_RST(LFSR_RST[0]),   
      .descramblingEnable(descramblingEnable[0]),   
      .LFSR_Out_8(LFSR_Out_8[0:7]),
      .LFSR_Out_8_gen3(LFSR_Out_8_gen3[0:7]),
	    .Des_Data_Out(Des_Data_Out[0:7])
    );

    PIPE_Counter_pipe  #(
      .CNT_WIDTH(CNT_WIDTH) 
    ) PIPE_Counter_1 (
	    .CLK(local_clk),
      .Hard_RST_L(local_rst),
      .PIPE_CNT_rst(PIPE_CNT_rst),
      .CNT_set(type_IDL_TS),
	    .i_CNT_EN((RX_Data_Valid[0] && (GEN == 1)) || (RXValid[0] && (GEN == 'd0))),		// to enable counting up by one when set
	    .RX_Start_Block(RX_Start_Block[0]),
      .o_CNT(PIPE_count[0])			//current count
    );

    Block_Type_Logic  Block_Type_Logic_1 (
      .CLK(local_clk) , 
      .RST_L(local_rst),
      .RX_Sync_Header(RX_SYNC_Header[0]),
      .RX_Start_Block(RX_Start_Block[0]),
      .Block_Type(deskewed_RX_sync[0])
    );


    for( i = 1 ; i < 32 ; i = i + 1)begin: sc_Gen3
      LFSR_8_gen3 lfsr_8_gen3(
        .seed(24'hFFFFFF),   
        .LFSR_RST(LFSR_RST[i]), 
        .rst(local_rst), 
        .back_pressure(!RX_Data_Valid[i]),
        .TX_CLK(local_clk), 
        .Data_Out(LFSR_Out_8_gen3[i*8 : ((i+1)*8)-1]),
        .EN(enable),
        .advance(advance[i]),
        .GEN(GEN)
      );

      LFSR_8  LF1(    
        .rst(local_rst),
        .TX_CLK(local_clk),
        .LFSR_RST(LFSR_RST[i]),
        .GEN(GEN),
        .advance(advance[i]),
        .EN(RXValid[i]),
        .Data_Out(LFSR_Out_8[i*8 : ((i+1)*8)-1])
      );

      Descrambler_Controler descrambler_control( 
        .CLK(local_clk),
        .RST_L(local_rst),
        .SyncHeader(deskewed_RX_sync[i]), 
        .PIPE_Data(rx_data[i*8 : ((i+1)*8)-1]), 
        .GEN(GEN),
	      .SC_LFSR_RST(LFSR_RST[i]),
	      .count(PIPE_count[i]), 
	      .advance(advance[i]),
        .RX_Data_Valid(RX_Data_Valid[i]),
	      .descramblingEnable(descramblingEnable[i])
      );

	    Descrambler descrambler(
	      .RX_CLK(local_clk), 
	      .rst(local_rst),
	      .PIPE_SyncHeader(deskewed_RX_sync[i]),
	      .seed(24'hFFFFFF), 
	      .PIPE_Data(rx_data[i*8 : ((i+1)*8)-1]), 
        .PIPE_d_K(PIPE_d_K[i]), 
        .GEN(GEN),
	      .count(PIPE_count[i]),
	      .LFSR_RST(LFSR_RST[i]),   
        .descramblingEnable(descramblingEnable[i]),   
        .LFSR_Out_8(LFSR_Out_8[i*8 : ((i+1)*8)-1]),
        .LFSR_Out_8_gen3(LFSR_Out_8_gen3[i*8 : ((i+1)*8)-1]),
	      .Des_Data_Out(Des_Data_Out[i*8 : ((i+1)*8)-1])
      );

      PIPE_Counter_pipe  #(
        .CNT_WIDTH(CNT_WIDTH) 
      ) PIPE_Counter_1 (
	      .CLK(local_clk),
        .Hard_RST_L(local_rst),
        .PIPE_CNT_rst(PIPE_CNT_rst),
        .CNT_set(type_IDL_TS),
	      .i_CNT_EN((RX_Data_Valid[i] && (GEN == 1)) || (RXValid[i] && (GEN == 'd0))),		// to enable counting up by one when set
	      .RX_Start_Block(RX_Start_Block[i]),
        .o_CNT(PIPE_count[i])			//current count
      );

      Block_Type_Logic  Block_Type_Logic_1 (
        .CLK(local_clk) , 
        .RST_L(local_rst),
        .RX_Sync_Header(RX_SYNC_Header[i]),
        .RX_Start_Block(RX_Start_Block[i]),
        .Block_Type(deskewed_RX_sync[i])
      );

    end
  end
endgenerate

endmodule




