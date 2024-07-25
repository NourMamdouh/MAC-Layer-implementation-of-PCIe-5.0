/* Description:
For Gen1 and Gen2, the DC Balance is maintained by 8b/10b encoding.
For Gen3 and higher, the contents of these two Symbols (14,15) depend on the DC Balance of
the Lane. Each Lane of a Transmitter must independently track the running
DC Balance for all the scrambled bits sent for TS1s and TS2s.Running
DC Balance means the difference between the number of ones sent
vs. the number of zeroes sent, and Lanes must be capable of tracking a difference
of up to 511 in either direction. These counters saturate at their max
value but continue to track reductions
*/

module DC_Balance #(
    data_width = 8,
    dc_balance_width = 9,
    symbol_count_width = 4,
    symb_14_15 = 2
) (

    input  logic [data_width-1:0]         Sc_Data_In,
    input  logic [symbol_count_width-1:0] count,
    input  logic                          clk,
    input  logic                          rst,
    input  logic                          TS_flag_Stored, // if the symbol is from a TS ordered set
    output logic [symb_14_15-1:0]         symb_14,
    output logic [symb_14_15-1:0]         symb_15

);

  logic [dc_balance_width-1:0] dc_balance;
  logic [dc_balance_width-1:0] zeros_flag;
  logic [dc_balance_width-1:0] ones_flag;
  logic [dc_balance_width-1:0] ones_comb; 
  logic [dc_balance_width-1:0] zeros_comb; 

  localparam EIOS = 8'hFF;



  always @(posedge clk or negedge rst) begin

    if (!rst) begin

      dc_balance <= 0;
      zeros_flag <= 0;
      ones_flag  <= 0;

    end else if (Sc_Data_In == EIOS && count == 'b1111) begin

      dc_balance <= 0;
      zeros_flag <= 0;
      ones_flag  <= 0;

    end else if (TS_flag_Stored) begin

      if(dc_balance + ones_flag - zeros_flag >=0 || dc_balance + ones_flag - zeros_flag < 512 ) begin
        dc_balance <= dc_balance + ones_comb - zeros_comb;
        zeros_flag <= zeros_flag + zeros_comb;
        ones_flag  <= ones_flag + ones_comb;

      end
    end
  end


  assign symb_14 = (dc_balance>31 && count == 4'b1011 && ones_flag > zeros_flag && TS_flag_Stored) ? 2'b00: 
                  (dc_balance>31 && count == 4'b1011 && ones_flag < zeros_flag && TS_flag_Stored) ? 2'b01 : 2'b10 ;

  assign symb_15 = ((dc_balance>31 && count == 4'b1011 && ones_flag > zeros_flag && TS_flag_Stored)
                   ||(dc_balance>15 && ones_flag > zeros_flag && TS_flag_Stored)) ? 2'b00:
                    ((dc_balance>31 && count == 4'b1011 && ones_flag < zeros_flag && TS_flag_Stored)
                   ||(dc_balance>15 && ones_flag < zeros_flag && TS_flag_Stored)) ? 2'b01 : 2'b10 ;

  assign ones_comb = Sc_Data_In[0]+Sc_Data_In[1]+Sc_Data_In[2]+Sc_Data_In[3]+Sc_Data_In[4]+Sc_Data_In[5]+Sc_Data_In[6]+Sc_Data_In[7]; // num of ones
  
  assign zeros_comb = dc_balance_width - 1 - ones_comb; 

endmodule
