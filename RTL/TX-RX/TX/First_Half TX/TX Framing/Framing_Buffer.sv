/*  Framing Buffer is required to store the Last 2 bytes of Data due to the 2 bytes of Tokens that we add at the start of TLP packet 
    so we need the Buffer.*/
    
module Framing_Buffer #(
    parameter SYMBOL_WIDTH		    = 'd8,  
    parameter FRAMING_DATA_WIDTH    = SYMBOL_WIDTH*2
)(
    input                                CLK,
    input                                RST_L,
    input                                i_Fram_Buff_W_EN,
    input      [0:FRAMING_DATA_WIDTH-1]  i_Fram_Buff_Data,
    output logic [0:FRAMING_DATA_WIDTH-1]  o_Fram_Buff_Data
);

always_ff @(posedge CLK , negedge RST_L) begin
    if(!RST_L)begin
        o_Fram_Buff_Data <= 'd0;
    end
    else begin
        if(i_Fram_Buff_W_EN)begin
            o_Fram_Buff_Data <= i_Fram_Buff_Data;
        end
    end
end
endmodule
