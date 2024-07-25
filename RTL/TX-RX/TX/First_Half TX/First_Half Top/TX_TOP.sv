module TX_TOP #(
    parameter DATA_WIDTH = 256,
    parameter BUFFER_DEPTH = 8,
    parameter ADDR_WIDTH = 3,
    parameter PACKET_LENGTH	= 'd11,    // in DW
    parameter SYMBOL_PTR_WIDTH  = 'd5,					// for framing buffer data_width && Last_Byte
    parameter SYMBOL_NUM_WIDTH	= 'd4, 								
    parameter SYMBOL_WIDTH		= 'd8,           		  	// in bits
    parameter MAX_LANES			= (2**SYMBOL_PTR_WIDTH)    // max number of lanes


) (
    input                                   CLK,
    input                                   RST_L,
    input                                   i_EN,
    input [1:0]                             i_GEN_Lanes,
    input                                   i_Os_Enable,
    input [0:(SYMBOL_WIDTH*MAX_LANES)-1]	i_OS,
    input [SYMBOL_NUM_WIDTH-1:0]			i_Symbol_Num,
    input                                   i_WR_EN,
    input                                   i_SOP,i_End_Valid,i_Type,
    input [PACKET_LENGTH-1:0]               i_Length,
    input [SYMBOL_PTR_WIDTH-1:0]            i_Last_Byte,
    input [0:DATA_WIDTH-1]                  Data_IN,
    input                                   Soft_RST_blocks,
    output                                  o_Full,
    output	    							o_Idle_Indicator,   //raised one when sending idles (no more TLPs or DLLPs to send)
    output	    							o_Sync_Sel,			// to be used for sync header insertion
    // costructed data to Byte stripping
    output [0:(SYMBOL_WIDTH*MAX_LANES)-1]	o_Framed_Data
);
    ///////////////////// Internal Signals ///////////////////////
    // output from TX Buffer
    logic i_RD_EN,o_Empty;
    logic [0:DATA_WIDTH-1] Data_Out;
    logic o_SOP,o_End_Valid,o_Type;
    logic [PACKET_LENGTH-1:0] o_Length;
    logic [SYMBOL_PTR_WIDTH-1:0] o_Last_Byte;

    Interface_Buffer  #(
        .BUFFER_DEPTH(BUFFER_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH) 
    )IB(
        .CLK(CLK),
        .RST_L(RST_L),
        .i_WR_EN(i_WR_EN), 
        .i_RD_EN(i_RD_EN),
        .i_SOP(i_SOP),
        .i_End_Valid(i_End_Valid),
        .i_Type(i_Type),
        .i_Length(i_Length),
        .i_Last_Byte(i_Last_Byte),
        .Data_IN(Data_IN),
        .o_Empty(o_Empty), 
        .o_Full(o_Full),
        .Data_Out(Data_Out),
        .o_SOP(o_SOP),
        .o_End_Valid(o_End_Valid),
        .o_Type(o_Type),
        .o_Length(o_Length),
        .Soft_RST_blocks(Soft_RST_blocks),
        .o_Last_Byte(o_Last_Byte)
    );

    Tx_Framing TF(
        .CLK(CLK),
        .RST_L(RST_L),
        .i_EN(i_EN),
        .i_Buffer_Data(Data_Out),
        .i_SOP(o_SOP),
        .i_Last_Byte(o_Last_Byte),
        .i_End_Valid(o_End_Valid),
        .i_Type(o_Type),
        .i_Length(o_Length),
        .i_Buffer_Empty(o_Empty),
        .i_GEN_Lanes(i_GEN_Lanes),
        .i_Os_Enable(i_Os_Enable),
        .i_OS(i_OS),
        .i_Symbol_Num(i_Symbol_Num),
        .o_Buffer_R_EN(i_RD_EN),
        .o_Idle_Indicator(o_Idle_Indicator),   
        .o_Sync_Sel(o_Sync_Sel),			
        .o_Framed_Data(o_Framed_Data)
    );
endmodule