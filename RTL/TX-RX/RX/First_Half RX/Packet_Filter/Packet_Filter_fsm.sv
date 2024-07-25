/* Description

	-The Packet Filter Finite State Machine (FSM) serves as the overarching
	 controller within the packet filter architecture. It is entrusted with the pivotal task 
	 of overseeing and managing the diverse responsibilities inherent to the packet 
	 filter, thereby ensuring the seamless operation of the system.
	-Packet Filter Finite State Machine (FSM) States comprise seven distinct states, 
	 with certain states designated for a 32-lane configuration (Tokens_32 
	 and Data_32), while others are allocated for single-lane operation (Tokens_1 and 
	 Data_1). The remaining states are shared between both configurations (Reset, Check_Os, SKP). 

*/
///////////////////////////////////inputs and outputs//////////////////////////////
module Packet_Filter_fsm #(
parameter SYMBOL_WIDTH				= 'd8,           		  	// in bits
parameter PACKET_LENGTH				= 'd11,        			    // in DW
parameter SYMBOL_NUM_WIDTH			= 'd4, 								
parameter SYMBOL_PTR_WIDTH 			= 'd5,						// for framing buffer data_width && Last_Byte
parameter MAX_LANES					= (2**SYMBOL_PTR_WIDTH),    // max number of lanes
parameter FILTERED_DATA_In_WIDTH 	= 'd31,
parameter FILTERED_DATA_Out_WIDTH	= 'd30
)(
input	logic													CLK,RST_L,i_EN,
input	logic													i_Lanes,   			// 32 lanes or only one lane
// Byte Unstripping outputs 
input	logic	[0:(SYMBOL_WIDTH*MAX_LANES)-1]					i_RCV_Data,
input	logic													i_Block_Type,
// Token Checker outputs
input	logic	[2:0]											i_Token_Type,
// oredered sets related inputs
input	logic	[SYMBOL_NUM_WIDTH-1:0]							i_Symbol_Num,
// counter outputs
input	logic													i_CNT_Done,
input	logic	[SYMBOL_PTR_WIDTH-1:0]							i_Count,
// Filtering Buffer outputs
input 	logic 	[0:FILTERED_DATA_In_WIDTH*SYMBOL_WIDTH-1] 		i_Filter_Buff_Data,
input 	logic 													i_Filter_Buff_SOP,
input 	logic 	[PACKET_LENGTH-1:0] 							i_Filter_Buff_Length,
input 	logic 													i_Filter_Buff_Type,
input 	logic													Soft_RST_blocks,
// Filtered Data and RX Buffer inputs
output	logic													EIEOS_Flag,
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
output	logic													o_Error,   				//to be raised when an error is detected
// counter inputs
output	logic													o_CNT_EN,       // to enable counting up by one
output	logic													o_CNT_RST,      // active high reset
output	logic	[SYMBOL_PTR_WIDTH-1:0]							o_CNT_RST_VAL,   //counter start value
output	logic	[SYMBOL_PTR_WIDTH-1:0]							o_CNT_END_VAL,   //counter start value
// LTSSM RESET

// Filtering Buffer inputs 
output	logic 	[SYMBOL_PTR_WIDTH-1:0]							o_Filter_Buff_Adress,
output 	logic 													o_Filter_Buff_Type,
output 	logic 													o_Filter_Buff_Data_W_EN, o_Filter_Buff_Ind_W_EN, o_Filter_Buff_SOP_W_EN,    // to enable writing over buffered data or buffered indicators related ti the buffered data
output  logic   [1:0]                                           o_Filter_Buff_Data_W_Options,
output	logic	[0:FILTERED_DATA_Out_WIDTH*SYMBOL_WIDTH-1]		o_Filter_Buff_Data,
output	logic													o_Filter_Buff_SOP,
output	logic	[PACKET_LENGTH-1:0]								o_Filter_Buff_Length
);


