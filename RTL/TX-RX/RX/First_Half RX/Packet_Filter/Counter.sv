/*Describtion: Counter is required to communicate with FSM 1 lane as we need to count each symbol of Tokens to start to send Data or OS 
or count each symbols of length of packets to finish packet and start new packet*/

module Counter #(
parameter	CNT_WIDTH = 5
)(
input	logic						CLK,Soft_RST,Hard_RST_L,
input	logic						i_CNT_EN,		// to enable counting up by one when set
input	logic	[CNT_WIDTH-1:0]		i_CNT_RST_VAL,	// the value counter is reset to when i_CNT_EN is set
input	logic	[CNT_WIDTH-1:0]		i_CNT_END_VAL,	// the value counter is to set o_CNT_Done when reached 
output	logic		[CNT_WIDTH-1:0]		o_CNT,			//current count
output	logic						o_CNT_Done		// set to one
);


//counter logic
always_ff @(posedge CLK, negedge Hard_RST_L)begin
	if(!Hard_RST_L) begin
		o_CNT <= 'd0;
	end 
	else if (Soft_RST) begin
		o_CNT <= i_CNT_RST_VAL;
	end
	else if (i_CNT_EN) begin
		o_CNT <= o_CNT + 'd1 ;
	end
end


//done signal logic
assign o_CNT_Done = (o_CNT == i_CNT_END_VAL) ;

endmodule
