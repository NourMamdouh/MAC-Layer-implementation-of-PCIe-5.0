module dff_sync2 #(
  PTR_WIDTH = 'd4
)(
  input  logic                  clk,
  input  logic                  rst,
  input  logic [PTR_WIDTH-1:0]  async,
  output logic [PTR_WIDTH-1:0]  sync
);
  
logic sync_flop1 [PTR_WIDTH-1:0];
logic sync_flop2 [PTR_WIDTH-1:0];
 
always_ff @(posedge clk or negedge rst) begin
  if(!rst) begin
	  for (int i =0; i<PTR_WIDTH; i++) begin
      sync_flop1[i] <= 1'b0;
      sync_flop2[i] <= 1'b0;
	  end
  end else begin
    for (int j =0; j<PTR_WIDTH; j++)begin
      sync_flop1 [j] <= async[j];
      sync_flop2 [j] <= sync_flop1[j];
	  end
  end
end

always_comb begin
  for (int i=0; i<PTR_WIDTH; i++) begin
    sync[i] = sync_flop2[i] ; 
  end
end
  
endmodule 