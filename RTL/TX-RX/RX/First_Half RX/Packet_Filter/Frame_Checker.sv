/*Description

	The Frame Checker module is resposible for decoding the received token 
	to determine its classification as either an STP, SDP, IDL, EDS, or an invalid token.
*/

module Frame_Checker #(
parameter FRAME_DEPTH = 4,
parameter SYMBOL_WIDTH= 8
)(
input	logic	[0:(FRAME_DEPTH*SYMBOL_WIDTH-1)]	i_Token,
output	logic	[0:2]								o_Token_Type
);

localparam 									PACKET_LENGTH	= 11;
localparam 									STP_DEPTH		= 4;
localparam 									SDP_DEPTH		= 2;
localparam 									EDS_DEPTH		= 4;
////////////// SIZES//////////////
localparam 									STP_H_WIDTH		= 'd4;					// in bits 
localparam 									CRC_WIDTH		= 'd4;             		// in bits
/////////// TOKEN PARAMETERS///////////

localparam [STP_H_WIDTH-1:0] 				STP_H = 'b1111;

localparam [SYMBOL_WIDTH-1:0] 				SDP_0 = 'b1111_0000, 
											SDP_1 = 'b1010_1100;

localparam [SYMBOL_WIDTH-1:0] 				IDL = 'b0000_0000;

				
localparam [SYMBOL_WIDTH-1:0] 				EDS_0 = 'b0001_1111,
											EDS_1 = 'b1000_0000,
											EDS_2 = 'b1001_0000,
											EDS_3 = 'b0000_0000;
localparam	[0:EDS_DEPTH*SYMBOL_WIDTH-1]	EDS   = {EDS_0,EDS_1,EDS_2,EDS_3};

localparam [2:0]							STP_TOKEN = 'd0,
											SDP_TOKEN = 'd1,
											IDL_TOKEN = 'd2,
											EDS_TOKEN = 'd4,
											INVALID_TOKEN = 'd3;
								
logic	[0:(SDP_DEPTH*SYMBOL_WIDTH-1)]		SDP;



////////////////////////////////////////////////////// STP ///////////////////////////////////////////////

//wire declarations
logic [STP_H_WIDTH-1:0] 		STP_H_calc;
logic [SYMBOL_WIDTH-1:0] 		STP_0 ,STP_1,STP_2,STP_3;
logic 							frame_parity,TLP_Check, DLLP_Check, IDL_Check, EDS_Check;
logic 							frame_crc_0_calc, frame_crc_1_calc, frame_crc_2_calc, frame_crc_3_calc, frame_parity_calc;
logic [CRC_WIDTH-1:0]			frame_crc,frame_crc_calc;
logic [PACKET_LENGTH-1:0]		length;

assign STP_0 = i_Token[0:SYMBOL_WIDTH-1];
assign STP_1 = i_Token[SYMBOL_WIDTH:SYMBOL_WIDTH*2-1];
assign STP_2 = i_Token[SYMBOL_WIDTH*2:SYMBOL_WIDTH*3-1];
assign STP_3 = i_Token[SYMBOL_WIDTH*3:SYMBOL_WIDTH*4-1];

assign length = {STP_1[6:0],STP_0[7:4]};

assign frame_parity = STP_1[7];

assign frame_crc = STP_2[7:4];

assign STP_H_calc = STP_0[3:0];

// STP symbols preparation
assign frame_crc_0_calc = length[0] ^ length[1] ^length[2] ^length[4] ^length[6] ^length[7] ^length[10];
assign frame_crc_1_calc = length[2] ^ length[3] ^length[4] ^length[5] ^length[7] ^length[9] ^length[10];
assign frame_crc_2_calc = length[1] ^ length[2] ^length[3] ^length[4] ^length[6] ^length[8] ^length[9];
assign frame_crc_3_calc = length[0] ^ length[1] ^length[2] ^length[3] ^length[5] ^length[7] ^length[8];
assign frame_crc_calc = {frame_crc_3_calc,frame_crc_2_calc,frame_crc_1_calc,frame_crc_0_calc};
assign frame_parity_calc = (^length ) ^ (^frame_crc_calc) ;


assign TLP_Check = ((frame_crc==frame_crc_calc)&& (frame_parity==frame_parity_calc) && (length>'d4) && (STP_H_calc==STP_H))  ;


////////////////////////////////////////////////////// SDP ///////////////////////////////////////////////

assign SDP  = {SDP_0,SDP_1};
assign DLLP_Check  = (i_Token[0:SDP_DEPTH*SYMBOL_WIDTH-1] == SDP);

////////////////////////////////////////////////////// IDL ///////////////////////////////////////////////

assign IDL_Check = (i_Token == 'd0);

////////////////////////////////////////////////////// EDS ///////////////////////////////////////////////

assign EDS_Check = (i_Token == EDS);

////////////////////////////////////////////////////////

always_comb begin
case({TLP_Check,DLLP_Check,IDL_Check,EDS_Check})
	4'b1000: begin
			o_Token_Type = STP_TOKEN;
	end
	4'b0100: begin
			o_Token_Type = SDP_TOKEN;
	end
	4'b0010: begin
			o_Token_Type = IDL_TOKEN;
	end	
	4'b0001: begin
			o_Token_Type = EDS_TOKEN;
	end		
	default: begin
			o_Token_Type = INVALID_TOKEN;
	end
endcase
end

endmodule
