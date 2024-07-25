/*-----------------------------------------------------------------------------
This module serves to :
1- Calculate the number of idles sent
2- Feed the LTSSM with ack_done indicating the sent of 16 idles
 -----------------------------------------------------------------------------*/    
module IDLE_Counter #(
    CNT_WIDTH = 4
) (
    input         clk,rst,
    input         cnt_enable,
    input         back_pressure,
    input         IDL_rst,
    output logic  ack_done
);

logic  [0: CNT_WIDTH-1] o_cnt;

always @(posedge clk , negedge rst)begin
    if(!rst)begin
        o_cnt <= 0;
    end else begin
	    if(IDL_rst) begin
            o_cnt <= 0;
        end
        else if (cnt_enable && !back_pressure) begin
            o_cnt <= o_cnt + 1;
        end
    end
end

assign ack_done = (o_cnt == 'd15);
    
endmodule