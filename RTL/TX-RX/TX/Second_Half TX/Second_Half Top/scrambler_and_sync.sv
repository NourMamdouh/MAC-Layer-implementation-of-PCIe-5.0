module scrambler_and_sync #(
  serdes = 0,
  SYMBOL_WIDTH = 8,
  CNT_WIDTH = 4,
  SYNC_WIDTH =2
)(
  
  input  logic                      tx_clk, tx_rst, 
  input  logic                      GEN,
  input  logic                      sync_sel,
  input  logic [SYMBOL_WIDTH -1:0]  Sc_Data_In,
  input  logic                      d_K,
  input  logic                      EN,
  output logic [SYMBOL_WIDTH-1:0]   out_data,
  output logic [CNT_WIDTH-1:0]      symbol_cnt,
  output logic                      valid_data,
  output logic                      back_pressure,
  output logic [SYNC_WIDTH-1:0]     sync_header,
  output logic                      Tx_Start_Block

  );
  
  logic                     LFSR_RST         ;
  logic [SYMBOL_WIDTH-1:0]  LFSR_Out_8       ;
  logic [SYMBOL_WIDTH-1:0]  LFSR_Out_8_gen3  ;  
  logic                     scramblingEnable ;
  logic [SYMBOL_WIDTH-1:0]  Sc_Data_Out      ;
  logic [1:0]               symb_14 ;
  logic [1:0]               symb_15  ;
  logic                     advance ;
  logic                     TS_flag_Stored ;
  logic [SYMBOL_WIDTH-1:0]  sync_data;

  assign out_data = (GEN == 1)?sync_data:Sc_Data_Out;
  
  Sync_Logic #(
    .serdes(serdes),
    .SYMBOL_WIDTH(SYMBOL_WIDTH), 
    .CNT_WIDTH(CNT_WIDTH),    
    .SYNC_WIDTH(SYNC_WIDTH)   
    ) u0_sync_logic (

    .clk(tx_clk),
    .rst(tx_rst),
    .enable(EN && GEN),
    .scrambled_data(Sc_Data_Out),
    .sync_sel(sync_sel),
    .sync_data(sync_data),
    .symbol_cnt(symbol_cnt),
    .back_pressure(back_pressure),
    .valid_data(valid_data),
    .Tx_Start_Block(Tx_Start_Block),
    .sync_header(sync_header)
  );
   
  LFSR_8_gen3 lfsr_8_gen3(
    .seed(24'hFFFFFF), 
    .LFSR_RST(LFSR_RST), 
    .rst(tx_rst), 
    .back_pressure(back_pressure),
    .TX_CLK(tx_clk), 
    .Data_Out(LFSR_Out_8_gen3),
    .advance(advance),
    .EN(EN),
    .GEN(GEN)
  );

  LFSR_8  LF1(
    .rst(tx_rst),
    .TX_CLK(tx_clk),
    .LFSR_RST(LFSR_RST),
    .GEN(GEN),
    .advance(advance),
    .EN(EN),
    .Data_Out(LFSR_Out_8)
  );

  DC_Balance dc_balance(
    .Sc_Data_In(Sc_Data_In),
    .count(symbol_cnt), 
    .clk(tx_clk),
    .rst(tx_rst), 
    .symb_14(symb_14),
    .symb_15(symb_15),
    .TS_flag_Stored(TS_flag_Stored));

  
  Scrambler_Controler scrambler_control( 
    .SyncHeader(sync_sel), 
    .Sc_Data(Sc_Data_In), // from framming [7:0] ..
    .GEN(GEN),
	  .SC_LFSR_RST(LFSR_RST),
	  .count(symbol_cnt), 
	  .advance(advance),
	  .scramblingEnable(scramblingEnable),
    .CLK(tx_clk),
    .RST_L(tx_rst),
    .back_pressure(back_pressure),
    .TS_flag_Stored(TS_flag_Stored)
	);
	
	Scrambler scrambler(
	  .TX_CLK(tx_clk), 
	  .rst(tx_rst),
	  .SyncHeader(sync_sel),// from framming
	  .seed(24'hFFFFFF), 
	  .Sc_Data_In(Sc_Data_In), // from framming [7:0] ..
    .d_K(d_K), // from framming 
    .GEN(GEN),
	  .back_pressure(back_pressure),
	  .count(symbol_cnt),
	  .LFSR_RST(LFSR_RST), //from sc_control  
    .scramblingEnable(scramblingEnable), //from sc_control  
    .LFSR_Out_8(LFSR_Out_8),
    .LFSR_Out_8_gen3(LFSR_Out_8_gen3),
	  .Sc_Data_Out(Sc_Data_Out),
	  .symb_14(symb_14),
	  .symb_15(symb_15)
	);
	  
endmodule



