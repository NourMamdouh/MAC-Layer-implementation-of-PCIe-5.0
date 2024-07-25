/*Description

	Packet Filter is the block responsible for processing the incoming data stream 
	to ensure that the Data Link Layer (DLL) on the receiving (Rx) side receives data identical to that transmitted to the Media Access Control (MAC) layer on the transmitting (Tx) side. 
	It accomplishes this by eliminating any framing that have been added 
	and meticulously checking for any framing errors that may have occurred, 
	promptly reporting such Errors to the Link Training and Status State Machine (LTSSM) upon their detection.

*/

module Packet_Filter_TOP #(
    parameter SYMBOL_WIDTH				= 'd8,           		  	// in bits
    parameter PACKET_LENGTH				= 'd11,        			    // in DW
    parameter SYMBOL_NUM_WIDTH			= 'd4, 								
    parameter SYMBOL_PTR_WIDTH 			= 'd5,						// for framing buffer data_width && Last_Byte
    parameter MAX_LANES					= (2**SYMBOL_PTR_WIDTH),    // max number of lanes
    parameter FILTERED_Buff_DATA_In_WIDTH 	= 'd30,
    parameter FILTERED_Buff_DATA_Out_WIDTH 	= 'd31,
    parameter FRAME_DEPTH = 4

) (
    input	logic													CLK,RST_L,i_EN,
    input	logic													i_Lanes,   			// 32 lanes or only one lane
    // Byte Unstripping outputs 
    input	logic	[0:(SYMBOL_WIDTH*MAX_LANES)-1]					i_RCV_Data,
    input	logic													i_Block_Type,
    // oredered sets related inputs
    input   logic                                                   Soft_RST_blocks,
    input	logic	[SYMBOL_NUM_WIDTH-1:0]							i_Symbol_Num,
    // Filtered Data and RX Buffer inputs
    output  logic                                                   EIEOS_Flag,
    output	logic	[0:(SYMBOL_WIDTH*MAX_LANES)-1]					o_Filtered_Data1,
    output	logic	[0:(SYMBOL_WIDTH*MAX_LANES)-1]					o_Filtered_Data2,
    output	logic													o_SOP1,o_SOP2,
    output	logic	[SYMBOL_PTR_WIDTH-1:0]							o_Last_Byte1,o_Last_Byte2,
    output	logic													o_End_Valid1,o_End_Valid2,
    output	logic													o_Type1,o_Type2,
    output	logic	[PACKET_LENGTH-1:0]								o_Length1,o_Length2,
    output	logic													o_Rx_Buff_W_EN,
    output	logic													o_Rx_Buff_valid_2, 		// to enable writting to locations
    // general outputs
    output	logic													o_Error  				//to be raised when an error is detected

);

// lane configurations
localparam									lane_1 			='d0,
											Lane_32			='d1;

//////////////////////////////// Internal Signals //////////////////////////////////////////////////
// Filtering Buffer Signals
logic [SYMBOL_PTR_WIDTH-1:0]                            address;
logic [1:0]                                             i_Data_W_Options;
logic                                                   i_Type , i_SOP, o_SOP, o_Type;
logic [PACKET_LENGTH-1:0]                               i_Length,o_Length;
logic                                                   i_Filter_Buff_ind_W_EN, i_Filter_Buff_SOP_W_EN, i_Filter_Buff_Data_W_EN;
logic [0:FILTERED_Buff_DATA_In_WIDTH*SYMBOL_WIDTH-1]    i_Filter_Buff_Data;
logic [0:FILTERED_Buff_DATA_Out_WIDTH*SYMBOL_WIDTH-1]   o_Filter_Buff_Data;

// FSM signals
logic [2:0] i_Token_Type;
logic i_CNT_Done , o_CNT_EN , o_CNT_RST;
logic [SYMBOL_PTR_WIDTH-1:0]	i_Count , o_CNT_END_VAL , o_CNT_RST_VAL;

