module PIPE_Counter_pipe #(
parameter	CNT_WIDTH = 4
)(
input	logic						CLK,Hard_RST_L,
input 	logic						PIPE_CNT_rst,
input	logic						CNT_set,
input   logic                       RX_Start_Block,
input	logic						i_CNT_EN,		// to enable counting up by one when set
output	logic	[CNT_WIDTH-1:0] 	o_CNT			//current count
);
 
logic [CNT_WIDTH-1:0]		CNT;

assign o_CNT = (RX_Start_Block)? 'd0 : CNT;

//counter logic
always @(posedge CLK, negedge Hard_RST_L)begin
	if(!Hard_RST_L) begin
		CNT <= 'd0;
	end 
	else if (PIPE_CNT_rst) begin
		CNT <= 0;
	end
	else if (CNT_set || RX_Start_Block) begin
		CNT <= 1;
	end
	else if (i_CNT_EN) begin
		CNT <= CNT + 'd1 ;
	end
end


endmodule

