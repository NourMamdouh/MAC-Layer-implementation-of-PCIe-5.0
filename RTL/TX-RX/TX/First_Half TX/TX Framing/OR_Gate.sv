/* OR gates is required to enable signals o_Buff_R_EN , o_Sync_Sel , O_Idle_Indicator in case 32 lane or 1 lane*/

module OR_Gate #(
    parameter DATA_WIDTH = 1
) (
    input  [DATA_WIDTH-1:0] x32,
    input  [DATA_WIDTH-1:0] x1,
    output [DATA_WIDTH-1:0] x
);

assign x = (x1 | x32);
    
endmodule
