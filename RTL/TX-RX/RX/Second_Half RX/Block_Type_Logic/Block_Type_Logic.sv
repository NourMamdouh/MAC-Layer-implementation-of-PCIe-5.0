module Block_Type_Logic (
    input CLK , RST_L,
    input [0:1] RX_Sync_Header,
    input RX_Start_Block,
    output reg Block_Type
);
    reg Block_Type_Reg;

always@(posedge CLK , negedge RST_L)begin
    if(!RST_L)begin
        Block_Type_Reg <= 0;
    end
    else if (RX_Start_Block) begin
        Block_Type_Reg <= Block_Type;
    end
end
always@(*)begin
    if(RX_Start_Block)begin
        if(RX_Sync_Header == 2'b01)begin
            Block_Type = 0;
        end
        else if (RX_Sync_Header == 2'b10)begin
            Block_Type = 1;
        end
        else begin
           Block_Type = 0;
        end
    end
    else begin
        Block_Type = Block_Type_Reg;
    end
end
    
endmodule