/* Description:
The descrambler controller runs by certain spec rules:
GEN1,2:
1-Descrambling is only applied to 'D' characters, which are those associated with TLP and DLLPs and the Logical Idle (00h) characters. 
2-'D' characters within TS1 and TS2 ordered sets are not descrambled.
'K' characters and characters within ordered sets like TS1, TS2 and SKP bypass the descrambler logic 
3-The COM character is used to reinitialize the LFSR to FFFFh at both the transmitter and receiver.
4-LFSR does not advance on SKP characters in the SKP

GEN3 and higher:
1-The Transmitter LFSR is reset when the last EIEOS Symbol has been sent
2-The Receiver LFSR is reset when the last EIEOS Symbol is received.
3-TS1 and TS2 Ordered Sets:
	— Symbol 0 bypasses descrambling
	— Symbols 1 to 13 are descrambled
	— Symbols 14 and 15 may or may not be descrambled
*/

module Descrambler_Controler #(
    symbol_count_width = 4,
    data_width = 8
) (

    input  logic                          CLK,
    input  logic                          RST_L,
    input  logic                          SyncHeader,
    input  logic [data_width-1:0]  		  PIPE_Data,
    input  logic [symbol_count_width-1:0] count,
    input  logic                          GEN,
    input  logic                          RX_Data_Valid,
    output logic                          SC_LFSR_RST,
    output logic                          descramblingEnable,
    output logic                          advance
);

  localparam COM = 188, EIEOS = 8'hFF, SKP = 28, SKP_gen3 = 8'h99;
  localparam os = 0, data = 1;
  localparam TS1 = 8'h1e, TS2 = 8'h2d;


  logic state;
  logic LFSR_RST, LFSR_RST_GEN3;
  logic TS_flag, TS_flag_Stored, Flag_EN;
  logic flag_rst;


  always @(*) begin

    LFSR_RST_GEN3    = 0 ;
    descramblingEnable = 0 ;
    advance = 0 ;
    LFSR_RST = 0 ;
    TS_flag = 0;

    if (count == 0) begin
      Flag_EN = 1;
    end else begin
      Flag_EN = 0;
    end

    if (!GEN)

      if (PIPE_Data == COM) LFSR_RST = 1;
      else begin
        descramblingEnable = 1;
        LFSR_RST = 0;
      end

    else begin

      if (SyncHeader) state = os;
      else state = data;

      case (state)

        os: begin

          LFSR_RST_GEN3    = 0 ;
          descramblingEnable = 0 ;
          advance = 1 ;

          if (count == 0 && ((PIPE_Data == TS1) || (PIPE_Data == TS2))) begin

            TS_flag = 1;
          end
		 
		   else if (TS_flag_Stored && (count > 0) && (count < 14)) begin

            descramblingEnable = 1;
          end 
		 
		  else if (TS_flag_Stored && (count == 4'b0001 || count == 4'b1101)) begin

            descramblingEnable = 1;
          end
          
		  else if(TS_flag_Stored && (count == 4'b1110)&& !((PIPE_Data == 8'h20 || PIPE_Data == 8'hDF))) begin

            descramblingEnable = 1;
          end

          else if(TS_flag_Stored && (count == 4'b1111)&& !((PIPE_Data == 8'h08 || PIPE_Data == 8'hF7))) begin

            descramblingEnable = 1;
          end
		  
		   else if (PIPE_Data == EIEOS && (count == 4'b1111)) begin

            LFSR_RST_GEN3 = 1;
          end 
		  
		  else if (PIPE_Data == SKP || PIPE_Data == SKP_gen3) begin

            advance = 0;
          end 
		  
		  else begin

            LFSR_RST_GEN3    = 0 ;
            descramblingEnable = 0 ;
            advance = 1 ;

            if(PIPE_Data == 8'h20 || PIPE_Data == 8'hDF || PIPE_Data == 8'h08 || PIPE_Data == 8'hF7) begin
              TS_flag = 1;

            end 
			
			else begin
              TS_flag = 0;
            end
          end
        end

        data: begin

          advance = 1;
          LFSR_RST_GEN3 = 0;
          descramblingEnable = 1;

        end

        default: begin

          advance = 1;
          LFSR_RST_GEN3 = 0;
          descramblingEnable = 0;

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
	
	else if (Flag_EN && RX_Data_Valid) begin
      TS_flag_Stored <= TS_flag;
    end
  end

  assign SC_LFSR_RST = (!GEN) ? LFSR_RST : LFSR_RST_GEN3;
  assign flag_rst = (count == 'd15);


endmodule



