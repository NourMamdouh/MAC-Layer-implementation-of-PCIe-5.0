/*Description

	The RX Buffer occupies a terminal position within the MAC RX architecture, serving as the interface with the data link layer. 
	Its primary function is to store received packets following the deframing process, 
	thus enabling the delivery of data to the DLL in a manner consistent with how the DLL transmits data to the MAC layer on the transmit side.
	
*/

module Rx_Buffer #(
    parameter DATA_WIDTH = 256,
    parameter BUFFER_DEPTH = 8,
    parameter ADDR_WIDTH = 3,
    parameter PACKET_LENGTH	= 'd11,    // in DW
    parameter SYMBOL_PTR_WIDTH  = 'd5					// for framing buffer data_width && Last_Byte
)(
    input                            CLK,
    input                            RST_L,
    input                            i_WR_EN, i_RD_EN,
    input                            i_SOP1,i_End_Valid1,i_Type1,i_SOP2,i_End_Valid2,i_Type2,
    input                            i_512_valid,
    input [PACKET_LENGTH-1:0]        i_Length1,i_Length2,
    input [SYMBOL_PTR_WIDTH-1:0]     i_Last_Byte1,i_Last_Byte2,
    input [0:DATA_WIDTH-1]           Data_IN1,Data_IN2,
    input                            Soft_RST_blocks,
    output                           o_Empty , 
    output [0:DATA_WIDTH-1]          Data_Out,
    output                           o_SOP,o_End_Valid,o_Type,
    output [PACKET_LENGTH-1:0]       o_Length,
    output [SYMBOL_PTR_WIDTH-1:0]    o_Last_Byte
);
    // pointers
    logic [ADDR_WIDTH:0] wr_ptr , rd_ptr;
    // Memory 
    logic [0:(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 3)-1] mem [0:BUFFER_DEPTH-1];
    // loop counter
    integer i;
   
    //internal bus to join data and packet indicators to store them
    logic [0:(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 3)-1] i_Data_Join1;
    logic [0:(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 3)-1] i_Data_Join2;
    logic [0:(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 3)-1] o_Data_Join;

    assign i_Data_Join1 = {Data_IN1 , i_Last_Byte1 , i_Length1 , i_SOP1 , i_End_Valid1 , i_Type1};
    assign i_Data_Join2 = {Data_IN2 , i_Last_Byte2 , i_Length2 , i_SOP2 , i_End_Valid2 , i_Type2};

    // write operation
    always_ff @(posedge CLK , negedge RST_L) begin
        if(!RST_L)begin
            for(i = 0 ; i < BUFFER_DEPTH ; i = i+1)begin
                mem[i] <= 'd0;
            end
            wr_ptr <= 'd0;
        end
        else if (Soft_RST_blocks) begin
            for(i = 0 ; i < BUFFER_DEPTH ; i = i+1)begin
                mem[i] <= 'd0;
            end
            wr_ptr <= 'd0;
        end
        else if (i_WR_EN)begin
            if(i_512_valid)begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= i_Data_Join1;
                mem[wr_ptr[ADDR_WIDTH-1:0] + 1'b1] <= i_Data_Join2;
                wr_ptr <= wr_ptr +2;
            end
            else begin 
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= i_Data_Join1;
                wr_ptr <= wr_ptr + 1;
            end
        end
    end

    // read operation
   always_ff @(posedge CLK , negedge RST_L) begin
        if(!RST_L)begin
            rd_ptr <= 'd0;
        end
        else if (Soft_RST_blocks) begin
            rd_ptr <= 'd0;
        end
        else if (!o_Empty && i_RD_EN)begin
            rd_ptr <= rd_ptr +1;
        end
    end
    
    // Output Decleration
    assign o_Data_Join = mem[rd_ptr[ADDR_WIDTH-1:0]];
    assign Data_Out = o_Data_Join[0:DATA_WIDTH-1];
    assign o_Last_Byte = o_Data_Join[DATA_WIDTH:(DATA_WIDTH+SYMBOL_PTR_WIDTH)-1];
    assign o_Length = o_Data_Join[(DATA_WIDTH+SYMBOL_PTR_WIDTH):(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH)-1];
    assign o_SOP = o_Data_Join[(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH)];
    assign o_End_Valid = o_Data_Join[(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 1)];
    assign o_Type = o_Data_Join[(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 2)];

    // Empty and full decleration
    assign o_Empty = (wr_ptr == rd_ptr)?1'b1:1'b0;
endmodule
