/*	FSM_32 is required to control Framing Data in case 32 lane as it’s responsible to out the final Form of data framed by Tokens and 
	out the Fram Sel to out Data or out OS’s in case there’s OS’s need to be sent or IDLES in case there’s no ready Data nor OS’s.*/
	
module Framing_fsm #(
parameter SYMBOL_WIDTH		= 'd8,           		  	// in bits
parameter PACKET_LENGTH		= 'd11,        			    // in DW
parameter SYMBOL_NUM_WIDTH	= 'd4, 								
parameter SYMBOL_PTR_WIDTH  = 'd5,						// for framing buffer data_width && Last_Byte
parameter MAX_LANES			= (2**SYMBOL_PTR_WIDTH),    // max number of lanes
parameter EDS_DIPTH			= 4, 
parameter STP_DIPTH			= 4, 
parameter SDP_DIPTH			= 2,
parameter FRAMING_DATA_WIDTH= SYMBOL_WIDTH*2
)(
input	wire									CLK,RST_L,i_EN,
// Tx Buffer outputs
input	wire	[0:(SYMBOL_WIDTH*MAX_LANES)-1]	i_Buffer_Data,
input	wire									i_SOP,
input	wire	[SYMBOL_PTR_WIDTH-1:0]			i_Last_Byte,
input	wire									i_End_Valid,
input	wire									i_Type,
input	wire	[PACKET_LENGTH-1:0]				i_Length,
input	wire									i_Buffer_Empty,
// Framming Buffer outputs
input	wire	[0:FRAMING_DATA_WIDTH-1]		i_Fram_Buff_Data,
//input	wire	[SYMBOL_PTR_WIDTH-1:0]			i_Data_Width,
// Framing Tokens
input	wire	[0:(SDP_DIPTH*SYMBOL_WIDTH-1)]	i_SDP,
input	wire	[0:(STP_DIPTH*SYMBOL_WIDTH-1)]	i_STP,
input	wire	[0:(EDS_DIPTH*SYMBOL_WIDTH-1)]	i_EDS,
input	wire	[0:(SYMBOL_WIDTH-1)]			i_IDL,
// oredered sets related inputs
input	wire									i_Os_Enable,
input	wire	[SYMBOL_NUM_WIDTH-1:0]			i_Symbol_Num,
// Tx Buffer inputs
output	logic										o_Buffer_R_EN,
// Framming Buffer inputs
output	logic		[0:FRAMING_DATA_WIDTH-1]		o_Fram_Buff_Data,
//output	logic		[SYMBOL_PTR_WIDTH-1:0]			o_Data_Width,
output	logic										o_Fram_Buff_W_EN,
// general outputs
output	logic										o_Idle_Indicator,   //raised one when sending idles (no more TLPs or DLLPs to send)
output	logic										o_Sync_Sel,			// to be used for sync header insertion
// costructed data 
output	logic		[0:(SYMBOL_WIDTH*MAX_LANES)-1]	o_Framed_Data,
output	logic		[1:0]							o_Fram_Sel

);

/////////////////////important parameters ////////////////////////
localparam [SYMBOL_NUM_WIDTH-1:0]	Last_Symbol = 'd15;
localparam 							DLLP_DATA_DIPTH = 'd6;
localparam 							SEQ_NUM_DIPTH = 'd2;
localparam							SYNC_H_DATA = 'd0;
localparam							SYNC_H_OS = 'd1;
// FRAMING SELECTION
localparam IDLE = 'b00;
localparam OS = 'b01;
localparam FRAM_32 = 'b10;
localparam FRAM_1= 'b11;



/////////////////////state definitions ////////////////////////
localparam [2:0] 	Reset		= 'b000,
					Send_Os		= 'b001,
					Idle_S_Pkt	= 'b011,
					L_Pkt		= 'b010,
					Idle_To_End	= 'b110;
					
					
					
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
always_comb begin

// output default values
	o_Buffer_R_EN		= 'd0;
	o_Idle_Indicator	= 'd0;
	o_Sync_Sel			= 'd0;
	o_Framed_Data		= 'd0;
	o_Fram_Buff_Data	= 'd0;
