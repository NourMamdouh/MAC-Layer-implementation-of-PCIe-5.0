/* Description:
The scrambler controller runs by certain spec rules:
GEN1,2:
1-Scrambling is only applied to 'D' characters, which are those associated with TLP and DLLPs and the Logical Idle (00h) characters. 
2-'D' characters within TS1 and TS2 ordered sets are not scrambled.
'K' characters and characters within ordered sets like TS1, TS2 and SKP bypass the scrambler logic 
3-The COM character is used to reinitialize the LFSR to FFFFh at both the transmitter and receiver.
4-LFSR does not advance on SKP characters in the SKP

GEN3 and higher:
1-The Transmitter LFSR is reset when the last EIEOS Symbol has been sent
2-The Receiver LFSR is reset when the last EIEOS Symbol is received.
3-TS1 and TS2 Ordered Sets:
	— Symbol 0 bypasses scrambling
	— Symbols 1 to 13 are scrambled
	— Symbols 14 and 15 may or may not be scrambled
*/

module Scrambler_Controler #(
    symbol_count_width = 4,
    data_width = 8
) (

    input  logic                          SyncHeader,
    input  logic                          CLK,
    input  logic                          RST_L,
    input  logic [data_width-1:0]		  Sc_Data,
    input  logic [symbol_count_width-1:0] count,
    input  logic                          GEN,
    input  logic                          back_pressure,
    output logic                          SC_LFSR_RST,
    output logic                          scramblingEnable,
    output logic                          advance,
    output logic                          TS_flag_Stored
);

  localparam COM = 188, EIEOS = 8'hFF, SKP = 28, SKP_gen3 = 8'h99;
  localparam os = 0, data = 1; // ordered set and data
  localparam TS1 = 8'h1e, TS2 = 8'h2d;

  logic state;
  logic LFSR_RST, LFSR_RST_GEN3;
  logic TS_flag; // Keep Track of TS ordered set
  logic Flag_EN;
  logic flag_rst;

  always @(*) begin
    TS_flag          = 0;
    LFSR_RST         = 0;
    LFSR_RST_GEN3    = 0;
    scramblingEnable = 0;
    advance          = 0;

    if (count == 0) begin
      Flag_EN = 1;
    end
	
	else begin
      Flag_EN = 0;
    end

    if (!GEN) begin

      if (Sc_Data == COM) begin //Resting the LFSR when a COM charachter arrives
		LFSR_RST = 1;
	  end
    
	  else begin
        LFSR_RST = 0;
      end

	end

    else begin

      if (SyncHeader) begin
		 state = os;
	  end

      else begin
		state = data;
	  end
      
	  case (state)
       
	     os: begin

          LFSR_RST_GEN3    = 0;
          scramblingEnable = 0;
          advance          = 1;

          if (count == 0 && ((Sc_Data == TS1) || (Sc_Data == TS2))) begin
            TS_flag = 1;
          end 
		  else if (TS_flag_Stored && count != 0) begin // In GEN 3 and higher the TS OS can be srambles except for symbol 0
			 scramblingEnable = 1;
		  end
		  else if (Sc_Data == EIEOS && (count == 4'b1111)) begin //Resting the LFSR when the last byte of EIOS arrives
			 LFSR_RST_GEN3 = 1;
		  end
          else if (Sc_Data == SKP_gen3) begin // Dont advance the LFSR when there is a SKP OS
			advance = 0;
		  end

		  else begin
            LFSR_RST_GEN3    = 0;
            scramblingEnable = 0;
            advance          = 1;
          end

        end

        data: begin
          advance          = 1;
          LFSR_RST_GEN3    = 0;
          scramblingEnable = 1;
        end

        default: begin
          LFSR_RST_GEN3 = 0;
          scramblingEnable = 0;
        end

      endcase
    end
  end


  always @(posedge CLK, negedge RST_L) begin
    if (!RST_L) begin
      TS_flag_Stored <= 0;
    end 
	else if (flag_rst) begin
		 TS_flag_Stored <= 0;
	end
	else if (Flag_EN && !back_pressure) begin
      TS_flag_Stored <= TS_flag;
    end
  end

  assign SC_LFSR_RST = (!GEN) ? LFSR_RST : LFSR_RST_GEN3;
  assign flag_rst = (count == 'd15);


endmodule







