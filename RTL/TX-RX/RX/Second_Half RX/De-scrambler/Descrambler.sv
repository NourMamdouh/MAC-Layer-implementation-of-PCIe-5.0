/* Description:
Receivers follow exactly the same rules for generating the scrambling polynomial
that the Transmitter does and simply XOR the same value to the input data
a second time to recover the original information.
*/
module Descrambler #(
    seed_width = 24,
    symbol_count_width = 4,
    data_width = 8
) (

    input  logic                          RX_CLK,
    input  logic                          rst,
    input  logic                          PIPE_SyncHeader,
    input  logic [seed_width-1:0]         seed,
    input  logic [symbol_count_width-1:0] count,
    input  logic [data_width-1:0] 		  PIPE_Data,
    input  logic                          PIPE_d_K,
    input  logic                          GEN,
    input  logic                          LFSR_RST,
    input  logic                          descramblingEnable,
    input  logic [data_width-1:0] 		  LFSR_Out_8,
    input  logic [data_width-1:0] 		  LFSR_Out_8_gen3,
    output logic [data_width-1:0]		  Des_Data_Out

);

  logic [data_width-1:0] data, lfsrOut;

  //Sync Header: 01 ----- Data block , 10 -> OS

  // seed of Lane 1 = 1dbfbc
  // seed of Lane 2 = 0607bb
  // seed of Lane 3 = 1ec760
  // seed of Lane 4 = 18c0db
  // seed of Lane 5 = 010f12
  // seed of Lane 6 = 19cfc9
  // seed of Lane 7 = 0277ce
  // seed of Lane 8 = 1bb807



  always @(*) begin

    if (!GEN) begin

      lfsrOut = LFSR_Out_8;

      if (!PIPE_d_K) begin
	  data = lfsrOut ^ PIPE_Data;
	  end
      else begin
		 data = PIPE_Data;
	  end

    end 
	else begin

      lfsrOut = LFSR_Out_8_gen3;

      if (descramblingEnable) begin
		data = lfsrOut ^ PIPE_Data;
	  end
      else begin
		data = PIPE_Data;
	  end
    end
  end

  assign Des_Data_Out = data;

endmodule
