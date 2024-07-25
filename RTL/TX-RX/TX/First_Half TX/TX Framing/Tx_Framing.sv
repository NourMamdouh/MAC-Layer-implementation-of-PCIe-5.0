/*	TX Framing in our design Supports Gen1,2 in Training sequence only and Gen 3,4,5 in training sequence and data transmission in
    case 32 lane and 1 lane so we needed multiplexer to out (Fram Sel) from Gen3_32 lane or Gen_3_1 lane or Gen1,2 according to 
    (i_Gen_Lanes).We need another multiplexer to out (o_Framed_Data) from Framed_Data_32 or Framed_Data_1 or IDLES or
    OS according to (Fram_Sel).(o_D_K) signal is asserted in case Gen1,2 and there are OS to be sent that is control characters.
*/

module Tx_Framing #(
parameter SYMBOL_WIDTH		= 'd8,           		  	// in bits
parameter PACKET_LENGTH		= 'd11,        			    // in DW
parameter SYMBOL_NUM_WIDTH	= 'd4, 								
parameter SYMBOL_PTR_WIDTH  = 'd5,						// Last_Byte
parameter MAX_LANES			= (2**SYMBOL_PTR_WIDTH)    // max number of lanes
)(
input	logic									CLK,RST_L,i_EN,
// Tx Buffer outputs
input	logic	[0:(SYMBOL_WIDTH*MAX_LANES)-1]	i_Buffer_Data,
input	logic									i_SOP,
input	logic	[SYMBOL_PTR_WIDTH-1:0]			i_Last_Byte,
input	logic									i_End_Valid,
input	logic									i_Type,
input	logic	[PACKET_LENGTH-1:0]				i_Length,
input	logic									i_Buffer_Empty,
// to be assigned after training
input	logic	[1:0]							i_GEN_Lanes,
// oredered sets related inputs
input	logic									i_Os_Enable,
input	logic	[0:(SYMBOL_WIDTH*MAX_LANES)-1]	i_OS,
input	logic	[SYMBOL_NUM_WIDTH-1:0]			i_Symbol_Num,
// Tx Buffer inputs
output	logic									o_Buffer_R_EN,
// general outputs
output	logic									o_Idle_Indicator,   //raised one when sending idles (no more TLPs or DLLPs to send)
output	logic									o_Sync_Sel,			// to be used for sync header insertion
// costructed data to Byte stripping
output	logic	    [0:(SYMBOL_WIDTH*MAX_LANES)-1]	o_Framed_Data

);


/////////////////////////parameters/////////////////
localparam EDS_DIPTH				= 'd4;
localparam STP_DIPTH				= 'd4;
localparam SDP_DIPTH				= 'd2;
localparam FRAMING_BUFF_DATA_WIDTH	= SYMBOL_WIDTH*2;
///////////////////////
localparam IDLE 					= 'b00;
localparam OS						= 'b01;
localparam FRAM_32 					= 'b10;
localparam FRAM_1					= 'b11;
///FOR i_GEN_Lanes////
localparam [1:0] GEN_1_1 			= 'd0;
localparam [1:0] GEN_1_32 			= 'd2;
localparam [1:0] H_GEN_1 			= 'd1;
localparam [1:0] H_GEN_32			= 'd3;

///////////////internal logics//////////////////////
logic GEN_1_SEL, H_GEN_32_EN, H_GEN_1_EN, GEN_1_EN;
logic [1:0] H_GEN_1_SEL, H_GEN_32_SEL;
logic  [1:0] FRAM_SEL;  
logic [0:SYMBOL_WIDTH*MAX_LANES-1] FRAMED_DATA_32, FRAMED_DATA_1;

//////////////FRAMING FOR GEN3/////////////////////
Gen3_Top #(
    .SYMBOL_WIDTH(SYMBOL_WIDTH),           		  	// in bits
    .PACKET_LENGTH(PACKET_LENGTH),        			    // in DW
    .SYMBOL_NUM_WIDTH(SYMBOL_NUM_WIDTH), 								
    .SYMBOL_PTR_WIDTH(SYMBOL_PTR_WIDTH),						// for framing buffer data_width && Last_Byte
    .MAX_LANES(MAX_LANES),    // max number of lanes
    .EDS_DIPTH(EDS_DIPTH), 
    .STP_DIPTH(STP_DIPTH), 
    .SDP_DIPTH(SDP_DIPTH),
    .FRAMING_DATA_WIDTH(FRAMING_BUFF_DATA_WIDTH)
) FRAMING_GEN_3(
    .CLK(CLK),
    .RST_L(RST_L),
    .i_EN_32(H_GEN_32_EN),
    .i_EN_1(H_GEN_1_EN),
    .i_Buffer_Data(i_Buffer_Data),
    .i_SOP(i_SOP), 
	.i_End_Valid (i_End_Valid), 
	.i_Type(i_Type),
	.i_Buffer_Empty(i_Buffer_Empty),
    .i_Last_Byte(i_Last_Byte),
    .i_Length(i_Length),
    // inputs from LTSSM
    .i_Os_Enable(i_Os_Enable),
    // inputs from sync logic
    .i_Symbol_Num(i_Symbol_Num),
    // Outputs to TX_Buffer
    .o_Buffer_R_EN(o_Buffer_R_EN),
    // Outputs to Sync logic
    .o_Idle_Indicator(o_Idle_Indicator),
    .o_Sync_Sel(o_Sync_Sel),
    // outputs to TX_Frame TOP 
    .o_Framed_Data_32(FRAMED_DATA_32),
    .o_Framed_Data_1(FRAMED_DATA_1),
    .o_Fram_Sel_32(H_GEN_32_SEL),
    .o_Fram_Sel_1(H_GEN_1_SEL)
);

/////////////////////////////////////////////////////////

always_comb begin
	FRAM_SEL = 'd0;
	case(i_GEN_Lanes)
		GEN_1_1 , GEN_1_32	 : begin
			FRAM_SEL = {1'b0,GEN_1_SEL};
		end
		H_GEN_32 : begin
			FRAM_SEL = H_GEN_32_SEL;
		end
		H_GEN_1  : begin
			FRAM_SEL = H_GEN_1_SEL;
		end	
	endcase
end

always_comb begin
	o_Framed_Data = 'd0;
	case(FRAM_SEL)
		IDLE	: begin
			o_Framed_Data = 'd0;
		end
		OS		: begin
			o_Framed_Data = i_OS;
		end
		FRAM_32	: begin
			o_Framed_Data = FRAMED_DATA_32;
		end	
		FRAM_1	: begin
			o_Framed_Data = FRAMED_DATA_1;
		end			
	endcase
end

assign GEN_1_EN    = ((i_GEN_Lanes == 2'b00) || (i_GEN_Lanes ==  2'b10)) && i_EN;
assign GEN_1_SEL   = (i_Os_Enable && GEN_1_EN) ;
assign H_GEN_32_EN = (i_GEN_Lanes == H_GEN_32) && i_EN;
assign H_GEN_1_EN  = (i_GEN_Lanes == H_GEN_1) && i_EN;


endmodule