////////////////////////////// important parameters //////////////////////////////
localparam [SYMBOL_NUM_WIDTH-1:0]			Last_Symbol		= 'd15;
localparam 									DLLP_DATA_DEPTH = 'd6;
localparam 									SEQ_NUM_DEPTH 	= 'd2;
localparam									BLOCK_TYPE_DATA = 1'b0;
localparam									BLOCK_TYPE_OS 	= 1'b1;
localparam 									EDS_DEPTH		= 4;
localparam 									STP_DEPTH		= 4;
localparam 									SDP_DEPTH		= 2;

localparam [SYMBOL_WIDTH-1:0] 				EDS_0			= 'b0001_1111,
											EDS_1 			= 'b1000_0000,
											EDS_2			= 'b1001_0000,
											EDS_3			= 'b0000_0000;									
localparam [0:(EDS_DEPTH*SYMBOL_WIDTH-1)] 	EDS  			= {EDS_0,EDS_1,EDS_2,EDS_3};

localparam [0:SYMBOL_WIDTH-1]				EIEOS_0 		= 'b0000_0000; // symbol0  in EIEOS

localparam [0:SYMBOL_WIDTH-1]				EIOS_0 			= 'b0110_0110; // symbol0  in EIOS

//localparam [0:SYMBOL_WIDTH-1]				SKP_0_GEN34		= 'b1010_1010; // symbol0  in SKP (8 or 16 GT/S)

localparam [0:SYMBOL_WIDTH-1]				SKP_0_GEN5		= 'b1001_1001; // symbol0  in SKP (32 or higher GT/s)

// to decode token checker output
localparam [2:0]							STP_TOKEN 		= 'd0,
											SDP_TOKEN 		= 'd1,
											IDL_TOKEN 		= 'd2,
											EDS_TOKEN 		= 'd4,
											INVALID_TOKEN 	= 'd3;
											
// lane configurations
localparam									lane_1 			='d0,
											Lane_32			='d1;
											
localparam [1:0] 							ONE_BYTE 		= 'd0,
											TWO_BYTES		= 'd1,
											THIRTY_BYTES 	= 'd2;											



//////////////////////////////state definitions //////////////////////////////
localparam [2:0] 							Reset			= 'b000,
											Tokens_32		= 'b001,
											Tokens_1		= 'b100,
											Data_32			= 'b011,
											Data_1			= 'b101,
											Check_Os		= 'b010,
											SKP				= 'b110;
					
					
					
///////////////////////extracted info from i_RCV_Data /////////////////////////
logic [SYMBOL_WIDTH-1:0] 				STP_0_32 ,STP_1_32,STP_2_32,STP_3_32,STP_0_1, STP_1_1,STP_2_1;
logic [PACKET_LENGTH-1:0] 				TLP_Length_32, TLP_Length_1; 
logic [SEQ_NUM_DEPTH*SYMBOL_WIDTH-1:0]	SEQ_Number_32, SEQ_Number_1;

// STP symbols when opearting with 32 lanes 
assign STP_0_32 = i_RCV_Data[0:SYMBOL_WIDTH-1];
assign STP_1_32 = i_RCV_Data[SYMBOL_WIDTH:SYMBOL_WIDTH*2-1];
assign STP_2_32 = i_RCV_Data[SYMBOL_WIDTH*2:SYMBOL_WIDTH*3-1];
assign STP_3_32 = i_RCV_Data[SYMBOL_WIDTH*3:SYMBOL_WIDTH*4-1];

// STP symbols when operating with 1 lane 
assign STP_0_1 = i_Filter_Buff_Data[0:SYMBOL_WIDTH-1];
assign STP_1_1 = i_Filter_Buff_Data[SYMBOL_WIDTH:SYMBOL_WIDTH*2-1];
assign STP_2_1 = i_Filter_Buff_Data[SYMBOL_WIDTH*2:SYMBOL_WIDTH*3-1];

//TLP whole length and sequence number when operating with 32 lanes
assign TLP_Length_32 = {STP_1_32[6:0],STP_0_32[7:4]};
assign SEQ_Number_32 = {STP_2_32[3:0],STP_3_32};	

