/* Description:
A 23‐bit Linear Feedback Shift Register (LFSR) with feedback points that implement the following polynomial:
G(X) = X23 + X21 + X16 + X8 + X5 + X2 + 1
*/

module LFSR_8_gen3 #( 

  seed_width = 24, 
  data_width = 8

  )(
  
  input  logic                   rst,
  input  logic                   TX_CLK,
  input  logic [seed_width-1:0]  seed, 
  input  logic                   LFSR_RST,
  input  logic                   back_pressure,
  input  logic                   GEN,
  input  logic                   advance,
  input  logic                   EN,
  output logic [data_width-1:0]  Data_Out
  
   );

  logic [seed_width-2:0]  LFSR_q, LFSR_c;
  logic [data_width-1:0]  Data_c;

  always @(*) begin
 
    
    LFSR_c[0]  = LFSR_q[15]  ^  LFSR_q[17] ^ LFSR_q[19] ^ LFSR_q[21] ^ LFSR_q[22];
    LFSR_c[1]  = LFSR_q[16]  ^  LFSR_q[18] ^ LFSR_q[20] ^ LFSR_q[22];
    LFSR_c[2]  = LFSR_q[15]  ^  LFSR_q[22];
    LFSR_c[3]  = LFSR_q[16];
    LFSR_c[4]  = LFSR_q[17];
    LFSR_c[5]  = LFSR_q[15]  ^  LFSR_q[17] ^ LFSR_q[18] ^ LFSR_q[19] ^ LFSR_q[21] ^ LFSR_q[22];
    LFSR_c[6]  = LFSR_q[16]  ^  LFSR_q[18] ^ LFSR_q[19] ^ LFSR_q[20] ^ LFSR_q[22];
    LFSR_c[7]  = LFSR_q[17]  ^  LFSR_q[19] ^ LFSR_q[20] ^ LFSR_q[21];
    LFSR_c[8]  = LFSR_q[0]   ^  LFSR_q[15] ^ LFSR_q[17] ^ LFSR_q[18] ^ LFSR_q[19] ^ LFSR_q[20];
    LFSR_c[9]  = LFSR_q[1]   ^  LFSR_q[16] ^ LFSR_q[18] ^ LFSR_q[19] ^ LFSR_q[20] ^ LFSR_q[21];
    LFSR_c[10] = LFSR_q[2]   ^  LFSR_q[17] ^ LFSR_q[19] ^ LFSR_q[20] ^ LFSR_q[21] ^ LFSR_q[22];
    LFSR_c[11] = LFSR_q[3]   ^  LFSR_q[18] ^ LFSR_q[20] ^ LFSR_q[21] ^ LFSR_q[22];
    LFSR_c[12] = LFSR_q[4]   ^  LFSR_q[19] ^ LFSR_q[21] ^ LFSR_q[22];
    LFSR_c[13] = LFSR_q[5]   ^  LFSR_q[20] ^ LFSR_q[22];
    LFSR_c[14] = LFSR_q[6]   ^  LFSR_q[21];
    LFSR_c[15] = LFSR_q[7]   ^  LFSR_q[22];
    LFSR_c[16] = LFSR_q[8]   ^  LFSR_q[15] ^ LFSR_q[17] ^ LFSR_q[19] ^ LFSR_q[21] ^ LFSR_q[22];
    LFSR_c[17] = LFSR_q[9]   ^  LFSR_q[16] ^ LFSR_q[18] ^ LFSR_q[20] ^ LFSR_q[22];
    LFSR_c[18] = LFSR_q[10]  ^ LFSR_q[17]  ^ LFSR_q[19] ^ LFSR_q[21];
    LFSR_c[19] = LFSR_q[11]  ^ LFSR_q[18]  ^ LFSR_q[20] ^ LFSR_q[22];
    LFSR_c[20] = LFSR_q[12]  ^ LFSR_q[19]  ^ LFSR_q[21];
    LFSR_c[21] = LFSR_q[13]  ^ LFSR_q[15]  ^ LFSR_q[17] ^ LFSR_q[19] ^ LFSR_q[20] ^ LFSR_q[21];
    LFSR_c[22] = LFSR_q[14]  ^ LFSR_q[16]  ^ LFSR_q[18] ^ LFSR_q[20] ^ LFSR_q[21] ^ LFSR_q[22]; 

 
    Data_c[0] = LFSR_q[22];
    Data_c[1] = LFSR_q[21];
    Data_c[2] = LFSR_q[20] ^ LFSR_q[22];
    Data_c[3] = LFSR_q[19] ^ LFSR_q[21];
    Data_c[4] = LFSR_q[18] ^ LFSR_q[20] ^ LFSR_q[22];
    Data_c[5] = LFSR_q[17] ^ LFSR_q[19] ^ LFSR_q[21];
    Data_c[6] = LFSR_q[16] ^ LFSR_q[18] ^ LFSR_q[20] ^ LFSR_q[22];
    Data_c[7] = LFSR_q[15] ^ LFSR_q[17] ^ LFSR_q[19] ^ LFSR_q[21] ^ LFSR_q[22];

  end

  always @(posedge TX_CLK or negedge rst or posedge LFSR_RST) begin

    if(~rst) begin 
      LFSR_q <= seed;
    end 
 	else if(LFSR_RST)  
      LFSR_q <= seed; 
    else if(!back_pressure && GEN && advance && EN) begin
      LFSR_q <= LFSR_c ;
	  end
end

  assign Data_Out = Data_c;



endmodule


