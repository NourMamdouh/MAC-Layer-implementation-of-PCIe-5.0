/* Description:
A 16‐bit Linear Feedback Shift Register (LFSR) with feedback points that implement the following polynomial:
G(x) = X16 + X5 + X4+ X3 +1
*/

module LFSR_8 #(
  lfsr_width = 16, 
  data_width = 8

  )(

  input  logic                   rst,
  input  logic                   TX_CLK,
  input  logic                   LFSR_RST,
  input  logic                   GEN,
  input  logic                   advance,
  input  logic                   EN,
  output logic [data_width-1:0]  Data_Out
  
   );

  logic [lfsr_width-1:0]  LFSR_q, LFSR_c;
  logic [data_width-1:0]  Data_c;

  always @(*) begin
    

      LFSR_c[0]  = LFSR_q[8];
      LFSR_c[1]  = LFSR_q[9];
      LFSR_c[2]  = LFSR_q[10];
      LFSR_c[3]  = LFSR_q[8]  ^ LFSR_q[11];
      LFSR_c[4]  = LFSR_q[8]  ^ LFSR_q[ 9] ^ LFSR_q[12];
      LFSR_c[5]  = LFSR_q[8]  ^ LFSR_q[ 9] ^ LFSR_q[10] ^ LFSR_q[13];
      LFSR_c[6]  = LFSR_q[9]  ^ LFSR_q[10] ^ LFSR_q[11] ^ LFSR_q[14];
      LFSR_c[7]  = LFSR_q[10] ^ LFSR_q[11] ^ LFSR_q[12] ^ LFSR_q[15];
      LFSR_c[8]  = LFSR_q[0]  ^ LFSR_q[11] ^ LFSR_q[12] ^ LFSR_q[13];
      LFSR_c[9]  = LFSR_q[1]  ^ LFSR_q[12] ^ LFSR_q[13] ^ LFSR_q[14];
      LFSR_c[10] = LFSR_q[2]  ^ LFSR_q[13] ^ LFSR_q[14] ^ LFSR_q[15];
      LFSR_c[11] = LFSR_q[3]  ^ LFSR_q[14] ^ LFSR_q[15];
      LFSR_c[12] = LFSR_q[4]  ^ LFSR_q[15];
      LFSR_c[13] = LFSR_q[5];
      LFSR_c[14] = LFSR_q[6];
      LFSR_c[15] = LFSR_q[7];
     
     
    Data_c[0] = LFSR_q[15];
    Data_c[1] = LFSR_q[14];
    Data_c[2] = LFSR_q[13];
    Data_c[3] = LFSR_q[12];
    Data_c[4] = LFSR_q[11];
    Data_c[5] = LFSR_q[10];
    Data_c[6] = LFSR_q[9];
    Data_c[7] = LFSR_q[8];
end

  always @(posedge TX_CLK or negedge rst or posedge LFSR_RST ) begin

    if(~rst) 
      LFSR_q <= 16'hFFFF; 
    else if(LFSR_RST)
       LFSR_q <= 16'hFFFF; 
    else if(!GEN && advance && EN)
      LFSR_q <= LFSR_c ;
    


  end

  assign Data_Out = Data_c;



endmodule



