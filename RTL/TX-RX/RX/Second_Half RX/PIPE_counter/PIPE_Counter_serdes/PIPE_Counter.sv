module PIPE_Counter #(
parameter	CNT_WIDTH = 4
)(
input	wire						CLK,Hard_RST_L,
input 	logic						PIPE_CNT_rst,
input	logic						CNT_set,
input	wire						i_CNT_EN,		// to enable counting up by one when set
output	reg		[CNT_WIDTH-1:0]		o_CNT			//current count
);


//counter logic
always @(posedge CLK, negedge Hard_RST_L)begin
	if(!Hard_RST_L) begin
		o_CNT <= 'd0;
	end 
	else if (PIPE_CNT_rst) begin
		o_CNT <= 0;
	end
	else if (CNT_set) begin
		o_CNT <= 1;
	end
	else if (i_CNT_EN) begin
		o_CNT <= o_CNT + 'd1 ;
	end
end


endmodule