//TLP whole length and sequence number when operating with 1 lane
assign TLP_Length_1 = {STP_1_1[6:0],STP_0_1[7:4]};
assign SEQ_Number_1 = {STP_2_1[3:0],i_RCV_Data[0:SYMBOL_WIDTH-1]};		



/////////////////necessary calculations for error checking /////////////////////////
logic  [PACKET_LENGTH-1:0]						current_TLP_Length,next_TLP_Length;
logic 											Length_W_EN ;
logic [0:(MAX_LANES-EDS_DEPTH)*SYMBOL_WIDTH-1] 	Data_Info;
logic [0:7]										shifted_bits_1, shifted_bits_2;  // max no of bits to be shifted = 28*8 = 224
logic 											Token_No_ERR_Check;
logic											Data_No_ERR_Check;

assign shifted_bits_1 = ((TLP_Length_32[2:0])*'d4*SYMBOL_WIDTH);
assign shifted_bits_2 = ((current_TLP_Length[2:0])*'d4*SYMBOL_WIDTH);

assign Data_Info = i_RCV_Data[0:(MAX_LANES-EDS_DEPTH)*SYMBOL_WIDTH-1];

assign Token_No_ERR_Check = ((Data_Info << shifted_bits_1 ) =='d0 ) ;
assign Data_No_ERR_Check = ((Data_Info << shifted_bits_2) =='d0 ) ;




///////////////////state transitions and TLP length calculations //////////////////////////////////
logic 	   [2:0]				current_state,next_state;

always_ff @(posedge CLK,negedge RST_L)begin
	if(!RST_L)begin
		current_state <= Reset;
		current_TLP_Length <= 'd0;
	end
	else if (Soft_RST_blocks)begin
		current_state <= Reset;
	end
	else begin
		current_state <= next_state;
		if(Length_W_EN)begin
			current_TLP_Length <= next_TLP_Length;
		end
	end
end



//////////////////////next_state and output logic///////////////////////////////
integer i;
always_comb begin

// output default values
	o_Filtered_Data1		 = 'd0;
	o_Filtered_Data2		 = 'd0;
	o_SOP1					 = 'd0;
	o_SOP2 					 = 'd0;
	o_Last_Byte1			 = 'd31;
	o_Last_Byte2			 = 'd31;
	o_End_Valid1			 = 'd0;
	o_End_Valid2			 = 'd0;
	o_Type1 				 = 'd0;
	o_Type2 				 = 'd0;
	o_Length1 			 	 = 'd0;
	o_Length2			 	 = 'd0;
	o_Rx_Buff_W_EN		 	 = 'd0;
	o_Rx_Buff_valid_2	 	 = 'd0;	
	
	o_Error				 	 = 'd0;
	o_CNT_EN				 = 'd0;
	o_CNT_RST				 = 'd0;
	o_CNT_RST_VAL		   	 = 'd0;
	o_CNT_END_VAL			 = 'd0;
	
	o_Filter_Buff_Adress	 = 'd0;
	o_Filter_Buff_SOP		 = 'd0;
	o_Filter_Buff_Length	 = 'd0;
	o_Filter_Buff_Type	 = 'd0;
	o_Filter_Buff_Data_W_EN= 'd0;
	o_Filter_Buff_Ind_W_EN = 'd0; 
	o_Filter_Buff_SOP_W_EN = 'd0;
	o_Filter_Buff_Data_W_Options = 'd0;
	o_Filter_Buff_Data	 = 'd0;
	EIEOS_Flag = 'd0;
	
	next_TLP_Length			 = 'd0;
	Length_W_EN         	 = 'd0;
	
	next_state				 = Reset ;
	
	case (current_state)
	
		Reset:		begin
						o_CNT_RST = 'd1;
						if(i_EN)begin    	 //take care of when enable is asserted (otherwise it should be combined with Tokens_32)
							if(i_Lanes== Lane_32)begin
								next_state = Tokens_32;
							end
							else begin
								next_state = Tokens_1;
							end
						end
						else begin
							next_state = Reset;    
						end
					end
		
		
		Tokens_32:		begin   
		
						o_SOP1 = 'd1;
						next_TLP_Length = TLP_Length_32-8;
						o_Filter_Buff_Length = TLP_Length_32 - 'd2;
						if(i_EN)begin
							case({i_Token_Type,i_Block_Type})
								{STP_TOKEN,BLOCK_TYPE_DATA}: begin // TLP 
								
									o_Type1 = 1;
									o_Last_Byte1 =  TLP_Length_32*4 - 3;
									o_Length1 = TLP_Length_32 - 'd2;
									
									if(TLP_Length_32 > 8 )begin  // not fit in one location
										next_state = Data_32;
										Length_W_EN = 'd1;
										o_Filter_Buff_Data_W_EN = 'd1;
										o_Filter_Buff_Ind_W_EN = 'd1;
										o_Filter_Buff_SOP_W_EN = 'd1;
										o_Filter_Buff_Data_W_Options = THIRTY_BYTES;
										o_Filter_Buff_SOP = 'd1;
								//		o_Filter_Buff_Adress = 'd0;
										o_Filter_Buff_Data = {SEQ_Number_32 , i_RCV_Data[32:255]};
									end
									else begin // small packet
										if((i_RCV_Data[224:255] == 0 && Token_No_ERR_Check) || (TLP_Length_32=='d8) ) begin  // small packet without EDS
											next_state = Tokens_32;
											o_Filtered_Data1 = {SEQ_Number_32 , i_RCV_Data[32:255] , {(2*SYMBOL_WIDTH){1'b0}}};
											o_Rx_Buff_W_EN = 1;
											o_End_Valid1 = 1;
											
										end
										else if(i_RCV_Data[224:255] == EDS && i_Symbol_Num == Last_Symbol && Token_No_ERR_Check)begin // small packet with EDS
											next_state = Check_Os;
											o_Filtered_Data1 = {SEQ_Number_32 , i_RCV_Data[32:223] , {(6*SYMBOL_WIDTH){1'b0}}};
											o_Rx_Buff_W_EN = 1;
											o_End_Valid1 = 1;
										end
										else begin 
											next_state = Reset;
											o_Error = 1;
										end
									end
								end 
								{SDP_TOKEN,BLOCK_TYPE_DATA}: begin
									o_Type1 = 0;
									o_Last_Byte1 = 5;
									o_End_Valid1 = 1;
									
									if(i_RCV_Data[224:255] == EDS && i_Symbol_Num == Last_Symbol && (i_RCV_Data[8*SYMBOL_WIDTH:223]=='d0) )begin // small packet with EDS // ab3tlo length el DLLP wla la2
										next_state = Check_Os;
										o_Filtered_Data1 = { i_RCV_Data[16:223] , {(6*SYMBOL_WIDTH){1'b0}}};
										o_Rx_Buff_W_EN = 1;
									end
									else if (i_RCV_Data[8*SYMBOL_WIDTH:255] == 0)begin // small packet without idles
										next_state = Tokens_32;
										o_Filtered_Data1 = {i_RCV_Data[16:255] , {(2*SYMBOL_WIDTH){1'b0}}};
										o_Rx_Buff_W_EN = 1;
									end
									else begin // frame ERROR
										next_state = Reset;
										o_Error = 1;
									end
								end
								{IDL_TOKEN,BLOCK_TYPE_DATA}:begin
									if(i_RCV_Data[224:255] == EDS && i_Symbol_Num == Last_Symbol && i_RCV_Data[4*SYMBOL_WIDTH:223] == 0 )begin // small packet with EDS
										next_state = Check_Os;
									end
									else if (i_RCV_Data[4*SYMBOL_WIDTH:255] == 0)begin // small packet without idles
										next_state = Tokens_32;
									end
									else begin // frame ERROR
										next_state = Reset;
										o_Error = 1;
									end
								end
								default:begin  //invalid token || os
										next_state = Reset;
										o_Error = 1;
								end

							endcase
						end 
						else begin
							next_state = Tokens_32;
						end
						
					end	
				
				
		Data_32:		begin
						if ((current_TLP_Length <= 'd8) && i_EN || (i_Block_Type==BLOCK_TYPE_OS )) // TLP is finished Or ERROR
							if(((Data_No_ERR_Check && (i_RCV_Data[(MAX_LANES-EDS_DEPTH)*SYMBOL_WIDTH : MAX_LANES*SYMBOL_WIDTH-1] == 'd0)) || (current_TLP_Length == 'd8)) && (i_Block_Type==BLOCK_TYPE_DATA) ) begin  
								o_Filtered_Data1	 = {i_Filter_Buff_Data[0:FILTERED_DATA_Out_WIDTH*SYMBOL_WIDTH-1],i_RCV_Data[0:(MAX_LANES-FILTERED_DATA_Out_WIDTH)*SYMBOL_WIDTH-1]};
								o_Filtered_Data2	 = {i_RCV_Data[(MAX_LANES-FILTERED_DATA_Out_WIDTH)*SYMBOL_WIDTH : MAX_LANES*SYMBOL_WIDTH-1],{((MAX_LANES-FILTERED_DATA_Out_WIDTH)*SYMBOL_WIDTH){1'b0}}};
								o_SOP1				 = i_Filter_Buff_SOP;
								o_Last_Byte2		 = current_TLP_Length*'d4-'d3;  // *4 to change to length in bytes,
								o_End_Valid2		 = 'd1;
								o_Type1 			 = 'd1;
								o_Type2 			 = 'd1;
								o_Length1 			 = i_Filter_Buff_Length;
								o_Length2			 = i_Filter_Buff_Length;
								o_Rx_Buff_W_EN		 = 'd1;
								o_Rx_Buff_valid_2	 = 'd1;		
								next_state			 = Tokens_32 ;

							end
							else if ((Data_No_ERR_Check && (i_RCV_Data[(MAX_LANES-EDS_DEPTH)*SYMBOL_WIDTH : MAX_LANES*SYMBOL_WIDTH-1] == EDS) && (i_Symbol_Num == Last_Symbol))) begin  //an os is to be followed
								o_Filtered_Data1	 = {i_Filter_Buff_Data[0:FILTERED_DATA_Out_WIDTH*SYMBOL_WIDTH-1],i_RCV_Data[0:(MAX_LANES-FILTERED_DATA_Out_WIDTH)*SYMBOL_WIDTH-1]};
								o_Filtered_Data2	 = {i_RCV_Data[(MAX_LANES-FILTERED_DATA_Out_WIDTH)*SYMBOL_WIDTH : (MAX_LANES-EDS_DEPTH)*SYMBOL_WIDTH-1],{((MAX_LANES-FILTERED_DATA_Out_WIDTH+EDS_DEPTH)*SYMBOL_WIDTH){1'b0}}};
								o_SOP1				 = i_Filter_Buff_SOP;
								o_Last_Byte2		 = current_TLP_Length*'d4-'d3;  // *4 to change to length in bytes,
								o_End_Valid2		 = 'd1;
								o_Type1 			 = 'd1;
								o_Type2 			 = 'd1;
								o_Length1 			 = i_Filter_Buff_Length;
								o_Length2			 = i_Filter_Buff_Length;
								o_Rx_Buff_W_EN		 = 'd1;
								o_Rx_Buff_valid_2	 = 'd1;		
								next_state			 = Check_Os ;
							end
							else begin	// a reciever error has occurred
								o_Error = 'd1;
								next_state = Reset;
							end
						else begin
							o_Filtered_Data1	 = {i_Filter_Buff_Data[0:FILTERED_DATA_Out_WIDTH*SYMBOL_WIDTH-1],i_RCV_Data[0:(MAX_LANES-FILTERED_DATA_Out_WIDTH)*SYMBOL_WIDTH-1]};
							o_SOP1				 = i_Filter_Buff_SOP;
							o_Type1 			 = 'd1;  //TLP
							o_Length1 			 = i_Filter_Buff_Length;
							o_Rx_Buff_W_EN		 = i_EN;
							o_Filter_Buff_Data	 = i_RCV_Data[(MAX_LANES-FILTERED_DATA_Out_WIDTH)*SYMBOL_WIDTH : MAX_LANES*SYMBOL_WIDTH-1];
							o_Filter_Buff_SOP	 = 'd0;
							o_Filter_Buff_SOP_W_EN	 = i_EN;
							o_Filter_Buff_Data_W_EN	 = i_EN;
							o_Filter_Buff_Data_W_Options = THIRTY_BYTES;
							next_TLP_Length		 = current_TLP_Length-'d8;
							Length_W_EN          = i_EN;
							next_state			 = Data_32 ;							
						end
					end	
					
		Tokens_1:	begin
				
						if((i_Count == 0 && i_RCV_Data[0:SYMBOL_WIDTH-1] == 'd0) || i_EN == 0)begin // IDL Token or no enable
							next_state = Tokens_1;
						end
						else begin // not IDL
							if(i_Count != 3)begin // storing Tokens
								next_state = Tokens_1;
								o_CNT_EN = 'd1;
								o_Filter_Buff_Data_W_EN = 'd1;
								o_Filter_Buff_Data_W_Options = ONE_BYTE;
								o_Filter_Buff_Data = {i_RCV_Data[0:SYMBOL_WIDTH-1],{ ((FILTERED_DATA_Out_WIDTH-1)*SYMBOL_WIDTH) {1'b0}}};
								o_Filter_Buff_Adress = i_Count;
							end
							else begin
								case ({i_Token_Type,i_Block_Type})
									{STP_TOKEN,BLOCK_TYPE_DATA}: begin // TLP Token
										next_state = Data_1;
										o_Filter_Buff_Ind_W_EN = 'd1;
										o_Filter_Buff_Length = TLP_Length_1 -'d2;
										o_Filter_Buff_Type = 'd1;
										o_Filter_Buff_SOP_W_EN = 'd1;
										o_Filter_Buff_SOP = 'd1;
										o_Filter_Buff_Data_W_EN = 'd1;
										o_Filter_Buff_Adress = 'd0;
										o_Filter_Buff_Data_W_Options = TWO_BYTES;
										o_Filter_Buff_Data = {SEQ_Number_1,{((FILTERED_DATA_Out_WIDTH-SEQ_NUM_DEPTH)*SYMBOL_WIDTH) {1'b0}}};
										o_CNT_RST = 'd1;
										o_CNT_RST_VAL = 'd2;
										Length_W_EN = 'd1;
										next_TLP_Length = TLP_Length_1;
									end
									{SDP_TOKEN,BLOCK_TYPE_DATA}: begin // DLLP Token
										next_state = Data_1;
										o_Filter_Buff_Ind_W_EN = 'd1; // no length stored
										o_Filter_Buff_Type = 'd0;
										o_Filter_Buff_SOP_W_EN = 'd1;
										o_Filter_Buff_SOP = 'd1;
										o_Filter_Buff_Data_W_EN = 'd1;
										o_Filter_Buff_Adress = 'd0;
										o_Filter_Buff_Data_W_Options = TWO_BYTES;
										o_Filter_Buff_Data = {i_Filter_Buff_Data[SYMBOL_WIDTH*SDP_DEPTH:3*SYMBOL_WIDTH-1],i_RCV_Data[0:SYMBOL_WIDTH-1],{ ((FILTERED_DATA_Out_WIDTH-SDP_DEPTH)*SYMBOL_WIDTH) {1'b0}}};
										o_CNT_RST = 'd1;
										o_CNT_RST_VAL = 'd2;
										Length_W_EN = 'd1;
										next_TLP_Length = 'd2;
									end
									{EDS_TOKEN,BLOCK_TYPE_DATA}: begin // EDS Token
										o_CNT_RST = 'd1;
										o_CNT_RST_VAL = 'd0;
										if(i_Symbol_Num == Last_Symbol)begin // EDS in correct position
											next_state = Check_Os;
										end
										else begin // EDS is within the block not in the End of the block
											next_state = Reset;
											o_Error = 'd1;
										end
									end
									default: begin // Errors
										o_CNT_RST = 'd1;
										o_CNT_RST_VAL = 'd0;
										next_state = Reset;
										o_Error = 'd1;
									end
								endcase
							end
						end
					end
					
		Data_1:		begin 
							
						next_TLP_Length = current_TLP_Length - 'd8;
						
						o_Filter_Buff_Adress = i_Count;
						o_Filter_Buff_SOP	   = 'd0;
						o_Filter_Buff_Data[0:SYMBOL_WIDTH-1] = i_RCV_Data[0:SYMBOL_WIDTH-1];
						o_Filter_Buff_Data_W_Options = ONE_BYTE;
						
						o_Filtered_Data1 = {i_Filter_Buff_Data,{((MAX_LANES-FILTERED_DATA_In_WIDTH)*SYMBOL_WIDTH){1'b0}}};
							for (i=0;i<SYMBOL_WIDTH; i=i+1)begin
								o_Filtered_Data1 [(i_Count)*SYMBOL_WIDTH + i] = i_RCV_Data[i];
							end
						

						//o_Filtered_Data1 [0:SYMBOL_WIDTH-1]= i_RCV_Data[0:SYMBOL_WIDTH-1];
						o_Last_Byte1 = current_TLP_Length*'d4-'d3;
						o_Length1 = i_Filter_Buff_Length;
						o_SOP1 = i_Filter_Buff_SOP;
						o_Type1 = i_Filter_Buff_Type;
						
						if (i_Block_Type == BLOCK_TYPE_DATA)begin
							if(current_TLP_Length <= 'd8) begin
								o_CNT_END_VAL = current_TLP_Length*'d4 - 'd3  ;
								o_End_Valid1 = 1;
							end
							else begin
								o_CNT_END_VAL = 'd31 ;
								o_End_Valid1 = 'd0;
							end
							
							
							if((current_TLP_Length <= 'd8) && i_CNT_Done && i_EN) begin
								next_state = Tokens_1;
								o_CNT_RST = 'd1;
								//
							end
							else begin
								next_state = Data_1;
								o_CNT_EN = i_EN;
							end
							
							
							if(i_CNT_Done && i_EN) begin
								o_Filter_Buff_SOP_W_EN = 'd1; 
								o_Rx_Buff_W_EN = 'd1;					
								Length_W_EN = 'd1;							
							end
							else begin
								o_Filter_Buff_Data_W_EN = i_EN;
							end
						end
						else begin
							next_state = Reset;
							o_Error = 'd1;
						end
						
					end					
					
		Check_Os:	begin
						if (i_EN) begin
							case({i_RCV_Data[0:SYMBOL_WIDTH-1],i_Block_Type})
								{SKP_0_GEN5,BLOCK_TYPE_OS} : begin
									next_state = SKP;
								end
								{EIOS_0,BLOCK_TYPE_OS}:begin
									next_state = Reset;  //Data_32 transmission is done
								end
								{EIEOS_0,BLOCK_TYPE_OS}: begin
									next_state = Reset;  //Data_32 transmission is done
									EIEOS_Flag = 1'b1;
								end	
								default													: begin  // block type is not os or any other os other than skp,EIEOS, EIOS
									o_Error = 'd1;
									next_state = Reset;
								end
							endcase
						end 
						else begin
							next_state = Check_Os;
						end
					end	
					
					
		SKP	:		begin
						if((i_Symbol_Num == Last_Symbol) && i_EN)begin  
							if(i_Lanes== Lane_32)begin
								next_state = Tokens_32;
							end
							else begin
								next_state = Tokens_1;
							end
						end
						else begin
							next_state = SKP;
						end
					end						
	endcase
	
end


endmodule
