
module Sync_Logic #(
  serdes       = 0,
  SYMBOL_WIDTH ='d8,
  CNT_WIDTH    ='d4,
  SYNC_WIDTH   ='d2
)(
  input  logic                    clk, rst, 
  input  logic                    enable,
  input  logic [SYMBOL_WIDTH-1:0] scrambled_data,
  input  logic                    sync_sel,
  output logic [CNT_WIDTH-1:0]  symbol_cnt,
  output logic                    back_pressure,
  output logic [SYMBOL_WIDTH-1:0] sync_data,
  output logic [SYNC_WIDTH-1:0]   sync_header,
  output logic                    valid_data,
  output logic                    Tx_Start_Block
  
);

logic [SYMBOL_WIDTH-1:0] internal_reg, saved_data;
logic                    reg_ptr_en, internal_reg_en, reint_cnt;
logic [2:0]              reg_ptr, ptr;

assign sync_header = (sync_sel)? 10 : 01; 
assign back_pressure = (reg_ptr == 4'b111);


always_comb begin
/////////////////// default values //////////////////// 
  reg_ptr_en = 1'b0;
  internal_reg_en = 1'b0;
  saved_data = 'b0;
  ptr = 'b0;
  reint_cnt = 'b0;
  valid_data = 1'b0;
  Tx_Start_Block = 'b0;
  sync_data = 'b0;
  if(enable) begin 
/////////////////// Assignment of TX_Start_Block ////////////////////    
    if(symbol_cnt == 'b0 && !back_pressure) begin
      Tx_Start_Block = 'b1;
    end
    else begin
      Tx_Start_Block = 'b0;       
    end
/////////////////// Assignment of valid_data //////////////////// 
    if(serdes)begin
      valid_data = 1;
    end
    else begin
      valid_data = !back_pressure;
    end

    case(reg_ptr)
/////////////////// 0 bits saved in internal reg ////////////////////
	  3'b000: begin
	            if(symbol_cnt == 4'b0 ) begin
                if(serdes)begin
                  sync_data = {scrambled_data [5:0],sync_header};
                  reg_ptr_en = 1'b1;
                  ptr = 3'b01;
                  saved_data = scrambled_data[7:6];
                  internal_reg_en = 1'b1;
                end
                else begin
                  reg_ptr_en = 1'b1;
                  ptr = 3'b01;
                  sync_data = scrambled_data;
                end				
	  	        end
	  	        else begin
	  			      sync_data = scrambled_data;
	  	        end
	          end
/////////////////// 2 bits saved in internal reg ////////////////////
	  3'b001: begin
	            if(symbol_cnt == 4'b0) begin
                if(serdes)begin
                  sync_data = {scrambled_data [3:0],sync_header, internal_reg[1:0]};
                  reg_ptr_en = 1'b1;
                  ptr = 3'b011;
                  saved_data = scrambled_data[7:4];
                  internal_reg_en = 1'b1;	
                end
                else begin
                  reg_ptr_en = 1'b1;
                  ptr = 3'b011;
                  sync_data = scrambled_data;
                end			
	  	        end
	  	        else 
	  	          if (serdes) begin
                  sync_data = {scrambled_data [5:0],internal_reg[1:0]};
                  saved_data = scrambled_data[7:6];
                  internal_reg_en = 1'b1;
	  	          end
	  	          else begin
	  	            sync_data = scrambled_data;  
	  	          end
	          end
/////////////////// 4 bits saved in internal reg ////////////////////
	  3'b011: begin
	            if(symbol_cnt == 4'b0)begin
                if(serdes)begin
                  sync_data = {scrambled_data [1:0],sync_header, internal_reg[3:0]};
                  reg_ptr_en = 1'b1;
                  ptr = 3'b101;
                  saved_data = scrambled_data[7:2];
                  internal_reg_en = 1'b1;	
                  end
                else begin
                  sync_data = scrambled_data;
                  reg_ptr_en = 1'b1;
                  ptr = 3'b101;
                end			
	  	        end
	  	        else 
	  	          if(serdes)begin
                  sync_data = {scrambled_data [3:0],internal_reg[3:0]};
                  saved_data = scrambled_data[7:4];
                  internal_reg_en = 1'b1;
	  	          end
	  	          else begin
	  	            sync_data = scrambled_data;
	  	          end
	          end
/////////////////// 6 bits saved in internal reg ////////////////////
	  3'b101: begin
	            if(symbol_cnt == 4'b0)begin
                if(serdes)begin
                sync_data = {sync_header, internal_reg[5:0]};
                reg_ptr_en = 1'b1;
                ptr = 3'b111;
                saved_data = scrambled_data;
                internal_reg_en = 1'b1;
                reint_cnt = 1'b1;	
                end
                else 
                begin
                  sync_data = scrambled_data;
                  reg_ptr_en = 1'b1;
                  ptr = 3'b111;
                  reint_cnt = 1'b1;	
                end			
	  	        end
	  	        else 
	  	          if(serdes) begin
                  sync_data = {scrambled_data [1:0],internal_reg[5:0]};
                  saved_data = scrambled_data[7:2];
                  internal_reg_en = 1'b1;
	  	          end
	  	          else begin
	  	            sync_data = scrambled_data;			          
	  	          end
	        end
/////////////////// 8 bits saved in internal reg ////////////////////
	  3'b111: begin
              if(serdes)begin
                sync_data = internal_reg;
              end
              else begin
                sync_data = scrambled_data;
              end
                reg_ptr_en = 1'b1;
                ptr = 3'b000;
	          end
    endcase 
  end 	  
end

/////////////////// register the remaining bits of current input data ////////////////////
always @(posedge clk or negedge rst) begin
  if(!rst) begin 
    internal_reg <= 3'b0;
  end
  else if (internal_reg_en) begin
    internal_reg <= saved_data;
  end	  
end

/////////////////// register the value of the internal reg pointer ////////////////////
always_ff @(posedge clk or negedge rst) begin
  if(!rst) begin 
    reg_ptr <= 3'b0;
  end
  else if (reg_ptr_en) begin
    reg_ptr <= ptr;
  end	  
end

/////////////////// symbol counter ////////////////////
always_ff @(posedge clk or negedge rst) begin 
  if (!rst) begin 
    symbol_cnt <= 4'b0;
  end
  else if (reint_cnt) begin
    symbol_cnt <= 'b1;
  end
  else if (enable && !back_pressure) begin
      symbol_cnt <= symbol_cnt + 1'b1;	
  end
end

endmodule 
