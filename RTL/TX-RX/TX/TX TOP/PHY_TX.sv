module PHY_TX #(
    DATA_WIDTH = 256,
    BUFFER_DEPTH = 8,
    ADDR_WIDTH = 3,
    PACKET_LENGTH	= 'd11,    // in DW
    SYMBOL_PTR_WIDTH  = 'd5,					// for framing buffer data_width && Last_Byte
    SYMBOL_NUM_WIDTH	= 'd4, 								
    SYMBOL_WIDTH		= 'd8,           		  	// in bits
    MAX_LANES			= (2**SYMBOL_PTR_WIDTH) ,   // max number of lanes
    serdes            = 1, // default Serdes
    SYNC_WIDTH =2
) (

    input                                   CLK,
    input                                   RST_L,
    input                                   i_EN,
    input [1:0]                             i_GEN_Lanes,
    input                                   i_Os_Enable,
    input [0:(SYMBOL_WIDTH*MAX_LANES)-1]	i_OS,
    input                                   i_WR_EN,
    input                                   i_SOP,i_End_Valid,i_Type,
    input [PACKET_LENGTH-1:0]               i_Length,
    input [SYMBOL_PTR_WIDTH-1:0]            i_Last_Byte,
    input [0:DATA_WIDTH-1]                  Data_IN,
    input                                   idle_cnt_enable,
    input [0:MAX_LANES-1]	    	        o_D_K,			// to be used for sync header insertion
    input                                   IDL_rst,
    input                                   Soft_RST_blocks,
    output                                  ack_done,
    output                                  o_Full, // re consider the throttling of DATA LINK Layer
    output [0:(SYMBOL_WIDTH*MAX_LANES)-1]	out_data, // GEN 3 
    output [0:MAX_LANES-1]                  valid_data, // GEN3
    output [0:MAX_LANES-1]                  TxStartBlock,
    output [0:1]                            TxSyncHeader [0:MAX_LANES-1],
    output   							    o_Sync_Sel,		// to be used for sync header insertion
    output    							    o_Idle_Indicator, //raised one when sending idles (no more TLPs or DLLPs to send)
    output [0:MAX_LANES-1]                  back_pressures 
);

/////////////////// Internal Signals /////////////////////////
logic [0:(SYMBOL_WIDTH*MAX_LANES)-1]	    o_Framed_Data;
logic [SYMBOL_NUM_WIDTH-1:0]			    i_Symbol_Num [0:MAX_LANES-1];



TX_TOP TT(
    .CLK(CLK), 
    .RST_L(RST_L), 
    .i_EN(i_EN && !back_pressures[0]), 
    .i_GEN_Lanes(i_GEN_Lanes), 
    .i_Os_Enable(i_Os_Enable), 
    .i_OS(i_OS), 
    .i_Symbol_Num(i_Symbol_Num[0]), 
    .i_WR_EN(i_WR_EN),       
    .i_SOP(i_SOP),
    .i_End_Valid(i_End_Valid),
    .i_Type(i_Type),
    .i_Length(i_Length),
    .i_Last_Byte(i_Last_Byte),    
    .Data_IN(Data_IN), 
    .o_Full(o_Full),     
    .o_Idle_Indicator(o_Idle_Indicator), 
    .o_Sync_Sel(o_Sync_Sel),
    .Soft_RST_blocks(Soft_RST_blocks), 
    .o_Framed_Data(o_Framed_Data)
);

scrambler_and_sync  #(
    .serdes(serdes), 
    .SYMBOL_WIDTH(SYMBOL_WIDTH), 
    .CNT_WIDTH(SYMBOL_NUM_WIDTH),  
    .SYNC_WIDTH(SYNC_WIDTH)
    ) DUT0(
    .tx_clk(CLK), 
    .tx_rst(RST_L), 
    .EN(i_EN),
    .GEN(i_GEN_Lanes[0]),
    .sync_sel(o_Sync_Sel),
    .Sc_Data_In(o_Framed_Data[0 : 7]), // check awl ma ytl3 8lt
    .d_K(o_D_K[0]),
    .out_data(out_data[0:7]),
    .symbol_cnt(i_Symbol_Num[0]),
    .valid_data(valid_data[0]),
    .back_pressure(back_pressures[0]),
    .sync_header(TxSyncHeader[0]),
    .Tx_Start_Block(TxStartBlock[0])
    );
generate
    genvar i;
    for( i = 1 ; i < 32 ; i = i + 1)begin: sc_Gen3
        scrambler_and_sync #(
            .serdes(serdes), 
            .SYMBOL_WIDTH(SYMBOL_WIDTH), 
            .CNT_WIDTH(SYMBOL_NUM_WIDTH),  
            .SYNC_WIDTH(SYNC_WIDTH)
            ) DUT (
            .tx_clk(CLK), 
            .tx_rst(RST_L), 
            .EN(i_EN && i_GEN_Lanes[1]),
            .GEN(i_GEN_Lanes[0]),
            .sync_sel(o_Sync_Sel),
            .Sc_Data_In(o_Framed_Data[i*8 : ((i+1)*8)-1]), // check awl ma ytl3 8lt
            .d_K(o_D_K[i]),
            .out_data(out_data[i*8 : ((i+1)*8)-1]),
            .symbol_cnt(i_Symbol_Num[i]),
            .valid_data(valid_data[i]),
            .back_pressure(back_pressures[i]),
            .sync_header(TxSyncHeader[i]),
            .Tx_Start_Block(TxStartBlock[i])
        );
    end
endgenerate

IDLE_Counter ID(
    .clk(CLK),
    .rst(RST_L),
    .cnt_enable(idle_cnt_enable),
    .back_pressure(back_pressures[0]),
    .IDL_rst(IDL_rst),
    .ack_done(ack_done)
);
    
endmodule