//Frame checker
logic	[0:(FRAME_DEPTH*SYMBOL_WIDTH-1)]	i_Token_choice;


always_comb begin
    case (i_Lanes)
        lane_1: begin
            i_Token_choice = {o_Filter_Buff_Data[0:3*SYMBOL_WIDTH-1] , i_RCV_Data[0:SYMBOL_WIDTH-1]};
        end
        Lane_32: begin
            i_Token_choice = i_RCV_Data[0:4*SYMBOL_WIDTH-1];
        end
        default: begin
            i_Token_choice = i_RCV_Data[0:4*SYMBOL_WIDTH-1];
        end
    endcase
    
end


// Filtering Buffer instantiation
Filtering_Buffer FB(
    .CLK(CLK),
    .RST_L(RST_L),
    .address(address),
	.i_Data_W_Options(i_Data_W_Options),  // to determine the number of bytes to be written at a time (1,2 or 30)
    .i_Type(i_Type),
    .i_SOP(i_SOP),
    .i_Length(i_Length),
    .i_Filter_Buff_ind_W_EN(i_Filter_Buff_ind_W_EN), 
    .i_Filter_Buff_SOP_W_EN(i_Filter_Buff_SOP_W_EN),
    .i_Filter_Buff_Data_W_EN(i_Filter_Buff_Data_W_EN), 
    .i_Filter_Buff_Data(i_Filter_Buff_Data),
    .o_Filter_Buff_Data(o_Filter_Buff_Data),
    .o_SOP(o_SOP),
    .o_Length(o_Length),
    .o_Type(o_Type)
);

// FSM Instantiation
Packet_Filter_fsm Pf(
    .CLK(CLK),
    .RST_L(RST_L),
    .i_EN(i_EN),
    .i_Lanes(i_Lanes),   			
    .i_RCV_Data(i_RCV_Data),
    .i_Block_Type(i_Block_Type),
    .i_Token_Type(i_Token_Type),
	.i_Symbol_Num(i_Symbol_Num),
    .i_CNT_Done(i_CNT_Done),
    .Soft_RST_blocks(Soft_RST_blocks),
    .EIEOS_Flag(EIEOS_Flag),
    .i_Count(i_Count),
    .o_CNT_EN(o_CNT_EN),
    .o_CNT_RST(o_CNT_RST),
    .o_CNT_RST_VAL(o_CNT_RST_VAL),
    .o_CNT_END_VAL(o_CNT_END_VAL),
    .i_Filter_Buff_Data(o_Filter_Buff_Data),
    .i_Filter_Buff_SOP(o_SOP),
    .i_Filter_Buff_Length(o_Length),
    .i_Filter_Buff_Type(o_Type),
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
	.o_Error(o_Error),   				
    .o_Filter_Buff_Adress(address),
    .o_Filter_Buff_Type(i_Type),
    .o_Filter_Buff_Data_W_EN(i_Filter_Buff_Data_W_EN), 
    .o_Filter_Buff_Ind_W_EN(i_Filter_Buff_ind_W_EN), 
    .o_Filter_Buff_SOP_W_EN(i_Filter_Buff_SOP_W_EN),    
    .o_Filter_Buff_Data_W_Options(i_Data_W_Options),
	.o_Filter_Buff_Data(i_Filter_Buff_Data),
    .o_Filter_Buff_SOP(i_SOP),
    .o_Filter_Buff_Length(i_Length)
);

//Counter instance
Counter CTR(
    .CLK(CLK),
    .Hard_RST_L(RST_L),
    .Soft_RST(o_CNT_RST || Soft_RST_blocks),
    .i_CNT_EN(o_CNT_EN),
    .i_CNT_RST_VAL(o_CNT_RST_VAL),
    .i_CNT_END_VAL(o_CNT_END_VAL),
    .o_CNT(i_Count),
    .o_CNT_Done(i_CNT_Done)
);

//Error checker
Frame_Checker Fc(
    .i_Token(i_Token_choice),
    .o_Token_Type(i_Token_Type)
);
    
endmodule