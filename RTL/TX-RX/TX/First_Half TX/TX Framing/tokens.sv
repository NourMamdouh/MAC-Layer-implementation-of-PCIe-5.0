/*	Tokens is required to form the tokens of packets (STP – SDP – EDS – IDLES) as these tokens is divided into fields that need 
	some logic to calculate it like Frame CRC or Frame Parity and so on.*/
///////////////////////////////////////////Tokens construction ///////////////////////////////////////
module tokens #(
parameter SEQ_NUM_WIDTH	= 12,
parameter SYMBOL_WIDTH	= 8,
parameter PACKET_LENGTH	= 11, 
parameter EDS_DIPTH		= 4, 
parameter STP_DIPTH		= 4, 
parameter SDP_DIPTH		= 2)
(
input	logic	[PACKET_LENGTH-1:0]				i_Length,
input	logic	[SEQ_NUM_WIDTH-1:0]				i_Sequence_number,
output	logic	[0:(SDP_DIPTH*SYMBOL_WIDTH-1)]	o_SDP,
output	logic	[0:(STP_DIPTH*SYMBOL_WIDTH-1)]	o_STP,
output	logic	[0:(EDS_DIPTH*SYMBOL_WIDTH-1)]	o_EDS,
output	logic	[0:(SYMBOL_WIDTH-1)]			o_IDL
);

////////////// SIZES//////////////
localparam STP_H_WIDTH		= 'd4;					// in bits 
localparam CRC_WIDTH		= 'd4;             		// in bits
localparam TOKEN_NUM        = 'd4;


/////////// TOKEN PARAMETERS///////////

localparam [STP_H_WIDTH-1:0] 	STP_H = 'b1111;

localparam [SYMBOL_WIDTH-1:0] 	SDP_0 = 'b1111_0000, 
								SDP_1 = 'b1010_1100;
				
localparam [SYMBOL_WIDTH-1:0] 	EDS_0 = 'b0001_1111,
								EDS_1 = 'b1000_0000,
								EDS_2 = 'b1001_0000,
								EDS_3 = 'b0000_0000;
				
localparam [SYMBOL_WIDTH-1:0] 	IDL = 'b0000_0000;

////////////////////////////////////////////////////// STP ///////////////////////////////////////////////

//logic declarations
logic [SYMBOL_WIDTH-1:0] 		STP_0 ,STP_1,STP_2,STP_3;
logic 							frame_crc_0, frame_crc_1, frame_crc_2, frame_crc_3, frame_parity;
logic [CRC_WIDTH-1:0]			frame_crc;
logic [PACKET_LENGTH-1:0]		length;

// STP symbols preparation
assign length = i_Length + 'd2 ;	
assign frame_crc_0 = length[0] ^ length[1] ^length[2] ^length[4] ^length[6] ^length[7] ^length[10];
assign frame_crc_1 = length[2] ^ length[3] ^length[4] ^length[5] ^length[7] ^length[9] ^length[10];
assign frame_crc_2 = length[1] ^ length[2] ^length[3] ^length[4] ^length[6] ^length[8] ^length[9];
assign frame_crc_3 = length[0] ^ length[1] ^length[2] ^length[3] ^length[5] ^length[7] ^length[8];
assign frame_crc = {frame_crc_3,frame_crc_2,frame_crc_1,frame_crc_0};
assign frame_parity = (^length ) ^ (^frame_crc) ;

// STP symbols construction
assign STP_0 = {length[3:0],STP_H};
assign STP_1 = {frame_parity,length[10:4]};
assign STP_2 = {frame_crc,i_Sequence_number[11:8]};
assign STP_3 = i_Sequence_number[7:0];
assign o_STP = {STP_0,STP_1,STP_2,STP_3};

////////////////////////////////////////////////////// SDP ///////////////////////////////////////////////

assign o_SDP  = {SDP_0,SDP_1};

////////////////////////////////////////////////////// EDS ///////////////////////////////////////////////

assign o_EDS  = {EDS_0,EDS_1,EDS_2,EDS_3};

////////////////////////////////////////////////////// IDL ///////////////////////////////////////////////

assign o_IDL  = IDL;


endmodule
