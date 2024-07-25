/* Description:
The module has acess to all lanes to:
1-Select the appropriate delay for each lane according to the time of SDS ordered set arrival
2-Assert/Deassert Deskew_error signal if the delay is more than 6 clk cycles (spec requirement)
3-Assert/Deassert valid_deskew to assure that the lanes are all alligned
3-Assert/Deassert valid_data to assure that each lane has valid data

*/
module lane_control #(
    lane_count  = 32,
    data_width  = 8,
    delay_width = 3
) (

    input  logic [ data_width-1:0] skewed_RX_Data_1[lane_count-1:0],
    input  logic                   RX_CLK,
    input  logic                   EN_LTSSM,
    input  logic                   rst,
    input  logic [0:lane_count-1]  block_type,
    input  logic                   Soft_RST_blocks,
    output logic                   Deskew_error,
    output logic [delay_width-1:0] delay_select    [lane_count-1:0],
    output logic                   valid_deskew,
    output logic [lane_count-1:0]  valid_data

);

  logic [delay_width:0]   count_edge;
  logic [lane_count-1:0]  lanes;
  logic [lane_count-1:0]  lanes_reg;
  logic                   done_flag;
  logic                   error_flag,error_flag_reg;
  logic                   correct_flag,correct_flag_reg;
  logic [delay_width-1:0] delay_select_reg[lane_count-1:0];



  localparam SDS = 8'hE1;

  always @(*) begin //track the SDS on all lanes

    for (int i = 0; i < 32; i++) begin

      if (!EN_LTSSM) begin
        lanes[i] = 0;
      end 
      else begin
        if (skewed_RX_Data_1[i] == SDS && block_type[i]) begin
          lanes[i] = 1;
        end 
        else begin
          lanes[i] = lanes_reg[i];
        end

      end
    end
  end

  always @(posedge RX_CLK or negedge rst) begin
    if (!rst) begin
      for (int i = 0; i < 32; i++) begin
        lanes_reg[i] <= 0;
      end
    end else begin
      for (int i = 0; i < 32; i++) begin
        lanes_reg[i] <= lanes[i];
      end
    end
  end


  always @(*) begin // choose the appropriate delay for each lane according to the time of arrival of the SDS
    for (int i = 0; i < 32; i++) begin

      if (!EN_LTSSM) begin
        delay_select[i] = 0;
      end
       else if (!done_flag && lanes_reg[i]) begin
        delay_select[i] = delay_select_reg[i] + 1;
      end 
      else if (skewed_RX_Data_1[i] == SDS && block_type[i]) begin
        delay_select[i] = 0;
      end 
      else begin
        delay_select[i] = delay_select_reg[i];
      end
    end
  end

  always @(*) begin 
    for (int i = 0; i < 32; i++) begin
      if (!EN_LTSSM) begin 
        valid_data[i] = 1;
      end
      else if (done_flag) begin
        valid_data[i] = 1;
      end
      else if (!lanes_reg[i]) begin
        valid_data[i] = 1;
      end
      else begin
        valid_data[i] = 0;
      end
    end

  end


  always @(posedge RX_CLK or negedge rst) begin
    if (!rst) begin
      for (int i = 0; i < 32; i++) begin
        delay_select_reg[i] <= 0;
      end
    end else begin
      for (int i = 0; i < 32; i++) begin
        delay_select_reg[i] <= delay_select[i];
      end
    end
  end



  always @(posedge RX_CLK or negedge rst) begin // count the delay cycles to make sure that they don't exceed 6 clk cycles
    if (!rst) begin
      count_edge <= 0;
    end 
    else if (!EN_LTSSM || lanes_reg == 32'h00000000)begin
      count_edge <= 0;
    end
    else if (count_edge < 7) begin
      count_edge <= count_edge + 1;
    end
  end

  always @(*) begin

    if (!EN_LTSSM) begin
      Deskew_error = 0;
      valid_deskew = 1;
      error_flag   = 0;
      correct_flag = 0;
    end else if (count_edge <= 6 && done_flag) begin
      Deskew_error = 0;
      valid_deskew = 1;
      error_flag   = 0;
      correct_flag = 1;
    end else if (count_edge == 6 && !done_flag) begin
      Deskew_error = 1;
      valid_deskew = 0;
      error_flag   = 1;
      correct_flag = 0;
    end else if (error_flag_reg) begin
      Deskew_error = 1;
      valid_deskew = 0;
      error_flag   = 1;
      correct_flag = 0;
    end else if (correct_flag_reg) begin
      Deskew_error = 0;
      valid_deskew = 1;
      error_flag   = 0;
      correct_flag = 1;
    end else begin
      Deskew_error = 0;
      valid_deskew = 0;
      error_flag   = 0;
      correct_flag = 0;
    end
  end

always@(posedge RX_CLK or negedge rst)begin
  
   if(!rst)
   begin
   
    correct_flag_reg <= 0 ;
    error_flag_reg <= 0 ;
   end

   else begin
   correct_flag_reg <=correct_flag ;
   error_flag_reg <= error_flag ;
  end
 end

  assign done_flag = (lanes_reg == 32'hFFFF_FFFF);



endmodule






