/*Description

	The "filtering_buffer" serves as the internal buffer utilized within the packet filter block. 
	It is instrumental in facilitating the storage of symbols for subsequent utilization or processing, 
	regardless of whether the operation is conducted in a 32 or one lane configuration.
*/

module Filtering_Buffer #(
    parameter SYMBOL_WIDTH			= 4'd8,  
    parameter FILTERED_DATA_Out_WIDTH 	= 'd31,
    parameter FILTERED_DATA_In_WIDTH 	= 'd30,
    parameter PACKET_LENGTH			= 'd11,    // in DW
    parameter SYMBOL_PTR_WIDTH 		= 'd5					// for framing buffer data_width && Last_Byte

)(
    input                                                     CLK,
    input                                                     RST_L, 
    input        [SYMBOL_PTR_WIDTH-1:0]                       address, // used when writing only one byte into the buffer
	input        [1:0]	                                      i_Data_W_Options,  // to determine the number of bytes to be written at a time (1,2 or 30)
    input                                                     i_Type,
    input                                                     i_SOP,
    input        [PACKET_LENGTH-1:0]                          i_Length,
    input                                                     i_Filter_Buff_ind_W_EN, i_Filter_Buff_SOP_W_EN,
    input                                                     i_Filter_Buff_Data_W_EN, 
    input        [0:FILTERED_DATA_In_WIDTH*SYMBOL_WIDTH-1]    i_Filter_Buff_Data,
    output logic [0:(FILTERED_DATA_Out_WIDTH)*SYMBOL_WIDTH-1] o_Filter_Buff_Data,
    output logic                                              o_SOP,
    output logic [PACKET_LENGTH-1:0]                          o_Length,
    output logic                                              o_Type
);

localparam [1:0]    ONE_BYTE 		= 'd0,
				    TWO_BYTES		= 'd1,
				    THIRTY_BYTES 	= 'd2;

logic      [0:255] 	Filter_Buff_Data;
integer i;


always_ff @(posedge CLK , negedge RST_L) begin
    if(!RST_L)begin
        Filter_Buff_Data <= 'd0;
        o_SOP <= 'd0;
        o_Length <= 'd0;
        o_Type <= 'd0;
    end
    else begin
	
		if (i_Filter_Buff_Data_W_EN) begin
			case (i_Data_W_Options)
				ONE_BYTE	: begin
					for (i = 0; i < SYMBOL_WIDTH ; i = i + 1)begin
						Filter_Buff_Data[address*SYMBOL_WIDTH + i] <= i_Filter_Buff_Data[i];
					end
				end
				
				TWO_BYTES	: begin
						Filter_Buff_Data[0:SYMBOL_WIDTH*2-1] <= i_Filter_Buff_Data[0:SYMBOL_WIDTH*2-1];
				end
				
				THIRTY_BYTES: begin
						Filter_Buff_Data[0:SYMBOL_WIDTH*30-1] <= i_Filter_Buff_Data;
				end
			endcase
		end
		
        if(i_Filter_Buff_SOP_W_EN)begin
            o_SOP <= i_SOP;
            
        end
		
		if(i_Filter_Buff_ind_W_EN)begin
			o_Length <= i_Length;
			o_Type <= i_Type;
		end
		
    end
end


assign 	o_Filter_Buff_Data = 	Filter_Buff_Data [0:(FILTERED_DATA_Out_WIDTH)*SYMBOL_WIDTH-1];

endmodule
