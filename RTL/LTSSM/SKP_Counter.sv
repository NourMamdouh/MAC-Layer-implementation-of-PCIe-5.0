/*-----------------------------------------------------------------------------
This module concerns with:
1- counting the number of cycles between skp transmission in high and low GENs
2- Assert the skp_enable to notify the OS_Creator module for time to send the SOS
3- Reset the counter in special states as directed by the LTSSM using skp_rst
 -----------------------------------------------------------------------------*/ 
module SKP_Counter #(
    CNT_Width_gen3 =  'd13,
    GEN3_Count = ('d6000 - 'd1), 
    GEN1_Count = ('d1538 - 'd1)
) (
    input        clk , rst,
    input        gen,
    input        back_pressure,
    input        skp_done,
    input        skp_rst,
    output logic skp_enable
);

logic [0:CNT_Width_gen3-1] CNT_Out;
localparam HIGH_GEN = 1, LOW_GEN =0;

always_ff @(posedge clk , negedge rst) begin
    if(!rst)begin
        CNT_Out <= 0;
        skp_enable <= 0;
    end
    else begin
        if(skp_rst)begin
            CNT_Out <= 0;
            skp_enable <= 0;
        end
        else if ((CNT_Out == GEN3_Count && gen == HIGH_GEN)  || (CNT_Out == GEN1_Count && gen == LOW_GEN)) begin
            skp_enable <= 'd1;
            CNT_Out <= 'd0;
        end
        else if (skp_done && !back_pressure) begin
            skp_enable <= 'd0;
            CNT_Out <= CNT_Out + 'd1;
        end
        else if(!back_pressure)  begin
            CNT_Out <= CNT_Out + 'd1;
        end
    end
end
endmodule