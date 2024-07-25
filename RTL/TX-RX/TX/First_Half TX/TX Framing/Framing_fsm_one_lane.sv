/*	FSM_1 is required to control Framing Data in case 1 lane as it’s responsible to out the final Form of data framed by Tokens and 
	out the Fram Sel to out Data or out OS’s in case there’s OS’s need to be sent or IDLES in case there’s no ready Data nor OS’s.*/

module Framing_fsm_one_lane #(
parameter SYMBOL_WIDTH		= 'd8,           		  	// in bits
parameter PACKET_LENGTH		= 'd11,        			    // in DW
parameter SYMBOL_NUM_WIDTH	= 'd4, 								
parameter SYMBOL_PTR_WIDTH  = 'd5,						// for framing buffer data_width && Last_Byte
parameter MAX_LANES			= (2**SYMBOL_PTR_WIDTH),    // max number of lanes
parameter EDS_DIPTH			= 4, 
parameter STP_DIPTH			= 4, 
parameter SDP_DIPTH			= 2
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
// Framing Tokens
input	logic	[0:(SDP_DIPTH*SYMBOL_WIDTH-1)]	i_SDP,
input	logic	[0:(STP_DIPTH*SYMBOL_WIDTH-1)]	i_STP,
input	logic	[0:(EDS_DIPTH*SYMBOL_WIDTH-1)]	i_EDS,
input	logic	[0:(SYMBOL_WIDTH-1)]			i_IDL,
// oredered sets related inputs
input	logic									i_Os_Enable,
input	logic	[SYMBOL_NUM_WIDTH-1:0]			i_Symbol_Num,
// counter outputs
input	logic									i_CNT_Done,
input	logic	[SYMBOL_PTR_WIDTH-1:0]			i_Count,
// counter inputs
output	logic										o_CNT_EN,       // to enable counting up by one
output	logic										o_CNT_RST,      // active high reset
output	logic		[SYMBOL_PTR_WIDTH-1:0]			o_CNT_RST_VAL,   //counter start value
output	logic		[SYMBOL_PTR_WIDTH-1:0]			o_CNT_END_VAL,   //counter start value
// Tx Buffer inputs
output	logic										o_Buffer_R_EN,
// general outputs
output	logic										o_Idle_Indicator,   //raised one when sending idles (no more TLPs or DLLPs to send)
output	logic										o_Sync_Sel,			// to be used for sync header insertion
// costructed data and selection
output	logic		[0:(SYMBOL_WIDTH*MAX_LANES)-1]	o_Framed_Data,
output	logic		[1:0]							o_Fram_Sel

);

/////////////////////important parameters ////////////////////////
localparam [SYMBOL_NUM_WIDTH-1:0]	EDS_Start_Symbol = 'd12;
localparam 							DLLP_DATA_DIPTH  = 'd6;
localparam 							SEQ_NUM_DIPTH    = 'd2;
localparam							SYNC_H_DATA      = 'd0;
localparam							SYNC_H_OS        = 'd1;
// FRAMING SELECTION
localparam IDLE    = 'b00;
localparam OS      = 'b01;
localparam FRAM_32 = 'b10;
localparam FRAM_1  = 'b11;


/////////////////////state definitions ////////////////////////
localparam [2:0] 	Reset		= 'b000,
					Send_Os		= 'b001,
					Tokens		= 'b011,
					EDS			= 'b100,
					STP			= 'b101,
					SDP			= 'b110,
					Data		= 'b010;
					
					
					
//s/////////////////state transitions//////////////////////////////////
logic 	   [2:0]	current_state,next_state;

always_ff @(posedge CLK,negedge RST_L)begin
	if(!RST_L)begin
		current_state <= Reset;
	end
	else begin
		current_state <= next_state;
	end
end



//////////////////////next_state and output logic///////////////////////////////
integer i;
always_comb begin

