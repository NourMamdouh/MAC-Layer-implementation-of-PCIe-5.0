/*-----------------------------------------------------------------------------
This module operates in the recovered clk domain (rx_clk)and has the following functions:
1- monitors for the EIEOS to make the transition to aligned phase and define block boundary
2- once aligned, it keeps on checking the alignment by verfiying the SKP symbols received and
   the sync header.
3- Monitor for SDS pattern and once received it transition to the locked_phase.
-----------------------------------------------------------------------------*/
 
module BA_FSM #(
  DATA_WIDTH         = 'd8,
  SYMBOL_COUNT_WIDTH = 'd4, 
  BITS_COUNT_WIDTH   = 'd3
) (
  input  logic                               rx_clk, rx_rst,
  input  logic 								 enable,
  input  logic  [DATA_WIDTH -1 :0]           rx_data,
  input  logic           					 flag,
  input  logic  [SYMBOL_COUNT_WIDTH -1 :0]   symbols_count,
  input  logic  [BITS_COUNT_WIDTH -1 :0]     bits_count,
  input  logic		     				     Soft_RST_blocks,
  input  logic 		     				     rst_BA,
  output logic                               cnt_bits_en,
  output logic                               cnt_symbols_en, 
  output logic                               reint_cnt_bits, 
  output logic                               reint_cnt_symbols,
  output logic                               reg_block_type, 
  output logic                               elstc_buff_en, 
  output logic                               error, 
  output logic                               flag_en, 
  output logic                               rst_flag
);                    
  
localparam  symbol_zero = 8'h00;
localparam  symbol_one  = 8'hFF;



logic [2:0] current_state, next_state;
logic       flag_state, reg_flag_state, flag_state_en;
logic       block_type, reg_block_typ_en;
logic       error_comb, error_en;
      
			                      
localparam  unaligned_phase   = 3'b000,
		    monitor_EIEOS     = 3'b001,
		    aligned_phase     = 3'b011,
		    waiting_for_SDS   = 3'b010,
		    monitor_SDS       = 3'b110,
		    locked_phase_sync = 3'b111,
		    locked_phase_data = 3'b101,
		    monitor_SKP       = 3'b100;

localparam SKP     = 8'h99;
localparam SKP_CTL = 8'h78;
localparam SKP_END = 8'hE1;
localparam SDS_ID  = 8'hE1;
localparam SDS     = 8'h87; 

localparam last_bit    = 3'd7;
localparam last_symbol = 4'd15;

localparam sync_data = 2'b01;
localparam sync_OS   = 2'b10;

// state transition
always_ff @(posedge rx_clk or negedge rx_rst) begin
	if (!rx_rst) begin
		current_state <= unaligned_phase;
	end
	else if (Soft_RST_blocks) begin
		current_state <= unaligned_phase;
	end
	else if (enable)
		current_state <= next_state;       
end

