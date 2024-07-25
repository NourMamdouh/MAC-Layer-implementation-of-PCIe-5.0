/*Description:
For wide links, skew between lanes is an issue that can’t be avoided and which
must be compensated at the receiver. Symbols are sent simultaneously on all
lanes using the same transmit clock, but they can’t be expected to arrive at the
receiver at precisely the same time.Thus Lane to Lane Deskew block is used to 
allign all the lanes.

*/

module lane_deskew #(
    data_width = 8,
    reg_delay_width = 6,
    symbol_count_width = 4,
    delay_width = 3
) (

    input  logic [data_width-1:0]         skewed_RX_Data,
    input  logic                          EN_LTSSM,
    input  logic                          valid_buffer,
    input  logic                          GEN,
    input  logic                          rst,
    input  logic                          RX_CLK,
    input  logic [symbol_count_width-1:0] count,
    input  logic                          block_type,
    input  logic [delay_width-1:0]        delay_select,
    input  logic                          Soft_RST_blocks,
    output logic [data_width-1:0]         deskewed_RX_Data,
    output logic [symbol_count_width-1:0] deskewed_RX_count,
    output logic                          deskewed_RX_sync,
    output logic                          deskewed_RX_valid

);
  logic [data_width-1:0] registers_data  [reg_delay_width-1];
  logic [3:0]            registers_count [reg_delay_width-1];
  logic                  registers_sync  [reg_delay_width-1];
  logic                  registers_valid [reg_delay_width-1];

  always @(posedge RX_CLK or negedge rst) begin // Deskewing the input data along with the symbol count number, sync_header and the valid signal

    if (!rst) begin
      for (int i = 0; i < reg_delay_width - 1; i++) begin
        registers_data[i]  <= 0;
        registers_count[i] <= 0;
        registers_sync[i]  <= 0;
        registers_valid[i] <= 0;
      end
    end
    else if (EN_LTSSM && GEN) begin
      registers_data[0]  <= skewed_RX_Data;
      registers_count[0] <= count;
      registers_sync[0]  <= block_type;
      registers_valid[0] <= valid_buffer;

      for (int i = 0; i < reg_delay_width - 1; i++) begin
        registers_data[i+1]  <= registers_data[i];
        registers_count[i+1] <= registers_count[i];
        registers_sync[i+1]  <= registers_sync[i];
        registers_valid[i+1] <= registers_valid[i];
      end
    end

  end

  always @(*) begin // Selecting the suitable delay from the set of delay registers
    if (EN_LTSSM && GEN) begin
      case (delay_select)

        3'd0: begin
          deskewed_RX_Data  = skewed_RX_Data;
          deskewed_RX_sync  = block_type;
          deskewed_RX_count = count;
          deskewed_RX_valid = valid_buffer;
        end
        3'd1: begin
          deskewed_RX_Data  = registers_data[0];
          deskewed_RX_sync  = registers_sync[0];
          deskewed_RX_count = registers_count[0];
          deskewed_RX_valid = registers_valid[0];
        end
        3'd2: begin
          deskewed_RX_Data  = registers_data[1];
          deskewed_RX_sync  = registers_sync[1];
          deskewed_RX_count = registers_count[1];
          deskewed_RX_valid = registers_valid[1];
        end
        3'd3: begin
          deskewed_RX_Data  = registers_data[2];
          deskewed_RX_sync  = registers_sync[2];
          deskewed_RX_count = registers_count[2];
          deskewed_RX_valid = registers_valid[2];
        end
        3'd4: begin
          deskewed_RX_Data  = registers_data[3];
          deskewed_RX_sync  = registers_sync[3];
          deskewed_RX_count = registers_count[3];
          deskewed_RX_valid = registers_valid[3];
        end
        3'd5: begin
          deskewed_RX_Data  = registers_data[4];
          deskewed_RX_sync  = registers_sync[4];
          deskewed_RX_count = registers_count[4];
          deskewed_RX_valid = registers_valid[4];
        end
        3'd6: begin
          deskewed_RX_Data  = registers_data[5];
          deskewed_RX_sync  = registers_sync[5];
          deskewed_RX_count = registers_count[5];
          deskewed_RX_valid = registers_valid[5];
        end
        default: begin
          deskewed_RX_Data  = skewed_RX_Data;
          deskewed_RX_sync  = block_type;
          deskewed_RX_count = count;
          deskewed_RX_valid = valid_buffer;
        end
      endcase
    end 
    else begin
      deskewed_RX_Data  = skewed_RX_Data;
      deskewed_RX_sync  = block_type;
      deskewed_RX_count = count;
      deskewed_RX_valid = valid_buffer;
    end

  end
endmodule


