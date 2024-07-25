/* Description:
Reducing repetitive patterns problem by spreading the energy over a wider frequency range is the
primary goal of scrambling. In addition, though, scrambled transmission on
one Lane also reduces interference with adjacent Lanes on a wide Link. The reduction of crosstalk
helps the receiver on each lane to distinguish the desired signal.
The scrambler runs by crain spec rules e.g SKP OS is not scrambled, all data is scrambled,..
*/

module Scrambler #(
    seed_width = 24,
    symbol_count_width = 4,
    data_width = 8,
    symb_14_15 = 2
) (

    input  logic                          TX_CLK,
    input  logic                          rst,
    input  logic                          SyncHeader,
    input  logic [seed_width-1:0] 		  seed,
    input  logic [symbol_count_width-1:0] count,
    input  logic [data_width-1:0] 		  Sc_Data_In,
    input  logic                          d_K,        // data or control symbol
    input  logic                          GEN,
    input  logic                          back_pressure,
    input  logic                          LFSR_RST,
    input  logic                          scramblingEnable,
    input  logic [data_width-1:0] 		  LFSR_Out_8,
    input  logic [data_width-1:0] 		  LFSR_Out_8_gen3,
    input  logic [symb_14_15-1:0] 		  symb_14,
    input  logic [symb_14_15-1:0] 		  symb_15,
    output logic [data_width-1:0]		    Sc_Data_Out

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

      if (!d_K) begin
	   data = lfsrOut ^ Sc_Data_In;
	  end

	  else begin 
		data = Sc_Data_In;
	  end
    end 
	
	else begin

      lfsrOut = LFSR_Out_8_gen3;

      if (scramblingEnable) begin
		data = lfsrOut ^ Sc_Data_In;
		end
      
	  else begin
		 data = Sc_Data_In;
	  end
    end
  end

  always @(*) begin // Maintaing DC_Balance

    if (symb_14 == 2'b00 && count == 4'b1110 && GEN) begin
		Sc_Data_Out = 8'h20;
	end
    else if (symb_14 == 2'b01 && count == 4'b1110 && GEN) begin
		Sc_Data_Out = 8'hdf;
	end
    else if (symb_15 == 2'b00 && count == 4'b1111 && GEN) begin
		Sc_Data_Out = 8'h08;
	end
    else if (symb_15 == 2'b01 && count == 4'b1111 && GEN) begin
		Sc_Data_Out = 8'hf7;
	end
    else begin
		Sc_Data_Out = data;
	end
  end

endmodule






