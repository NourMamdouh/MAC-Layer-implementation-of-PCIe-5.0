/*	This Buffer is a Sync FIFO that required to allow for continuous flow of data from DLL even when physical layer is busy sending OSs, 
    and to accommodate for the halting resulting from 128b/130b encoding scheme and the insertion of framing tokens for each packet
    received from DLL.The size of Buffer contain width (32 Byte (Data) + 19 bits (packet indicators)) and depth 16 location that 
    calculated according to 16 cycle for sending SKP Symbols as no need to stop DLL this long period although we can halt them in other 
    situations if the Buffer is full.
*/

module Interface_Buffer #(
    parameter DATA_WIDTH        = 256,
    parameter BUFFER_DEPTH      = 16,
    parameter ADDR_WIDTH        = 4,
    parameter PACKET_LENGTH     = 'd11,    // in DW
    parameter SYMBOL_PTR_WIDTH  = 'd5					// for framing buffer data_width && Last_Byte
)(
    input                           CLK,
    input                           RST_L,
    input                           i_WR_EN, i_RD_EN,
    input                           i_SOP,i_End_Valid,i_Type,
    input  [PACKET_LENGTH-1:0]      i_Length,
    input  [SYMBOL_PTR_WIDTH-1:0]   i_Last_Byte,
    input  [0:DATA_WIDTH-1]         Data_IN,
    input                           Soft_RST_blocks,
    output                          o_Empty , o_Full,
    output [0:DATA_WIDTH-1]         Data_Out,
    output                          o_SOP,o_End_Valid,o_Type,
    output [PACKET_LENGTH-1:0]      o_Length,
    output [SYMBOL_PTR_WIDTH-1:0]   o_Last_Byte
);
    // pointers
    logic [ADDR_WIDTH:0] wr_ptr , rd_ptr;
    // Memory 
    reg [0:(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 3)-1] mem [0:BUFFER_DEPTH-1];
    // loop counter
    integer i;
    //internal bus to join data and packet indicators to store them
    logic [0:(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 3)-1] i_Data_Join;
    logic [0:(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 3)-1] o_Data_Join;
    assign i_Data_Join = {Data_IN, i_Last_Byte , i_Length , i_SOP , i_End_Valid , i_Type};

    // write operation
    always_ff @(posedge CLK , negedge RST_L) begin
        if(!RST_L)begin
            for(i = 0 ; i < BUFFER_DEPTH ; i = i+1)begin
                mem[i] <= 'd0;
            end
            wr_ptr <= 'd0;
        end
        else if (Soft_RST_blocks)begin
            for(i = 0 ; i < BUFFER_DEPTH ; i = i+1)begin
                mem[i] <= 'd0;
            end
            wr_ptr <= 'd0;
        end
        else if (!o_Full && i_WR_EN)begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= i_Data_Join;
            wr_ptr <= wr_ptr +1;
        end
    end

    // read operation
    always_ff @(posedge CLK , negedge RST_L) begin
        if(!RST_L)begin
            rd_ptr <= 'd0;
        end
        else if (Soft_RST_blocks)begin
            rd_ptr <= 'd0;
        end
        else if (!o_Empty && i_RD_EN)begin
            rd_ptr <= rd_ptr +1;
        end
    end
    
    // Output Decleration
    assign o_Data_Join = mem[rd_ptr[ADDR_WIDTH-1:0]];
    assign Data_Out    = o_Data_Join[0:DATA_WIDTH-1];
    assign o_Last_Byte = o_Data_Join[DATA_WIDTH:(DATA_WIDTH+SYMBOL_PTR_WIDTH)-1];
    assign o_Length    = o_Data_Join[(DATA_WIDTH+SYMBOL_PTR_WIDTH):(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH)-1];
    assign o_SOP       = o_Data_Join[(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH)];
    assign o_End_Valid = o_Data_Join[(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 1)];
    assign o_Type      = o_Data_Join[(DATA_WIDTH + SYMBOL_PTR_WIDTH + PACKET_LENGTH + 2)];

    // Empty and full decleration
    assign o_Empty = (wr_ptr == rd_ptr)?1'b1:1'b0;
    assign o_Full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH] && wr_ptr[ADDR_WIDTH-1:0]  == rd_ptr[ADDR_WIDTH-1:0])?1'b1:1'b0;
endmodule