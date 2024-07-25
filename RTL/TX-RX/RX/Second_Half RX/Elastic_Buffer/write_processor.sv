/*-----------------------------------------------------------------------------
This module has the following functions:
1- Check if the input Symbol is SKP,
2- Enable or disable the writing operation according to whether there is a need to remove a SKP or not
-----------------------------------------------------------------------------*/

module write_processor #( 
  BUFFER_WIDTH = 'd13
) (
  input  logic                   rx_clk, rx_rst,
  input  logic [BUFFER_WIDTH -1:0] rx_data,
  input  logic                   elstc_buff_en,
  input  logic                   SKP_remv_rqst,
  output logic                   write_en
);

logic       is_SKP, first_SKP, fifth_SKP;
logic [3:0] deleted_count;
logic       cnt_en, reint;

localparam [3:0] max_deleted = 'd8,
                 half_max_deleted = 'd4;

assign is_SKP    = (rx_data[8:0] == 9'b110011001); // 1 for ordered set and 99 for SKP
assign first_SKP = ((rx_data [12:9] == 'd0));
assign fifth_SKP = (rx_data [12:9] == 'd4);
assign reint     = ((deleted_count == 'd8) || (rx_data[12:9] == 'd15));

always_comb begin
  if (elstc_buff_en) begin 
    if(SKP_remv_rqst) begin
      if((is_SKP && first_SKP) || (fifth_SKP && (deleted_count == half_max_deleted)))begin
        write_en = 1'b0;
        cnt_en = 1'b1;
      end
      else if ((is_SKP && (deleted_count >0) && (deleted_count <half_max_deleted)) ||(is_SKP && (deleted_count > half_max_deleted) && (deleted_count < max_deleted))) begin
        write_en = 1'b0;
        cnt_en = 1'b1;
      end
      else begin
        write_en = 1'b1;
        cnt_en = 1'b0;
      end 
    end else begin
      if (is_SKP && (deleted_count > 0) && (deleted_count <half_max_deleted)) begin
        write_en = 1'b0;
        cnt_en = 1'b1; 
      end else if (is_SKP && (deleted_count > half_max_deleted) && (deleted_count < max_deleted)) begin
        write_en = 1'b0;
        cnt_en = 1'b1;              
      end else begin
        write_en = 1'b1;
        cnt_en = 1'b0;
      end
    end
  end else begin
    write_en = 1'b0;
    cnt_en = 1'b0; 
  end
end
  
always @ (posedge rx_clk or negedge rx_rst) begin 
  if(!rx_rst) begin
    deleted_count <= 'b0;
  end
  else if(reint) begin
    deleted_count <= 4'b0;
  end
  else if (cnt_en) begin
    deleted_count <= deleted_count + 1'b1;
  end
end 
 
endmodule