//	o_Data_Width		= 'd0;
	o_Fram_Buff_W_EN	= 'd0;
	o_Fram_Sel			= 'd0;
	next_state 			= Reset ;
	
	case (current_state)
	
		Reset:		begin
						if (i_EN && i_Os_Enable) begin
							next_state = Send_Os;
							o_Fram_Sel = OS;
							o_Sync_Sel = SYNC_H_OS;
						end
						else begin
							next_state = Reset;
							o_Fram_Sel = IDLE;
							o_Sync_Sel = SYNC_H_DATA;
						end
					end
		
		
		Send_Os:	begin
						o_Fram_Sel = OS;
						o_Sync_Sel = SYNC_H_OS;
						if ((i_Os_Enable == 'd0) && i_EN) begin
							next_state = Idle_S_Pkt;
						end
						else begin
							next_state = Send_Os;
						end
					end	
				
				
		Idle_S_Pkt:	begin
						o_Sync_Sel = SYNC_H_DATA;
						if (i_Os_Enable && (i_Symbol_Num == Last_Symbol) && i_EN) begin
							next_state = Send_Os;
							o_Fram_Sel = FRAM_32;
							if (!i_Buffer_Empty && (i_Type==0)) begin  //DLLP
								o_Framed_Data = {i_SDP,i_Buffer_Data[0:DLLP_DATA_DIPTH*SYMBOL_WIDTH-1],{(MAX_LANES-(DLLP_DATA_DIPTH+SDP_DIPTH)-EDS_DIPTH){i_IDL}},i_EDS };
								o_Buffer_R_EN = 'd1;
							end
							else if (!i_Buffer_Empty && i_Length <= 'd5) begin
								o_Framed_Data = {i_STP,i_Buffer_Data[SEQ_NUM_DIPTH*SYMBOL_WIDTH:((MAX_LANES-(STP_DIPTH-SEQ_NUM_DIPTH)-EDS_DIPTH)*SYMBOL_WIDTH) - 1],i_EDS};
								o_Buffer_R_EN = 'd1;
							end
							else begin
								o_Framed_Data = {{(MAX_LANES-EDS_DIPTH){i_IDL}},i_EDS};
							end
						end
						else begin
							if (i_Buffer_Empty || !i_EN || (i_Type==0)) begin
								next_state = Idle_S_Pkt ; 
								if (i_Buffer_Empty || !i_EN ) begin  //DLLP
									o_Idle_Indicator = 'd1;
									o_Fram_Sel = IDLE;
								end
								else begin   //i_Type==0
									o_Framed_Data = {i_SDP,i_Buffer_Data[0:DLLP_DATA_DIPTH*SYMBOL_WIDTH-1],{(MAX_LANES-(DLLP_DATA_DIPTH+SDP_DIPTH)){i_IDL}}};    //packet [0:6*8-1], {20{i_IDL}},EDS}ك
									o_Fram_Sel = FRAM_32;
									o_Buffer_R_EN = 'd1;
								end
							end
							else if (i_Os_Enable && (i_Length > ('d125-(i_Symbol_Num<<3)) ))  begin //couldn't be started
								o_Fram_Sel = IDLE;
								next_state = Idle_To_End;
							end
							else if (i_End_Valid) begin // length<=30 bytes
								o_Framed_Data = {i_STP,i_Buffer_Data[SEQ_NUM_DIPTH*SYMBOL_WIDTH:((MAX_LANES-(STP_DIPTH-SEQ_NUM_DIPTH))*SYMBOL_WIDTH) - 1]}; //STP+packet1[2:EOP1]+idles   //out= (packet[2*8:32*8-1] >> 2*8 ), out[0:4*8-1] = stp;  // or out = {stp,packet[2*8:30*8-1]}
								o_Fram_Sel = FRAM_32;
								o_Buffer_R_EN = 'd1;
								next_state = Idle_S_Pkt;
							end
							else begin
								o_Framed_Data = {i_STP,i_Buffer_Data[SEQ_NUM_DIPTH*SYMBOL_WIDTH:((MAX_LANES-(STP_DIPTH-SEQ_NUM_DIPTH))*SYMBOL_WIDTH) - 1]};//stp+packet1[2:29]  //out = {stp,packet[2*8:30*8-1]}
								o_Fram_Sel = FRAM_32;
								o_Buffer_R_EN = 'd1;
								o_Fram_Buff_Data = i_Buffer_Data[((MAX_LANES-(STP_DIPTH-SEQ_NUM_DIPTH))*SYMBOL_WIDTH):(MAX_LANES*SYMBOL_WIDTH)-1];
								o_Fram_Buff_W_EN = 'd1;
								next_state = L_Pkt;
							end
						end
					end	
					
					
		L_Pkt:		begin
						o_Sync_Sel = SYNC_H_DATA;
						o_Idle_Indicator = 0;
						o_Fram_Buff_Data = i_Buffer_Data[(255-16)+1:255];
						o_Buffer_R_EN = i_EN;
						o_Fram_Sel = FRAM_32;
						if (i_EN) begin
							if(i_End_Valid || i_Buffer_Empty)begin
								o_Fram_Buff_W_EN = 0;
								if((i_Symbol_Num == Last_Symbol) && (i_Os_Enable == 1) && (((i_Last_Byte + 1) + 2 + 4) <= 32)  )begin // ready ordered sets and symbol 15
									next_state = Send_Os;
									o_Framed_Data = {i_Fram_Buff_Data[0:15] , i_Buffer_Data[0:(255-32-16)] , i_EDS};									
								end
								else begin // any symbol except symbol 15 or no ordered sets
									next_state = Idle_S_Pkt;
									o_Framed_Data = {i_Fram_Buff_Data[0:15] , i_Buffer_Data[0:(255-16)]};
								end
							end
							else begin // not End of packet or Start of Packet
									next_state = L_Pkt;
									o_Framed_Data = {i_Fram_Buff_Data[0:15] , i_Buffer_Data[0:(255-16)]};
									o_Fram_Buff_W_EN = 1;
							end
						end
						else begin
							next_state = L_Pkt;
						end
					end	
					
					
		Idle_To_End:begin
						o_Sync_Sel = SYNC_H_DATA;
						if(i_Symbol_Num == Last_Symbol && i_EN)begin
							next_state = Send_Os;
							o_Framed_Data = { {(MAX_LANES-EDS_DIPTH){i_IDL}}, i_EDS };
							o_Fram_Sel = FRAM_32;
						end
						else begin // any symbol except symbol 15
							next_state = Idle_To_End;
							o_Fram_Sel = IDLE;
						end	
					end						
	endcase
	
	
end
endmodule