// output default values
	o_Buffer_R_EN		= 'd0;
	o_Idle_Indicator	= 'd0;
	o_Sync_Sel			= 'd0;
	o_Framed_Data		= 'd0;
	o_Fram_Sel			= IDLE;
	o_CNT_EN			= 'd0;
	o_CNT_RST			= 'd0;
	o_CNT_RST_VAL		= 'd0;
	o_CNT_END_VAL		= 'd0;
	next_state 			= Reset ;
	
	case (current_state)
	
		Reset:		begin
						o_CNT_RST  = 'd1;
						if (i_EN && i_Os_Enable) begin
							next_state = Send_Os;
							o_Fram_Sel = OS ;
							o_Sync_Sel = SYNC_H_OS;
						end
						else begin
							next_state = Reset;
							o_Fram_Sel = IDLE ;
							o_Sync_Sel = SYNC_H_DATA;
						end
					end
		
		
		Send_Os:	begin
						o_Fram_Sel = OS;
						o_Sync_Sel = SYNC_H_OS;
						o_CNT_RST  = 'd1;
						if (i_Os_Enable == 'd0 && i_EN) begin
							next_state = Tokens;
						end
						else begin
							next_state = Send_Os;
						end
					end	
				
				
		Tokens:		begin
						o_Sync_Sel = SYNC_H_DATA;
						o_Buffer_R_EN = 0;
						if(i_Os_Enable && (i_Symbol_Num == EDS_Start_Symbol) && i_EN)begin // EDS Token
							o_Fram_Sel = FRAM_1;
							for (i=0;i<SYMBOL_WIDTH;i=i+1)begin
								o_Framed_Data[i] = i_EDS[i_Count*SYMBOL_WIDTH + i];
							end	
							next_state = EDS;
							o_CNT_EN = 'd1;
						end
						else if (i_Os_Enable && !i_Buffer_Empty && i_EN) begin // ready ordered sets
							 if(i_Type == 0 && (6 + 2 + 4) <= (16-i_Symbol_Num))begin // DLLP fit 
								o_Fram_Sel = FRAM_1;
								for (i=0;i<SYMBOL_WIDTH;i=i+1)begin
									o_Framed_Data[i] = i_SDP[i_Count*SYMBOL_WIDTH + i];
								end	
								next_state = SDP;
								o_CNT_EN = 'd1;
							end
							else begin // IDLES
								o_Fram_Sel = IDLE;
								next_state = Tokens;
								o_Idle_Indicator = 0;
							end
						end
						else if (!i_Buffer_Empty && i_EN) begin // no ready ordered sets and not empty buffer
							o_Fram_Sel = FRAM_1;
							if(i_Type == 1)begin // TLP
								for (i=0;i<SYMBOL_WIDTH;i=i+1)begin
									o_Framed_Data[i] = i_STP[i_Count*SYMBOL_WIDTH + i];
								end
								next_state = STP;
								o_CNT_EN = 'd1;
							end
							else begin // DLLP
								for (i=0;i<SYMBOL_WIDTH;i=i+1)begin
									o_Framed_Data[i] = i_SDP[i_Count*SYMBOL_WIDTH + i];
								end	
								next_state = SDP;
								o_CNT_EN = 'd1;
							end
						end
						else begin // IDLES
							o_Fram_Sel = IDLE;
							next_state = Tokens;
							o_Idle_Indicator = 1;
						end
					end

		EDS:		begin
						o_Sync_Sel = SYNC_H_DATA;
						o_Fram_Sel = FRAM_1;
						o_CNT_END_VAL = EDS_DIPTH-1;
						for (i=0;i<SYMBOL_WIDTH;i=i+1)begin
							o_Framed_Data[i] = i_EDS[i_Count*SYMBOL_WIDTH + i];
						end
						if(i_CNT_Done)begin // 4 EDS is finished
							next_state = Send_Os;
							o_CNT_RST = 1;
							o_CNT_RST_VAL = 0;
						end
						else begin
							next_state = EDS;
							o_CNT_EN = 1;
						end
					end	

		STP:		begin
						o_Sync_Sel = SYNC_H_DATA;
						o_Fram_Sel = FRAM_1;
						o_CNT_END_VAL = STP_DIPTH-1;
						for (i=0;i<SYMBOL_WIDTH;i=i+1)begin
							o_Framed_Data[i] = i_STP[i_Count*SYMBOL_WIDTH + i];
						end
						if(i_CNT_Done)begin // 4 STP is finished
							next_state = Data;
							o_CNT_RST = 1;
							o_CNT_RST_VAL = 'd2;
						end
						else begin
							next_state = STP;
							o_CNT_EN = 1;
						end
					end	

		SDP:		begin
						o_Sync_Sel = SYNC_H_DATA;
						o_Fram_Sel = FRAM_1;
						o_CNT_END_VAL = SDP_DIPTH-1;
						for (i=0;i<SYMBOL_WIDTH;i=i+1)begin
							o_Framed_Data[i] = i_SDP[i_Count*SYMBOL_WIDTH + i];
						end
						if(i_CNT_Done)begin // 2 SDP is finished
							next_state = Data;
							o_CNT_RST = 1;
							o_CNT_RST_VAL = 'd0;
						end
						else begin
							next_state = SDP;
							o_CNT_EN = 1;
						end
					end					
					
					
		Data:		begin
		
						o_Sync_Sel = SYNC_H_DATA;
						o_Fram_Sel = FRAM_1;
						o_Framed_Data [SYMBOL_WIDTH : MAX_LANES*SYMBOL_WIDTH-1] = {(MAX_LANES-1){i_IDL}};
						
						for (i=0;i<SYMBOL_WIDTH;i=i+1)begin
							o_Framed_Data[i] = i_Buffer_Data[i_Count*SYMBOL_WIDTH + i];
						end	
						/////////////////////////////////
						if (i_End_Valid)begin
							o_CNT_END_VAL = i_Last_Byte;
						end
						else begin
							o_CNT_END_VAL = (2**SYMBOL_PTR_WIDTH)-'d1;
						end
						/////////////////////////////////
						if(i_CNT_Done && i_End_Valid && i_EN)begin
							next_state = Tokens;
							o_CNT_EN = 'd0;
							o_CNT_RST = 'd1;
							o_CNT_RST_VAL = 'd0;
						end
						else begin
							next_state = Data;
							o_CNT_EN = i_EN;
							o_CNT_RST = 'd0;
							o_CNT_RST_VAL = 'd0;
						end
						////////////////////////////////
						if(i_CNT_Done && i_EN) begin
							o_Buffer_R_EN = 'd1;
						end
						else begin
							o_Buffer_R_EN = 'd0;
						end
	
					end	
		
					
										
	endcase
	
	
end
endmodule