module RX_TOP #(
    SYMBOL_WIDTH				    = 'd8,           		  	// in bits
    PACKET_LENGTH				    = 'd11,        			    // in DW
    SYMBOL_NUM_WIDTH			    = 'd4, 								
    SYMBOL_PTR_WIDTH 			    = 'd5,						// for framing buffer data_width && Last_Byte
    MAX_LANES					    = (2**SYMBOL_PTR_WIDTH),    // max number of lanes
    FILTERED_Buff_DATA_In_WIDTH 	= 'd30,
    FILTERED_Buff_DATA_Out_WIDTH 	= 'd31,
    FRAME_DEPTH                     = 4,
    DATA_WIDTH                      = 256,
    BUFFER_DEPTH                    = 8,
    ADDR_WIDTH                      = 3
) (
    input	logic													CLK,RST_L,i_EN,
    input	logic													i_Lanes,   			// 32 lanes or only one lane
    // Byte Unstripping outputs 
    input	logic	[0:(SYMBOL_WIDTH*MAX_LANES)-1]					i_RCV_Data,
    input	logic													i_Block_Type,
    // oredered sets related inputs
    input	logic	[SYMBOL_NUM_WIDTH-1:0]							i_Symbol_Num,
    input   logic                                                   i_RD_EN,
    input                                                           Soft_RST_blocks,
    // general outputs
    output                                                          EIEOS_Flag,
    output	    													o_Error,  				//to be raised when an error is detected
    output                                                          o_Empty,
    output          [0:DATA_WIDTH-1]                                Data_Out,
    output                                                          o_SOP,o_End_Valid,o_Type,
    output          [PACKET_LENGTH-1:0]                             o_Length,
    output          [SYMBOL_PTR_WIDTH-1:0]                          o_Last_Byte
);

////////////////////// Internal Signals //////////////////////////////////////////
// output from Packet Filter
logic	[0:(SYMBOL_WIDTH*MAX_LANES)-1]					o_Filtered_Data1,o_Filtered_Data2;
logic                                                   o_SOP1,o_SOP2,o_End_Valid1,o_End_Valid2,o_Type1,o_Type2;
logic                                                   o_Rx_Buff_W_EN,o_Rx_Buff_valid_2;
logic	[SYMBOL_PTR_WIDTH-1:0]							o_Last_Byte1,o_Last_Byte2;
logic	[PACKET_LENGTH-1:0]								o_Length1,o_Length2;

Packet_Filter_TOP PF(
    .CLK(CLK),
    .RST_L(RST_L),
    .i_EN(i_EN),
    .i_Lanes(i_Lanes),   			
    .i_RCV_Data(i_RCV_Data),
    .i_Block_Type(i_Block_Type),
    .i_Symbol_Num(i_Symbol_Num),
    .o_Filtered_Data1(o_Filtered_Data1),
    .o_Filtered_Data2(o_Filtered_Data2),
    .o_SOP1(o_SOP1),
    .o_SOP2(o_SOP2),
    .o_Last_Byte1(o_Last_Byte1),
    .o_Last_Byte2(o_Last_Byte2),
    .o_End_Valid1(o_End_Valid1),
    .o_End_Valid2(o_End_Valid2),
    .o_Type1(o_Type1),
    .o_Type2(o_Type2),
    .o_Length1(o_Length1),
    .o_Length2(o_Length2),
    .o_Rx_Buff_W_EN(o_Rx_Buff_W_EN),
    .o_Rx_Buff_valid_2(o_Rx_Buff_valid_2), 
    .EIEOS_Flag(EIEOS_Flag),
    .Soft_RST_blocks(Soft_RST_blocks),		
    .o_Error(o_Error)  				//to be raised when an error is detected
);

Rx_Buffer #(
    .BUFFER_DEPTH(BUFFER_DEPTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) RB(
    .CLK(CLK),
    .RST_L(RST_L),
    .i_WR_EN(o_Rx_Buff_W_EN), 
    .i_RD_EN(i_RD_EN),
    .i_SOP1(o_SOP1),
    .i_End_Valid1(o_End_Valid1),
    .i_Type1(o_Type1),
    .i_SOP2(o_SOP2),
    .i_End_Valid2(o_End_Valid2),
    .i_Type2(o_Type2),
    .i_512_valid(o_Rx_Buff_valid_2),
    .i_Length1(o_Length1),
    .i_Length2(o_Length2),
    .i_Last_Byte1(o_Last_Byte1),
    .i_Last_Byte2(o_Last_Byte2),
    .Data_IN1(o_Filtered_Data1),
    .Data_IN2(o_Filtered_Data2),
    .o_Empty(o_Empty), 
    .Data_Out(Data_Out),
    .o_SOP(o_SOP),
    .o_End_Valid(o_End_Valid),
    .o_Type(o_Type),
    .o_Length(o_Length),
    .Soft_RST_blocks(Soft_RST_blocks),
    .o_Last_Byte(o_Last_Byte)
);
    
endmodule