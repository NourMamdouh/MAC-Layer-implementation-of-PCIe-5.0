/* -----------------------------------------------------------------------------
This module is operating in the recovered clk domain and has the following functions:
1 - Takes the current negotiated speed as input (generation) and an enable 
    signal (flag_en) from  BA_FSM to indicate the current monitoring of EIEOS ,
2-  output a flag that toggles according to the symbol that must be recieved, 
    as the pattern of EIEOS is always alternating zeros and ones but the alternation frequency 
    changes according to the speed 
-----------------------------------------------------------------------------*/
      
module BA_flag_genarator #(
  SYMBOL_COUNT_WIDTH = 'd4
) (
  input  logic                            rx_clk, rx_rst,
  input  logic                            flag_en,
  input  logic [SYMBOL_COUNT_WIDTH -1 :0] symbols_count,
  input  logic                            Soft_RST_blocks,
  input  logic                            rst_flag,
  output logic                            flag
);
  
logic flag_one_gen5;

assign flag_one_gen5 = symbols_count [2];
  
  // flag generator
always_ff @ (posedge rx_clk or negedge rx_rst)begin
  if (!rx_rst )begin
    flag <= 1'b0;
  end
  else if (Soft_RST_blocks || rst_flag) begin
    flag <= 1'b0;
  end
  else if(flag_en) begin
    if (flag_one_gen5)begin
      flag <= 1'b1;
    end
    else begin
      flag <= 1'b0;
    end
  end
end
  
endmodule