//next_state logic
always_comb begin
	cnt_bits_en       = 1'b0;
	reint_cnt_bits    = 1'b0;
	reint_cnt_symbols = 1'b0;
	elstc_buff_en     = 1'b0;
	block_type        = 1'b0;
	error_comb        = 1'b0;
	error_en          = 1'b0;
	flag_state        = 1'b0;
	flag_state_en     = 1'b0;
	flag_en           = 1'b0;
	reg_block_typ_en  = 1'b0;
	cnt_symbols_en    = 1'b0;
	rst_flag          = 1'b0;

	case(current_state)  
	unaligned_phase : begin
						if ((rx_data == symbol_zero) && !flag) begin
							next_state = monitor_EIEOS;
							flag_en = 1'b1;
							cnt_symbols_en = 1'b1;
						end else begin
							next_state = unaligned_phase;
						end
	end
								
	monitor_EIEOS : begin
						cnt_bits_en = 1'b1;
						flag_en = 1'b1; 
						if (bits_count == last_bit)
							if ((rx_data == symbol_zero && !flag) | (rx_data == symbol_one && flag)) begin
								if (symbols_count == last_symbol)begin
									next_state = aligned_phase;
								end else begin
									next_state = monitor_EIEOS;
								end
							end else begin
								next_state = unaligned_phase;
								rst_flag = 1'b1;
								reint_cnt_bits = 1'b1;
								reint_cnt_symbols = 1'b1;
							end
						else begin
							next_state = monitor_EIEOS;
						end				   
	end

	aligned_phase : begin   
						cnt_bits_en = 1'b1;
						if (bits_count == 2'b01) begin
							if (rx_data[7:6] == sync_OS) begin
								next_state = waiting_for_SDS;
								reint_cnt_bits = 1'b1;
								block_type = 1'b1;
								reg_block_typ_en = 1'b1;
							end else begin
								next_state = unaligned_phase;
								rst_flag = 1'b1;
								reint_cnt_bits = 1'b1;					                       
								reint_cnt_symbols = 1'b1;
							end
						end else 
							next_state = aligned_phase;
	end

	waiting_for_SDS : begin
						cnt_bits_en = 1'b1 ;
						flag_state = 1'b1;
						flag_state_en = 1'b1;
						if (bits_count == last_bit) begin
							elstc_buff_en = 1'b1;
							case (symbols_count)
							'd0: begin
								if (rx_data == SDS_ID &&  reg_block_type )begin
									next_state = monitor_SDS;							
								end
								else if (rx_data == SKP && reg_block_type )begin
									next_state = monitor_SKP;
								end else begin
								next_state = waiting_for_SDS;  						
								end
							end
							'd15: begin
								next_state = aligned_phase;	 
							end
							default: begin
								next_state = waiting_for_SDS ; 
							end
							endcase 						
						end else 
							next_state = waiting_for_SDS;
						end
					
	monitor_SKP : begin
					cnt_bits_en = 1'b1;
					if (bits_count == last_bit) begin
						elstc_buff_en = 1'b1 ;
						case (symbols_count)
						'd12 : begin 
							if ((rx_data == SKP_END) ||(rx_data == SKP_CTL) ) begin
								next_state = monitor_SKP;							   
							end
							else begin 
								next_state = unaligned_phase;
								rst_flag = 1'b1; 
								reint_cnt_bits = 1'b1;
								reint_cnt_symbols = 1'b1;							 
							end 
						end
						'd12,'d13,'d14 : begin
							next_state = monitor_SKP;		 
						end
						'd15 : begin
							if (reg_flag_state) begin
								next_state = aligned_phase;	
							end else begin  
								next_state = locked_phase_sync;	
							end 
						end 
						default: begin
							if (rx_data == SKP) begin
								next_state = monitor_SKP;
							end
							else begin
								next_state = unaligned_phase;
								rst_flag = 1'b1;
								reint_cnt_bits = 1'b1;
								reint_cnt_symbols = 1'b1;
							end  
						end
						endcase
					end else begin 
						next_state = monitor_SKP;
					end
	end
					
	monitor_SDS :  begin 
						cnt_bits_en = 1'b1;
						if (bits_count == last_bit) begin
							elstc_buff_en = 1'b1 ;
							if  (rx_data == SDS) begin
								if (symbols_count == last_symbol) begin            
									next_state = locked_phase_sync;						   
								end
								else begin
									next_state = monitor_SDS;
								end
							end
							else begin
								next_state = unaligned_phase;
								reint_cnt_bits = 1'b1;
								rst_flag = 1'b1;
								reint_cnt_symbols = 1'b1;
							end
						end else begin
							next_state = monitor_SDS;
						end
	end  
				
	locked_phase_sync : begin 
							cnt_bits_en = 1'b1;
							if (bits_count == 2'b01) begin
								if (rx_data[7:6] == sync_data)begin
									next_state = locked_phase_data;
									reint_cnt_bits = 1'b1;
									block_type = 1'b0; //data
									reg_block_typ_en = 1'b1;
								end
								else if (rx_data[7:6] == sync_OS) begin
									next_state = locked_phase_data;
									reint_cnt_bits = 1'b1;
									block_type = 1'b1; //ordered_set
									reg_block_typ_en = 1'b1;
								end
								else begin
									error_comb = 1'b1;
							        error_en = 1'b1;
									next_state = unaligned_phase;
									rst_flag = 1'b1;
									reint_cnt_bits = 1'b1;
									reint_cnt_symbols = 1'b1;
								end
							end else begin 
								next_state = locked_phase_sync;
							end
	end
						
	locked_phase_data : begin
							cnt_bits_en = 1'b1 ;
							flag_state = 1'b0;
							flag_state_en = 1'b1;
							if (bits_count == last_bit) begin
								elstc_buff_en = 1'b1;
								if (symbols_count == last_symbol)begin
									next_state = locked_phase_sync;							  
								end
								else if ((symbols_count == 'b0) && (rx_data == SKP) && (reg_block_type == 1'b1)) begin
									next_state = monitor_SKP;
								end else begin 
									next_state = locked_phase_data; 
								end 						
							end else begin 
								next_state = locked_phase_data;
							end
	end
	endcase
end

always_ff @(posedge rx_clk or negedge rx_rst ) begin
	if (!rx_rst) begin
		reg_block_type <= 'b1;
		error <= 0;
	end 
	else if(rst_BA) begin
		reg_block_type <= 1;
		error <= 0;
	end
	else begin 
		if (reg_block_typ_en)
			reg_block_type <= block_type;
		if (error_en)
			error <= error_comb;
	end
end	

always_ff @(posedge rx_clk or negedge rx_rst) begin
	if (!rx_rst) begin
		reg_flag_state <= 'b1;	
	end 
	else if (Soft_RST_blocks) begin
		reg_flag_state <= 'b1;
	end
	else if (flag_state_en)
		reg_flag_state <= flag_state;
end


endmodule
