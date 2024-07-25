module LTSSM #(
SYMBOL_WIDTH		= 'd8,   // in bits
state_width		= 'd5,
LANES_NUM			= 'd32   // max number of lanes
)
(
input 							  clk,rst,

//*********************************Interface with Data Link Layer*********************************\\
output logic       				  O_Link_Up,
output logic       				  O_Retrain_succ,
output logic [0:1] 				  O_Actual_pwr,
input 		 [0:1] 				  I_Pwr_States,
//asserted when a link recovery process is initiated by MAC layer
output logic 	   				  Physical_recovery,	
//asserted when a link recovery process is requested by DL layer
input 			   				  Retrain,				

//*********************************Interface with Rx*********************************\\
output logic 					  PIPE_CNT_rst,
output logic 					  rst_BA,
input  logic 					  Block_Type,
// packet filter enable, to be raised whe data is expected
output logic 					  PF_EN,
//block alignment enable, to be raised after changing rate to 32GT/s
output logic 					  BA_EN,
// output from PF, to be raised when an EIEOS ID is seen which means link partner has enetred recovery
input  logic					  EIEOS_Flag,
//aasserted when a receiver error is detected
input 		       				  phy_rx_error,		

//*********************************Interface with Tx*********************************\\
// to enable sending OSs
output logic 					  os_enable,
// to enable Tx blocks for data and OS transmission
output logic 					  o_EN_blocks,
// to reset the idle counter when needed
output logic 				      IDL_rst,
// asserted when 16 idles are sent successfully
input  logic 					  ack_idle,
// ro be raised when 16 idles are to be sent during link training
output logic 					  idle_16,


//*********************************Interface with PIPE*********************************\\
output logic 			          o_PIPE_rst,
// to instruct the pipe to start receiver detection
output logic [0:(LANES_NUM-1)] 	  O_St_Detect,
// to inform the pipe of the power current power state
output logic [1:0] 				  powerDown_PIPE [0:(LANES_NUM-1)],
// to change the rate when needed
output logic [2:0] 				  O_rate_PIPE,
// to indicate wherther a receiver is detected oe not
input  logic [0:(LANES_NUM-1)]    I_Rcv_Deteted,
// to indicate whether any lane got out of electrical idle
input  logic [0:(LANES_NUM-1)] 	  I_RX_EIdle,
// to force the pipe to go into electrical idle when needed
output logic [0:(LANES_NUM-1)]    TxElecIdle_PIPE ,
// to be asserted when pipe succefully reponds to the given instructions
input  logic 					  I_PhyStatus,

//*********************************interface with decoder*********************************\\
input 		 [0:(LANES_NUM-1)] 	  pad_link_flag ,
input 		 [0:3]  			  cons_count [32],
input 			   				  disable_reg,loopback,
input 		 [0:(SYMBOL_WIDTH-1)] link_num [32],
input 		 [0:(LANES_NUM-1)] 	  done_cnt,
input 		 [0:(LANES_NUM-1)] 	  type_OS_dec ,
input 		 [0:(SYMBOL_WIDTH-1)] UpConfig_DataR ,
output logic [0:(LANES_NUM-1)] 	  controller_stop,
output logic 			          controller_rst,  
output logic [0:(SYMBOL_WIDTH-1)] rcv_link_num,
output logic [0:state_width-1] 	  current_state,
input  logic [0:(LANES_NUM-1)]    recovr_speedequ_config,
input  logic [0:(LANES_NUM-1)]    recovr_recvrconfg,
input  logic 					  type_IDL_TS,
output logic 					  directed_speed_change,


//*********************************interface with OS creator*********************************\\
// to specify how many times an OS is to be sent
output logic [0:1] 				  repetion,
// asserted when the desired number of ordered sets is sent
input 							  ack,
// asserted whenever its the last symbol time of the os
input  logic 					  os_creator_done,
// to reset ack flag
output logic 				      reset_ack,
// to specify the type of os to be sent
output logic [0:2] 				  type_OS,
// to reset the os symbols count when needed
output logic 					  LTSSM_Count_rst,
// used whenn sending TS2, to specfiy whether the type_OS appllies for all lanes or only one lane (lane0) 
output logic 					  type_os_one_lane,   
// to instruct the os_creator whether to use pad in the lane number field in TS
output logic [0:(LANES_NUM-1)] 	  lane_pad,
// to instruct the os_creator whether to use pad in the link number field in TS
output logic [0:(LANES_NUM-1)] 	  link_pad,


//*********************************interface with Timer*********************************\\
input 							  time_out1,
input 							  time_out2, 
input  logic 					  timeout3,
output logic 					  start_speed_neg,
output logic [0:2] 				  time_value1,
output logic 					  time_value2,
output logic 					  start,


//*********************************Interface with SKP scheduler*********************************\\
output logic 					  skp_rst,

//*********************************common signals*********************************\\
output logic 					  Soft_RST_blocks, 
input 							  gen,
output logic 					  o_config_lanes
);		  


logic 		[0:state_width-1]  	  next_state;
// to store the lanes that have detected a receiver
logic 		[0:(LANES_NUM-1)] 	  detection_lanes_comb ;
logic 		[0:(LANES_NUM-1)] 	  detection_lanes ;
logic 		       		          detection_lanes_EN;
// to store the link number agreed upon during link training
logic 		[0:(SYMBOL_WIDTH-1)]  rcv_link_num_comb;
logic 		       				  enable_link_num; 
// to store which lanes have recieved non pad link or lane number to be used later for lane configuration
logic 		[0:(LANES_NUM-1)] 	  non_pad_link_lanes, non_pad_link_lanes_comb;
logic 				 			  non_pad_link_lanes_enable;
// to indicate which lanes whose desired received conseccutive OS count is reached, for the sake of state transistion
logic 		[0:(LANES_NUM-1)] 	  exit_state ;
// to be used to statt counting on the number of transmitted OSs in the cases where this count should not be accounted for until an OS of specific characteristics is recieved first
logic 		[0:(LANES_NUM-1)] 	  start_TX_count ;
// this flag is asserted whenver the the decoder cons_count is one to indicate the receprion of one os of the desired characteristics
logic 		       				  one_TS_rec ;
// this signal is to reset the one_ts_rec when needed
logic 		       				  sync_reset ;
//to store the current power state
logic 		[0:1]	 			  O_Pwr_States [0:(LANES_NUM-1)];
logic 		[0:(LANES_NUM-1)] 	  powerDown_EN; // POWER dOWEn enable
logic 		[1:0] 				  powerDown_comb [0:(LANES_NUM-1)];
// to store the settings for TxElecIdle_PIPE
logic 		[0:(LANES_NUM-1)] 	  TxElecIdle_comb;
logic 		[0:(LANES_NUM-1)] 	  TxElecIdle;
logic 		[0:(LANES_NUM-1)] 	  TxElecIdle_EN;
// to store the settings for O_Link_Up
logic 		 					  O_Link_Up_Comb;
logic 		 					  link_up_EN;
// to store the settings for directed_speed_change veriable used in recovery
logic 		 					  directed_speed_change_comb;
logic 		 					  directed_speed_change_EN;
// to store the settings for changed_speed_recovery veriable used in recovery
logic 							  changed_speed_recovery;
logic 							  changed_speed_recovery_EN;
logic 							  changed_speed_recovery_comb;
// to be used to determine lane configuration (o_config_lanes) (32 or 1)
logic 							  config_lanes;
// to specify the number of desired consecuitive OSs to be received in each state so that exit_state could be set accordingly
logic 		[3:0] 				  consec_num;
// to be used in config_idle to indicate whether this state is entered due to a timeput in config_complete sttate
logic 							  timeout_complete, timeout_complete_comb, timeout_complete_EN;
// to store the settings for successful_speed_negotiation veriable used in recovery
logic 							  successful_speed_negotiation, successful_speed_negotiation_comb , successful_speed_negotiation_en;
// to store the settings for O_rate
logic 		[0:2] 				  O_rate_comb  , O_rate;
logic 							  O_rate_enable;
// to store the settings for BA_EN and PF_EN
logic 							  BA_EN_comb , BA_EN_enable , PF_EN_comb , PF_EN_enable;
// to keep physical_recovery asserted to DLL while link recovery due to receiver errors
logic 							  physical_recovery_comb, physical_recovery_reg, enable_physical_recovery;


//LTSSM states
localparam 						  Reset = 'd0,
								  detect_again = 'd1,
								  detect_rate_change = 'd2,
								  detect_time_1ms = 'd3,
								  detect_quiet = 'd4, 
								  detect_active = 'd5 ,
								  pre_polling = 'd6,
								  polling_active = 'd7,
								  polling_config = 'd8,
								  config_linkwidth_start = 'd9,
								  config_linkwidth_accept = 'd10,
								  config_lanenum_wait = 'd11,
								  config_lanenum_accept = 'd12,
								  config_complete = 'd13,
								  config_idle = 'd14,
								  config_idle_2 = 'd15,
								  recovery_idle_skp ='d16,  
								  recovery_idle_sds = 'd17,
								  recovery_idle_idl = 'd18,
								  recovery_rcvrconfig = 'd19,
								  recovery_rcvrlock = 'd20,
								  recovery_speed_EIOS = 'd21,
								  recovery_speed_TX_IDLE = 'd22,
								  recovery_speed_RX_IDLE = 'd23,
								  recovery_speed_power_up = 'd24,
								  recovery_speed_rate_change = 'd25,
								  recovery_speed_wait_neg = 'd26,
								  recovery_speed_EIEOS = 'd27,
								  pre_recovery = 'd28,
								  L0 = 'd29;
		  
// for os_type
localparam 						  TS1 = 1'b0 , TS2 = 1'b1 ;
localparam 						  SDS = 2;
localparam 						  CTL_SKP = 3;
localparam 						  EIOS = 4  , EIEOS = 5;
// for lane configuration
localparam 						  MAX_LANES = 'd1 , ONE_LANE = 'd0 ;
// for os_creator repetition
localparam 					      infinity = 'b00, rep_1024 ='b01 , rep_16 = 'b10, rep_32 = 'b11;
// for gen signal
localparam 						  HIGH_GEN = 1, LOW_GEN =0;
// timer time value in ms
localparam 						  t12 = 'b00 , t24 = 'b01 , t2 = 'b10 , t48 = 'b11;
// for power pipe power states
localparam 						  p0 = 'b00 , p1 = 'b10 , p0s = 'b01 ;
// for block type values
localparam						  BLOCK_TYPE_DATA = 1'b0;
localparam						  BLOCK_TYPE_OS 	= 1'b1;

//**********************************************************************************************************************
//***********************************************internal needed storage***********************************************
//**********************************************************************************************************************

always_ff @(posedge clk , negedge rst)begin
	if(!rst)begin
	  for(int i=0 ; i<32 ; i++) begin 
		O_Pwr_States [i] <= 0;
	  end
		TxElecIdle <= 0;
		changed_speed_recovery <= 0;
		O_rate <= 0;
		BA_EN <= 0;
		PF_EN <= 0;
	end
	else begin
		for(int i = 0 ; i < 32 ; i ++ )begin
			if(powerDown_EN[i])begin
				O_Pwr_States[i] <= powerDown_comb[i];
			end
			if(TxElecIdle_EN[i])begin
				TxElecIdle[i] <= TxElecIdle_comb[i];
			end
		end
		if(changed_speed_recovery_EN)begin
			changed_speed_recovery <= changed_speed_recovery_comb;
		end
		if(O_rate_enable)begin
			O_rate <= O_rate_comb;
		end
		if(BA_EN_enable)begin
			BA_EN <= BA_EN_comb;
		end
		if(PF_EN_enable)begin
			PF_EN <= PF_EN_comb;
		end
	end

end

always_ff @(posedge clk , negedge rst)begin
	if(!rst)begin
		directed_speed_change <= 0;
		O_Link_Up <= 0 ;
		timeout_complete <= 0;
		detection_lanes <= 0;
		rcv_link_num <= 0;
		non_pad_link_lanes <= 0;
		successful_speed_negotiation <= 0;
		physical_recovery_reg <= 0;
	end
	else begin
		if(directed_speed_change_EN)begin
			directed_speed_change <= directed_speed_change_comb;
		end
		if(link_up_EN)begin
			O_Link_Up <= O_Link_Up_Comb;
		end
		if(detection_lanes_EN)begin
			detection_lanes <= detection_lanes_comb;
		end
		if (enable_link_num) begin
			rcv_link_num <= rcv_link_num_comb ;
 		end
		if(non_pad_link_lanes_enable)begin
			non_pad_link_lanes <= non_pad_link_lanes_comb;
		end
		if (timeout_complete_EN) begin
			timeout_complete <= timeout_complete_comb ;
		end
		if (successful_speed_negotiation_en) begin
			successful_speed_negotiation <= successful_speed_negotiation_comb;
		end
		if (enable_physical_recovery) begin
			physical_recovery_reg <= physical_recovery_comb; 
		end
	end
end


always_ff @(posedge clk or negedge rst) begin
	if(!rst)begin
		one_TS_rec <= 1'b0 ;
	end
	else if(sync_reset)begin
		one_TS_rec <= 1'b0 ;
	end
	else if (start_TX_count != 0 ) begin  
		one_TS_rec <= 1'b1 ;
	end
end

//**********************************************************************************************************************
//***********************************************Current_state logic***********************************************
//**********************************************************************************************************************

always_ff @(posedge clk or negedge rst) begin
	if(!rst)begin
		current_state <= Reset ;
	end
	else begin
		current_state <= next_state ;
	end
end

//**********************************************************************************************************************
//***************************************internal needed logic for state transitions***********************************
//**********************************************************************************************************************

always_comb begin        
	exit_state = 0 ;
	start_TX_count = 0;
	for(int i=0;i<32;i++) begin
	if(cons_count[i] == consec_num) begin
		exit_state[i] = 1'b1 ; // which means the corresponding lane received the desired number of consecuitive OSs
	end
	else begin
		exit_state[i] = 1'b0 ;
	end

	if(cons_count[i] == 4'b0001) begin
		start_TX_count[i] = 1'b1;  // which means one Os of the desired characteristics is received on that lane so that one_TS_rec could be set and sent_os count in OS_creator could be started
	end
	else begin
		start_TX_count[i] = 1'b0;
	end
	end
end
//after finishing initial traiing, non_pad_link_lanes stores the final indicators for lane configuration
//the leftmost indicator is for lane 0
assign config_lanes = (non_pad_link_lanes == {1'b1,{(LANES_NUM-1){1'b0}}})? ONE_LANE : MAX_LANES ;


//**********************************************************************************************************************
//*******************************************next_state && Rx side logic************************************************
//**********************************************************************************************************************

always_comb begin
	// outputs and next_state default values
	for (int i =0; i<32; i++) begin
	powerDown_comb[i] = p0;
	end
	TxElecIdle_comb = 'd0;
	powerDown_PIPE  =  O_Pwr_States;
	TxElecIdle_PIPE = TxElecIdle;
	o_config_lanes = MAX_LANES;
	start = 1'b0;
	time_value1 = 'd0;
	time_value2 = 'd0;
	o_PIPE_rst = 'd0;
	powerDown_EN = 'd0;
	TxElecIdle_EN = 'd0;
	sync_reset = 'd0; 
	O_Link_Up_Comb = 'd0; 
	link_up_EN = 'd0;
	directed_speed_change_comb = 'd0;
	directed_speed_change_EN = 'd0;
	changed_speed_recovery_EN = 'd0;
	changed_speed_recovery_comb = 'd0;
	successful_speed_negotiation_comb = 'd0;
	successful_speed_negotiation_en = 'd0;
	detection_lanes_comb = 'd0;
	detection_lanes_EN = 'd0;
	rcv_link_num_comb = 'd0;
	enable_link_num = 'd0;
	non_pad_link_lanes_enable = 'd0;
	next_state = L0;
	PIPE_CNT_rst = 1'b0;
	non_pad_link_lanes_comb = 'd0;
	consec_num = 'd0;
	timeout_complete_comb= 'd0; 
	timeout_complete_EN = 'd0;
	O_St_Detect = 'd0;
	controller_rst = 'b0;
	reset_ack = 'b0;
	LTSSM_Count_rst = 'b0;
	o_EN_blocks = 'b1;
	skp_rst = 'd0;
	IDL_rst = 'd1;
	O_rate_comb = 0;
	O_rate_enable = 0;
	O_rate_PIPE = O_rate;
	BA_EN_comb = 0;
	BA_EN_enable = 0;
	PF_EN_comb = 0;
	PF_EN_enable = 0;
	Soft_RST_blocks = 0;
	O_Retrain_succ = 0;
	controller_stop = exit_state;
	start_speed_neg = 1'b0;
	O_Actual_pwr = p0;
	Physical_recovery = physical_recovery_reg;
	enable_physical_recovery = 1'b0;
	physical_recovery_comb = 1'b0;
	rst_BA = 1'b0;

	case(current_state) 

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	Reset:begin
		o_EN_blocks = 'b0;
		for(int i= 0; i <32; i++) begin
		powerDown_comb[i] = p1;
		powerDown_PIPE [i] = p1;
		end
		TxElecIdle_comb = {(LANES_NUM){1'b1}};
		TxElecIdle_PIPE = {(LANES_NUM){1'b1}};

		if(I_PhyStatus == 0) begin  // which indicates clock is ready and stable
			next_state = detect_quiet;
			//power down all lanes and force electrical idle on Tx lanes before going to detect
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_EN = {(LANES_NUM){1'b1}};
			//start detect timer
			start = 'b1;
			time_value1 = t12;
			o_PIPE_rst = 0;
		end
		else begin
			o_PIPE_rst = 1;
			next_state = Reset;
		end	
	end
	
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
	detect_rate_change:begin // entered when transitioning back to detect from any state when current speed is not 2.5GT/s
		o_EN_blocks = 'b0;
		O_rate_comb = 'b000; // 2.5GT/s
		O_rate_enable = 1'b1; // to change the rate back to 2.5
		O_rate_PIPE = 'b000;

		if(I_PhyStatus)begin  //which indicates rate is successfully changed 
			if(time_out2)begin // 1ms
				next_state = detect_quiet;
				start = 1'b1;
				time_value1 = t12;
			end
			else begin
				next_state = detect_time_1ms;  // since 1ms must pass before starting receiver detection
			end
		end
		else begin
			next_state = detect_rate_change;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	detect_time_1ms: begin
		o_EN_blocks = 'b0;
		if(time_out2)begin
			next_state = detect_quiet;
			start = 1'b1;
			time_value1 = t12;
		end
		else begin
			next_state = detect_time_1ms;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	detect_quiet: begin
		// clear all counters and internal variables and flags
		o_EN_blocks = 'b0;
		sync_reset = 1'b1 ;
		reset_ack = 1'b1;
		controller_rst = 'b1;
		O_Link_Up_Comb = 1'b0;
		link_up_EN = 1;
		directed_speed_change_comb = 'b0;
		directed_speed_change_EN = 1'b1;
		if(time_out1 || (~I_RX_EIdle) != 0) begin // which means some Rx lanes have gor out of electrical idle
			next_state = detect_active;					
		end
		else begin
			next_state = detect_quiet;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	detect_active: begin
		o_EN_blocks = 'b0;
		O_St_Detect = {(LANES_NUM){1'b1}}; // start receiver detection on all lanes

		if(I_PhyStatus)begin //receiver detection operation is completed
		if((I_Rcv_Deteted == {(LANES_NUM){1'b1}})) begin  // all lanes detected a receiver
			next_state = pre_polling; // to raise TX power for Tx power transmission
			detection_lanes_comb = I_Rcv_Deteted;
			detection_lanes_EN = 1;
		end 
		else if(I_Rcv_Deteted != 0 && I_Rcv_Deteted[0] != 0) begin // some lanes detected a receiver (lane0 included)
			detection_lanes_comb = I_Rcv_Deteted;
			next_state = detect_again;  
			detection_lanes_EN = 1;
			start = 1;
			time_value1 = t12;
		end
		else begin
			next_state = detect_quiet;
			start = 1'b1;
			time_value1 = t12;
		end
		end
		else begin
			next_state = detect_active;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////				 	
	detect_again: begin
		o_EN_blocks = 'b0;
		if(time_out1)begin //recievr detection should not start before 12 ms
			O_St_Detect = {(LANES_NUM){1'b1}};
			if(I_PhyStatus)begin
				if((I_Rcv_Deteted == detection_lanes))begin //same previously detected lanes
					next_state = pre_polling;
				end
				else begin
					next_state = detect_quiet;  // receiver detection failed
					start = 1'b1;
					time_value1 = t12;
				end
			end
			else begin
				next_state = detect_again;
			end
		end
		else begin
			next_state = detect_again;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	pre_polling : begin
		o_EN_blocks = 'b0;
		skp_rst = 'd1;
		powerDown_EN = detection_lanes;  // only raise tx power for those lanes that detected a receiver
		TxElecIdle_comb = {(LANES_NUM){1'b0}} ;
		TxElecIdle_PIPE = {(LANES_NUM){1'b0}};
		TxElecIdle_EN= detection_lanes;  // only detected lanes are allowed to exit electrical idle
		reset_ack = 'b1;
		for(int i= 0; i <32; i++) begin
		powerDown_comb[i] = p0;
		powerDown_PIPE [i] = p0;
		end

		if(I_PhyStatus)begin // power is raised
			LTSSM_Count_rst = 1'b1;
			next_state = polling_active;
			start = 1'b1 ;
			time_value1 = t24 ; 
		end
		else begin
			next_state = pre_polling;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	polling_active: begin 
		consec_num = 'd8; // desired number of consecuitive received Os of special characteristics known to the decoder
		sync_reset = 'd1 ; 
		if(exit_state == detection_lanes && ack && (os_creator_done == 'd1 )) begin // all detected lanes hit exit state
			next_state = polling_config ;
			controller_rst = 'd1;
			start = 1'b1 ;
			time_value1 = t48 ; 
			reset_ack = 1'b1 ;
		end
		else if(time_out1 && (os_creator_done == 'd1 )) begin
			if(exit_state != 0 && ack ) begin // some detected lanes hit exit state
				next_state = polling_config ;
				controller_rst = 'd1;
				start = 1'b1 ;
				time_value1 = t48 ; 
				reset_ack = 1'b1 ;
			end
			else begin
				next_state = detect_quiet ;
				start = 1'b1 ;
				controller_rst = 'd1;
				time_value1 =  t12; 
				reset_ack = 1'b1 ;
			end
		end
		else begin
			next_state = polling_active ;
		end

					
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	polling_config: begin 		
		consec_num =  'd8;
		if(exit_state != 0 &&  (exit_state[0] == 1) && ack && (os_creator_done == 'd1 )) begin // any detected lanes hit exit state
			next_state = config_linkwidth_start ;
			controller_rst = 'd1;
			start = 1'b1 ;
			time_value1 = t24 ; 
			reset_ack = 1'b1 ;
			sync_reset = 1'b1;
		end
		else if(time_out1 && (os_creator_done == 'd1 )) begin
			next_state = detect_quiet ;
			controller_rst = 'd1;
			start = 1'b1 ;
			time_value1 = t12 ; 
			reset_ack = 1'b1 ;
			sync_reset = 1'b1;
		end
		else begin
			next_state = polling_config;
		end             
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_linkwidth_start : begin
		reset_ack = 1'b1;
		sync_reset = 1'b1;
		consec_num = 'd2;
		//////////////////  exit to detect  //////////////////
		if ((time_out1 ||(exit_state != 0 && disable_reg !=0 ))&& (os_creator_done == 'd1 )) begin // any detected lanes hit exit state
			for(int i= 0; i <32; i++) begin
			powerDown_comb[i] = p1;
			powerDown_PIPE [i] = p1;
			end
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_comb = {(LANES_NUM){1'b1}};
			TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
			TxElecIdle_EN= {(LANES_NUM){1'b1}};
			if(gen == HIGH_GEN) begin
			next_state = detect_rate_change;
			start = 1'b1;
			time_value1 = t12;
			time_value2 = 'd1;
			end
			else begin
			next_state = detect_quiet;
			start = 1'b1;
			time_value1 = t12;
			end
		end 
		else begin
			if ( exit_state != 0 &&  (exit_state[0] == 1)&& loopback !=0 && (os_creator_done == 'd1 )) begin
				next_state = detect_quiet;  
				controller_rst = 1'b1; 
				start = 1'b1;
				time_value1 = t2;   
			end 
			else if (exit_state != 0 && (exit_state[0] == 1) && (os_creator_done == 'd1 )) begin //// exit to linkwidth accept ////
				if(done_cnt != 0)begin
					enable_link_num = 1'b1;
					non_pad_link_lanes_enable = 1'b1;
					non_pad_link_lanes_comb = exit_state; 
					next_state = config_linkwidth_accept;
					for(int i =0; i<32; i++) begin 
						if(exit_state[i]) begin
						rcv_link_num_comb = link_num [i];
						end
					end
					controller_rst = 1'b1; 
					start = 1'b1;
					time_value1 = t2; 
				end
				else begin
					next_state = config_linkwidth_start;
				end
			end
			else begin
				next_state = config_linkwidth_start;
			end							
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_linkwidth_accept : begin 
		consec_num = 'd2;
		sync_reset = 1'b1;
		reset_ack = 1'b1;
		if(time_out1) begin
			if(exit_state != 0 && (exit_state[0] == 1) && (os_creator_done == 'd1 )) begin
				next_state =  config_lanenum_wait;
				start = 1'b1 ;
				time_value1 = t2 ; 
				reset_ack = 1'b1 ;
				non_pad_link_lanes_enable = 1'b1;
				non_pad_link_lanes_comb = exit_state;      
				controller_rst = 1'b1;
			end
			else if ((os_creator_done == 'd1 ))begin
				controller_rst = 1'b1;
				for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
				end
				powerDown_EN = {(LANES_NUM){1'b1}};
				TxElecIdle_comb = {(LANES_NUM){1'b1}};
				TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
				TxElecIdle_EN= {(LANES_NUM){1'b1}};
				if(gen == HIGH_GEN) begin
					next_state = detect_rate_change;
					start = 1'b1;
					time_value1 = t12;
					time_value2 = 'd1;
				end
				else begin
					next_state = detect_quiet;
					start = 1'b1;
					time_value1 = t12;
				end
			end

		end
		else begin
			if(exit_state == non_pad_link_lanes && (os_creator_done == 'd1 )) begin
				next_state = config_lanenum_wait ;
				start = 1'b1 ;
				time_value1 = t2 ; 
				reset_ack = 1'b1 ;
				non_pad_link_lanes_enable = 1'b1;
				non_pad_link_lanes_comb = exit_state;
				controller_rst = 1'b1;					 
			end
			else begin
				next_state = config_linkwidth_accept ;
			end
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_lanenum_wait : begin 
		consec_num = 'd2;
		sync_reset = 1'b1;
		reset_ack = 1'b1;
		if(time_out1) begin
			if(exit_state != 0 && exit_state[0] == 1  && (os_creator_done == 'd1 )) begin
				next_state =  config_lanenum_accept;
				controller_rst = 1'b1;
				reset_ack = 1'b1 ;
				non_pad_link_lanes_enable = 'b1;
				non_pad_link_lanes_comb = exit_state;
			end
			else if (os_creator_done == 'd1 )  begin
				controller_rst = 1'b1;
				for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
				end
				powerDown_EN = {(LANES_NUM){1'b1}};
				TxElecIdle_comb = {(LANES_NUM){1'b1}};
				TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
				TxElecIdle_EN= {(LANES_NUM){1'b1}};
				if(gen == HIGH_GEN) begin
					next_state = detect_rate_change;
					start = 1'b1;
					time_value1 = t12;
					time_value2 = 'd1;
				end
				else begin
					next_state = detect_quiet;
					start = 1'b1;
					time_value1 = t12;
				end
			end
		end
		else begin      
			if(exit_state == non_pad_link_lanes && (os_creator_done == 'd1 ) ) begin
				next_state = config_lanenum_accept ;
				controller_rst = 1'b1;
				reset_ack = 1'b1 ;
				non_pad_link_lanes_enable = 'b1;
				non_pad_link_lanes_comb = exit_state;					 
			end
			else begin
				next_state = config_lanenum_wait;
			end
		end
end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_lanenum_accept: begin
		consec_num = 'd2 ;
		reset_ack = 1'b1;
		sync_reset = 1'b1;
		if (exit_state != 0 && (os_creator_done == 'd1 )) begin
			if ((exit_state == non_pad_link_lanes) && (type_OS_dec == {(LANES_NUM){TS2}}) && (pad_link_flag == ~non_pad_link_lanes)) begin
				next_state = config_complete;
				start = 1'b1;
				time_value1 = t2;  
				controller_rst = 1'b1 ;
				if(non_pad_link_lanes != 32'hFFFF_FFFF) begin
					non_pad_link_lanes_comb = {1'b1,{(LANES_NUM-1){1'b0}}} ;
					non_pad_link_lanes_enable = 1'b1 ;
				end
			end
			else if(type_OS_dec == {(LANES_NUM){TS1}} && (pad_link_flag == ~non_pad_link_lanes) && exit_state[0] == 1 ) begin
				next_state = config_lanenum_wait;
				start = 1'b1;
				time_value1 = t2;  
				non_pad_link_lanes_comb = {1'b1,{(LANES_NUM-1){1'b0}}} ;
				non_pad_link_lanes_enable = 1'b1 ;
				controller_rst = 1'b1 ;
			end 
			else begin
				controller_rst = 1'b1;
				for(int i= 0; i <32; i++) begin
					powerDown_comb[i] = p1;
					powerDown_PIPE [i] = p1;
				end
				powerDown_EN = {(LANES_NUM){1'b1}};
				TxElecIdle_comb = {(LANES_NUM){1'b1}};
				TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
				TxElecIdle_EN= {(LANES_NUM){1'b1}};
				if(gen == HIGH_GEN) begin
					next_state = detect_rate_change;
					start = 1'b1;
					time_value1 = t12;
					time_value2 = 'd1;
					end
				else begin
					next_state = detect_quiet;
					start = 1'b1;
					time_value1 = t12;
				end
			end
		end
		else begin
			next_state = config_lanenum_accept ;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_complete:	begin
		consec_num = 'd8;
		changed_speed_recovery_comb = 'd0 ;
		changed_speed_recovery_EN = 'd1;
		
		if(ack && (config_lanes==MAX_LANES) && ((exit_state == {(LANES_NUM){1'b1}})) && os_creator_done)begin
			if (gen == HIGH_GEN) begin
			next_state = config_idle;
			end
			else begin
			next_state = config_idle_2;
			end
			controller_rst = 'd1;
			sync_reset = 'd1;
			reset_ack = 'd1;
			start = 1'b1 ;
			time_value1 = t2 ;
		end
		else if (ack && (config_lanes==ONE_LANE) && exit_state[0] && os_creator_done)begin
			if (gen == HIGH_GEN) begin
			next_state = config_idle;
			end
			else begin
			next_state = config_idle_2;
			end
			controller_rst = 'd1;
			sync_reset = 'd1;
			reset_ack = 'd1;
			start = 1'b1 ;
			time_value1 = t2 ;
			// the rest of the lanes should transistion to electrical idle
			for(int i= 0; i <32; i++) begin
				if(i ==0) begin
			powerDown_comb[i] = p0;
			powerDown_PIPE [i] = p0;
				end
				else begin
					powerDown_comb [i] = p1;
					powerDown_PIPE [i] = p1; 
				end
			end
			powerDown_EN = {1'b0,{(LANES_NUM-1){1'b1}}};
			TxElecIdle_comb = {1'b0,{(LANES_NUM-1){1'b1}}};
			TxElecIdle_PIPE = {1'b0,{(LANES_NUM-1){1'b1}}};
			TxElecIdle_EN= {1'b0,{(LANES_NUM-1){1'b1}}};
		end
		else if(!os_creator_done || !time_out1) begin
			next_state = config_complete;
		end
		else begin
			if(gen==LOW_GEN )begin
				if(gen == HIGH_GEN) begin
					next_state = detect_rate_change;
					start = 1'b1;
					time_value1 = 'd12;
					time_value2 = 'd1;
				end
				else begin
					next_state = detect_quiet;
					start = 1'b1;
					time_value1 = t12;
				end
				
				controller_rst = 'd1;
				sync_reset = 'd1;
				reset_ack = 'd1;
				for(int i= 0; i <32; i++) begin
					powerDown_comb[i] = p1;
					powerDown_PIPE [i] = p1;
				end
				powerDown_EN = {(LANES_NUM){1'b1}};
				TxElecIdle_comb = {(LANES_NUM){1'b1}};;
				TxElecIdle_PIPE = {(LANES_NUM){1'b1}};;
				TxElecIdle_EN= {(LANES_NUM){1'b1}};;
			end
			else begin
				timeout_complete_comb = 1'b1;
				timeout_complete_EN = 1'b1;
				if (gen == HIGH_GEN) begin
				next_state = config_idle;
				end
				else begin
				next_state = config_idle_2;
				end
				controller_rst = 'd1;
				sync_reset = 'd1;
				reset_ack = 'd1;
				start = 1'b1 ;
				time_value1 = t2 ; 
				// the rest of the lanes should transistion to electrical idle ==> if one lane
				if(config_lanes==ONE_LANE)begin
					for(int i= 0; i <32; i++) begin
						if(i== 0) begin
							powerDown_comb[i] = p0;
							powerDown_PIPE [i] = p0;
						end
						else begin 
							powerDown_comb [i] = p1;
							powerDown_PIPE [i] = p1;
						end
					end
					powerDown_EN = {1'b0,{(LANES_NUM-1){1'b1}}};
					TxElecIdle_comb = {1'b0,{(LANES_NUM-1){1'b1}}};
					TxElecIdle_PIPE = {1'b0,{(LANES_NUM-1){1'b1}}};
					TxElecIdle_EN= {1'b0,{(LANES_NUM-1){1'b1}}};	
				end	
			end
		end
	end
				
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_idle : begin
		if(os_creator_done) begin
			next_state = config_idle_2;
		end
		else begin
		next_state = config_idle ;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_idle_2: begin
		IDL_rst = 1'b0;
		consec_num = 'd8 ;
		o_config_lanes = config_lanes;
		if(!time_out1) begin 
			if (gen == LOW_GEN) begin	
				if(((non_pad_link_lanes == 32'hFFFF_FFFF && exit_state == 32'hFFFF_FFFF)
				|| (non_pad_link_lanes[0] == 1'b1  && exit_state[0]== 1'b1)) && ack_idle)begin
					next_state = L0;
					reset_ack = 1'b1;
					controller_rst = 1'b1;
					sync_reset = 1'b1;
					PIPE_CNT_rst = 1'b1;
				end
				else begin
					next_state = config_idle_2 ;
				end
			end 
			else begin
				if(((non_pad_link_lanes == 32'hFFFF_FFFF && exit_state == 32'hFFFF_FFFF)
				|| (non_pad_link_lanes[0] == 1'b1 && exit_state[0]== 1'b1))
				&& !timeout_complete && ack_idle )begin
					timeout_complete_EN = 1'b1;
					timeout_complete_comb = 1'b0;
					next_state = L0;
					reset_ack = 1'b1;
					O_Link_Up_Comb = 1'b1;
					link_up_EN = 1'b1;
					controller_rst = 1'b1;
					PIPE_CNT_rst = 1'b1;
					sync_reset = 1'b1;
				end
				else begin
					next_state = config_idle_2 ;
				end
			end
		end
		else begin //boso 3lyha lma t3mlo el recovery
			controller_rst = 1'b1;
			for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
			end
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_comb = {(LANES_NUM){1'b1}};
			TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
			TxElecIdle_EN= {(LANES_NUM){1'b1}};
			if(gen == HIGH_GEN) begin
				next_state = detect_rate_change;
				start = 1'b1;
				time_value1 = t12;
				time_value2 = 'd1;
				end
			else begin
				next_state = detect_quiet;
				start = 1'b1;
				time_value1 = t12;
			end
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	pre_recovery: begin
			controller_stop = 1'b0;
			o_config_lanes = config_lanes;
			if(gen == LOW_GEN)begin
				if(type_IDL_TS)begin
					next_state = recovery_rcvrlock;
					LTSSM_Count_rst = 1'b0;
					reset_ack = 1'b1;
					sync_reset = 1'b1;
				end
				else begin
					next_state = pre_recovery;
				end
			end
			else begin
				rst_BA = 1'b1;
				if (!Retrain) begin
					enable_physical_recovery = 1'b1;
					physical_recovery_comb = 1'b1;
					Physical_recovery = 1'b1;
				end
				if(ack && os_creator_done)begin
					next_state = recovery_rcvrlock;
					LTSSM_Count_rst = 1'b1;
					reset_ack = 1'b1;
					sync_reset = 1'b1;
					controller_rst = 1'b1;
					start = 1'b1;
					time_value1 = 1'b1;
				end
				else begin
					next_state = pre_recovery;
				end
			end
	end
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_rcvrlock:begin
		o_config_lanes = config_lanes;
		consec_num = 'd8;
		sync_reset = 1'b1;
		reset_ack = 1'b1;
		if(exit_state != 0  && (recovr_recvrconfg == exit_state))begin
			directed_speed_change_comb = 1'b1;
			directed_speed_change_EN = 1'b1;
		end
		if(time_out1 && (os_creator_done == 'd1 ))begin
			if((exit_state == non_pad_link_lanes )&& (recovr_speedequ_config == exit_state))begin
				next_state = config_linkwidth_start;
				start = 1'b1 ;
				time_value1 = t24 ; 
				controller_rst = 1'b1;
			end
			else if((exit_state == non_pad_link_lanes)  && (recovr_recvrconfg == non_pad_link_lanes))begin
				next_state = recovery_rcvrconfig;
				start = 1'b1 ;
				time_value1 = t48 ; 
				controller_rst = 1'b1;
			end
			else begin
				controller_rst = 1'b1;
				for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
				end
				powerDown_EN = {(LANES_NUM){1'b1}};
				TxElecIdle_comb = {(LANES_NUM){1'b1}};
				TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
				TxElecIdle_EN= {(LANES_NUM){1'b1}};
				if(gen == HIGH_GEN) begin
					next_state = detect_rate_change;
					start = 1'b1;
					time_value1 = t12;
					time_value2 = 'd1;
				end
				else begin
					next_state = detect_quiet;
					start = 1'b1;
					time_value1 = t12;
				end
			end
		end
		else begin
			if((exit_state == non_pad_link_lanes )&& (os_creator_done == 'd1 ) && (recovr_speedequ_config == 0)) begin
				next_state = recovery_rcvrconfig;
				start = 1'b1 ;
				time_value1 = t48 ; 
				controller_rst = 1'b1;
			end
			else begin
				next_state = recovery_rcvrlock;
			end
		end
	end
		
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////	  
	recovery_rcvrconfig : begin 
		o_config_lanes = config_lanes;
		consec_num = 'd8;
		successful_speed_negotiation_comb = 1'b1;
		successful_speed_negotiation_en = 1'b1;
		if(time_out1) begin
			for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
			end
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_comb = {(LANES_NUM){1'b1}};
			TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
			TxElecIdle_EN= {(LANES_NUM){1'b1}};
			if(gen == HIGH_GEN) begin
				next_state = detect_rate_change;
				start = 1'b1;
				time_value1 = t12;
				time_value2 = 'd1;
			end
			else begin
				next_state = detect_quiet;
				start = 1'b1;
				time_value1 = t12;
			end				
		end 
		else begin 
			if((exit_state != 0) && (os_creator_done) && ack && !UpConfig_DataR[(SYMBOL_WIDTH-1)] && (type_OS_dec[0] == TS2)) begin
				changed_speed_recovery_comb = 1'b0;
				changed_speed_recovery_EN = 1'b1;
				directed_speed_change_comb = 1'b0;
				directed_speed_change_EN = 1'b1;
				next_state =  recovery_idle_skp;
				start = 1'b1 ;
				time_value1 = t2 ;
				reset_ack = 1'b1 ;
				sync_reset = 1'b1;    
				controller_rst = 1'b1; 
			end
			else if((exit_state != 0) && (os_creator_done) && ack && UpConfig_DataR[(SYMBOL_WIDTH-1)] && (type_OS_dec[0] == TS2))begin
				next_state =  recovery_speed_EIOS ; 
				start = 1'b1;
				time_value1 = t48;
				reset_ack = 1'b1 ;
				sync_reset = 1'b1;    
				controller_rst = 1'b1; 
			end
			else if ((exit_state !=0) && (os_creator_done) && !UpConfig_DataR[(SYMBOL_WIDTH-1)] && (type_OS_dec[0] == TS1)) begin 
				next_state =  config_linkwidth_start ;
				start = 1'b1 ;
				time_value1 = t24;
				reset_ack = 1'b1 ;
				sync_reset = 1'b1;    
				controller_rst = 1'b1; 						
			end
			else begin
				next_state = recovery_rcvrconfig;
			end
		end
	end
		
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
	recovery_speed_EIOS:begin
		o_config_lanes = config_lanes;
		sync_reset = 1'b1;
		if(os_creator_done)begin
			next_state = recovery_speed_TX_IDLE;
			controller_rst = 1'b1;
		end
		else begin
			next_state = recovery_speed_EIOS;
			controller_rst = 1'b1;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_speed_TX_IDLE:begin
		o_config_lanes = config_lanes;
		for(int i= 0; i <32; i++) begin
			powerDown_comb[i] = p1;
			powerDown_PIPE [i] = p1;
		end
		powerDown_EN = {(LANES_NUM){1'b1}};
		TxElecIdle_comb = {(LANES_NUM){1'b1}};
		TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
		TxElecIdle_EN= {(LANES_NUM){1'b1}};
		if(!time_out1)begin
			if(I_PhyStatus)begin
				if(I_RX_EIdle == {(LANES_NUM){1'b1}})begin
					next_state = recovery_speed_rate_change;
					start_speed_neg = 1'b1;
				end
				else begin
					next_state = recovery_speed_RX_IDLE;
				end
			end
			else begin
				next_state = recovery_speed_TX_IDLE;
			end
		end
		else begin
			controller_rst = 1'b1;
			for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
			end
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_comb = {(LANES_NUM){1'b1}};
			TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
			TxElecIdle_EN= {(LANES_NUM){1'b1}};
			if(gen == HIGH_GEN) begin
				next_state = detect_rate_change;
				start = 1'b1;
				time_value1 = t12;
				time_value2 = 'd1;
			end
			else begin
				next_state = detect_quiet;
				start = 1'b1;
				time_value1 = t12;
			end
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_speed_RX_IDLE: begin
		o_config_lanes = config_lanes;
		if(!time_out1)begin
			if(I_RX_EIdle == {(LANES_NUM){1'b1}})begin
				next_state = recovery_speed_rate_change;
				start_speed_neg = 1'b1;
			end
			else begin
				next_state = recovery_speed_RX_IDLE;
			end
		end
		else begin
			controller_rst = 1'b1;
			for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
			end
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_comb = {(LANES_NUM){1'b1}};
			TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
			TxElecIdle_EN= {(LANES_NUM){1'b1}};
			if(gen == HIGH_GEN) begin
				next_state = detect_rate_change;
				start = 1'b1;
				time_value1 = t12;
				time_value2 = 'd1;
			end
			else begin
				next_state = detect_quiet;
				start = 1'b1;
				time_value1 = t12;
			end
		end
		
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_speed_rate_change:begin
		o_config_lanes = config_lanes;
		O_rate_comb = 'b100;
		O_rate_enable = 1'b1;
		O_rate_PIPE = 'b100;	
		if(!time_out1)begin
			if(I_PhyStatus)begin
				if(timeout3)begin
					next_state = recovery_speed_power_up;
				end
				else begin
					next_state = recovery_speed_wait_neg;
				end
			end
			else begin
				next_state = recovery_speed_rate_change;
			end
		end
		else begin
			controller_rst = 1'b1;
			for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
			end
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_comb = {(LANES_NUM){1'b1}};
			TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
			TxElecIdle_EN= {(LANES_NUM){1'b1}};
			if(gen == HIGH_GEN) begin
				next_state = detect_rate_change;
				start = 1'b1;
				time_value1 = t12;
				time_value2 = 'd1;
			end
			else begin
				next_state = detect_quiet;
				start = 1'b1;
				time_value1 = t12;
			end
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_speed_wait_neg:begin
		o_config_lanes = config_lanes;
		if(!time_out1)begin
			if(timeout3)begin
				next_state = recovery_speed_power_up;
			end
			else begin
				next_state = recovery_speed_wait_neg;
			end
		end
		else begin
			controller_rst = 1'b1;
			for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
			end
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_comb = {(LANES_NUM){1'b1}};
			TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
			TxElecIdle_EN= {(LANES_NUM){1'b1}};
			if(gen == HIGH_GEN) begin
				next_state = detect_rate_change;
				start = 1'b1;
				time_value1 = t12;
				time_value2 = 'd1;
				end
			else begin
				next_state = detect_quiet;
				start = 1'b1;
				time_value1 = t12;
			end
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_speed_power_up:begin
		o_config_lanes = config_lanes;
		powerDown_EN = non_pad_link_lanes;
		TxElecIdle_comb = {(LANES_NUM){1'b0}};
		TxElecIdle_PIPE = {(LANES_NUM){1'b0}};
		TxElecIdle_EN= non_pad_link_lanes;
		for(int i= 0; i <32; i++) begin
			powerDown_comb[i] = p0;
			powerDown_PIPE [i] = p0;
		end
		if(!time_out1)begin
			if(I_PhyStatus)begin
				LTSSM_Count_rst = 1'b1;
				BA_EN_enable = 1'b1;
				BA_EN_comb = 1'b1;
				next_state = recovery_speed_EIEOS;
				skp_rst = 1'b1;
				directed_speed_change_comb = 1'b0;
				directed_speed_change_EN = 1'b1;
			end
			else begin
				next_state = recovery_speed_power_up;
			end
		end
		else begin
			controller_rst = 1'b1;
			for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
			end
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_comb = {(LANES_NUM){1'b1}};
			TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
			TxElecIdle_EN= {(LANES_NUM){1'b1}};
			if(gen == HIGH_GEN) begin
				next_state = detect_rate_change;
				start = 1'b1;
				time_value1 = t12;
				time_value2 = 'd1;
			end
			else begin
				next_state = detect_quiet;
				start = 1'b1;
				time_value1 = t12;
			end
		end
		
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_speed_EIEOS:begin
		o_config_lanes = config_lanes;
		if(!time_out1)begin
				if(ack && os_creator_done)begin
					next_state = recovery_rcvrlock;
					start = 1'b1;
					time_value1 = t24;
					controller_rst = 1'b1;
					reset_ack = 1'b1 ;
					sync_reset = 1'b1;
				end
				else begin
					next_state = recovery_speed_EIEOS;
				end
			end
		else begin
			controller_rst = 1'b1;
			for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
			end
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_comb = {(LANES_NUM){1'b1}};
			TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
			TxElecIdle_EN= {(LANES_NUM){1'b1}};
			if(gen == HIGH_GEN) begin
				next_state = detect_rate_change;
				start = 1'b1;
				time_value1 = t12;
				time_value2 = 'd1;
			end
			else begin
				next_state = detect_quiet;
				start = 1'b1;
				time_value1 = t12;
			end
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_idle_skp : begin
		o_config_lanes = config_lanes;
		if(os_creator_done)begin
			if(exit_state!='d0 && (Block_Type==BLOCK_TYPE_OS))begin
				next_state = config_linkwidth_start;
				controller_rst = 'd1;
				start = 1'b1 ;
				time_value1 = t24 ;
				reset_ack = 1'b1 ;
				LTSSM_Count_rst = 1'b1;
			end
			else begin
				next_state = recovery_idle_sds;
			end
		end
		else begin
			next_state = recovery_idle_skp;
		end
		
		if (Block_Type==BLOCK_TYPE_DATA)begin
			sync_reset = 'd0;
			consec_num = 'd8-'d1 ; 
		end
		else begin
			sync_reset = 'd1;
			consec_num = 'd2 ;
		end	
		
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_idle_sds : begin
		o_config_lanes = config_lanes;
		if(os_creator_done)begin
			if(exit_state!='d0 && (Block_Type==BLOCK_TYPE_OS))begin
				next_state = config_linkwidth_start;
				controller_rst = 'd1;
				start = 1'b1 ;
				time_value1 = t24 ;
				reset_ack = 1'b1 ;
				LTSSM_Count_rst = 1'b1;
			end
			else begin
				next_state = recovery_idle_idl;
			end
		end
		else begin
			next_state = recovery_idle_sds;
		end
		
		if (Block_Type==BLOCK_TYPE_DATA)begin
			consec_num = 'd8-'d1 ;
		end
		else begin
			sync_reset = 'd1;
			consec_num = 'd2 ;
		end	
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_idle_idl : begin	
		o_config_lanes = config_lanes;
		IDL_rst = 'd0;
		if(exit_state!='d0)begin
			if(Block_Type==BLOCK_TYPE_OS)begin
				next_state = config_linkwidth_start;
				controller_rst = 'd1;
				start = 1'b1 ;
				time_value1 = t24 ;
				reset_ack = 1'b1 ;
				LTSSM_Count_rst = 1'b1;
			end
			else begin
				if(ack_idle)begin   
					next_state = L0;  
					controller_rst = 'd1;
					O_Retrain_succ = 1'b1;
					O_Link_Up_Comb = 1'b1;
					link_up_EN = 1'b1;
					enable_physical_recovery = 1'b1;
					physical_recovery_comb = 1'b0;
					Physical_recovery = 1'b0;
				end
				else begin
					next_state = recovery_idle_idl;
				end
			end
		end
		else if(time_out1)begin
			next_state = detect_rate_change;
			start = 1'b1;
			time_value1 = t12;
			time_value2 = 'd1;
			controller_rst = 'd1;
			for(int i= 0; i <32; i++) begin
				powerDown_comb[i] = p1;
				powerDown_PIPE [i] = p1;
			end
			powerDown_EN = {(LANES_NUM){1'b1}};
			TxElecIdle_comb = {(LANES_NUM){1'b1}};
			TxElecIdle_PIPE = {(LANES_NUM){1'b1}};
			TxElecIdle_EN= {(LANES_NUM){1'b1}};
		end
		else begin
			next_state = recovery_idle_idl;
		end
		

		if (Block_Type==BLOCK_TYPE_DATA)begin
			consec_num = 'd8-'d1 ;
			if (one_TS_rec)begin
				PF_EN_enable = 'd1;
				PF_EN_comb = 'd1;
			end
			else begin
				PF_EN_enable = 'd1;
				PF_EN_comb = 'd0;
			end
		end
		else begin
			consec_num = 'd2 ;
			sync_reset = 'd1;
		end
	end
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	L0: begin
		controller_stop = 1'b0;
		o_config_lanes = config_lanes;
		if(gen == LOW_GEN)begin
			if(type_IDL_TS)begin
				next_state = recovery_rcvrlock;
				start = 1'b1;
				time_value1 = 1'b1;
				LTSSM_Count_rst = 1'b1;
				reset_ack = 1'b1;
				sync_reset = 1'b1;
			end
			else begin
				LTSSM_Count_rst = 1'b1;
				next_state = pre_recovery;
				start = 1'b1;
				time_value1 = 1'b1;
				directed_speed_change_comb = 1'b1;
				directed_speed_change_EN = 1'b1;
				reset_ack = 1'b1;
				sync_reset = 1'b1;
			end
		end
		else begin
			if(Retrain || EIEOS_Flag || phy_rx_error)begin
				Soft_RST_blocks = 1'b1;
				rst_BA = 1'b0; 
				PF_EN_comb = 1'b0;
				PF_EN_enable = 1'b1;
				LTSSM_Count_rst = 1'b1;
				reset_ack = 1'b1;
				sync_reset = 1'b1;
				controller_rst = 1'b1;
				next_state = pre_recovery;
			end
			else begin
				next_state = L0;
			end
		end
	end

	endcase

end

//**********************************************************************************************************************
//***********************************************Tx side logic*********************************************************
//**********************************************************************************************************************
always_comb begin
	//default values
    type_os_one_lane = 'd0;
	os_enable = 1'b1;
	idle_16 = 'd0;
	repetion = infinity ;  
	type_OS = TS1;
	lane_pad = {(LANES_NUM){1'b1}} ;
	link_pad = {(LANES_NUM){1'b1}} ;

	case(current_state) 
	polling_active: begin 
		if(!ack) begin
		repetion = rep_32 ;  // was rep_1024
		type_OS = TS1;
		//send pad link and lane numbers
		lane_pad = {(LANES_NUM){1'b1}} ;
		link_pad = {(LANES_NUM){1'b1}} ;
		end
		else begin
		repetion = infinity ;  
		type_OS = TS1;
		//send pad link and lane numbers
		lane_pad = {(LANES_NUM){1'b1}} ;
		link_pad = {(LANES_NUM){1'b1}} ;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	polling_config: begin 
		if(!ack && (start_TX_count != 0 || one_TS_rec )) begin  
		repetion = rep_16;  
		type_OS = TS2;
		//send pad link and lane numbers
		lane_pad = {(LANES_NUM){1'b1}} ;
		link_pad = {(LANES_NUM){1'b1}} ;
		
		end
		else begin
		repetion = infinity ;  
		type_OS = TS2;
		//send pad link and lane numbers
		lane_pad = {(LANES_NUM){1'b1}} ;
		link_pad = {(LANES_NUM){1'b1}} ;
		
		end                
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_linkwidth_start : begin
		repetion = infinity;
		type_OS = TS1;
		//send pad link and lane numbers
		lane_pad = {(LANES_NUM){1'b1}} ;
		link_pad = {(LANES_NUM){1'b1}} ;
	end 

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////						   
	config_linkwidth_accept: begin 
		repetion = infinity ;  
		type_OS = TS1;
		//send pad lane number
		lane_pad = {(LANES_NUM){1'b1}};
		//send non_pad link number (which is rcv_link_num)
		link_pad = (~non_pad_link_lanes) ;
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_lanenum_wait,config_lanenum_accept: begin 
		repetion = infinity ;  
		type_OS = TS1;
		lane_pad = (~(non_pad_link_lanes));
		link_pad = (~(non_pad_link_lanes)) ;
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_rcvrlock: begin 
		repetion = infinity ;  
		type_OS = TS1;
		//send device lane numbers
		lane_pad = (~(non_pad_link_lanes));
		//send non_pad link number (which is rcv_link_num)
		link_pad = (~(non_pad_link_lanes)) ;
	end		

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	pre_recovery :begin
		if(gen == LOW_GEN)begin
			repetion = infinity ;  
			type_OS = TS1;
			//send device lane numbers
			lane_pad = (~(non_pad_link_lanes));
			//send non_pad link number (which is rcv_link_num)
			link_pad = (~(non_pad_link_lanes)) ;
		end
		else begin
			repetion = rep_16;
			type_OS = EIEOS;
			//send device lane numbers
			lane_pad = (~(non_pad_link_lanes));
			//send non_pad link number (which is rcv_link_num)
			link_pad = (~(non_pad_link_lanes)) ;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_complete:begin
		type_OS = TS2;
		if(config_lanes == LANES_NUM)begin  
			type_os_one_lane = 'd0;
			lane_pad = 'd0;   //use lane numbers on all 32 lanes
			link_pad = 'd0;   // use link umber on all 32 lanes
		end
		else begin
			type_os_one_lane = 'd1; // which means TS2 on lane0 with non pad link and lane numbers and TS1 with pad on the others
		end					
		if(!ack && (start_TX_count != 0 || one_TS_rec )) begin  
			repetion = rep_16;  
		end
		else begin
			repetion = infinity;  
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_idle: begin
		repetion = infinity;  
		type_OS = SDS;
		lane_pad = (~(non_pad_link_lanes));
		link_pad = (~(non_pad_link_lanes)) ;
		if(os_creator_done)begin
			os_enable = 'd0;
		end
		else begin
			os_enable = 1'b1;  
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	config_idle_2: begin
		os_enable = 1'b0;  
		if ((start_TX_count != 0 || one_TS_rec) && !ack_idle) begin  //byza zbtyha
			idle_16 = 1'b1; // start sent_idle counter
		end
		else begin
			idle_16 = 1'b0;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	L0: begin
		os_enable = 1'b0;
	end	

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_rcvrconfig :begin
		type_OS =  TS2;
		lane_pad = 'd0;   
		link_pad = 'd0;  		
		if(!ack && (start_TX_count != 0 || one_TS_rec ) && !UpConfig_DataR[(SYMBOL_WIDTH-1)] &&(type_OS_dec[0] == TS2)) begin // in order to transition to idle   
			repetion = rep_16;  
		end
		else if(!ack && (start_TX_count != 0 || one_TS_rec ) && UpConfig_DataR[(SYMBOL_WIDTH-1)] && (type_OS_dec[0] == TS2)) begin // in order to transition to speed 
			repetion = rep_32;  
		end
		else begin
			repetion = infinity;  
		end
	end	
		
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
	recovery_idle_skp : begin
		repetion = infinity;  
		type_OS = CTL_SKP ;
		os_enable = 'd1;  
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_idle_sds : begin
		repetion = infinity;  
		type_OS = SDS;
		if(os_creator_done)begin
			os_enable = 'd0;
		end
		else begin
			os_enable = 'd1;  
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_idle_idl : begin
		os_enable = 'd0;
		if (((start_TX_count != 0 && (Block_Type==BLOCK_TYPE_DATA)) || one_TS_rec) && !ack_idle) begin  
		idle_16 = 1'b1;
		end
		else begin
		idle_16 = 1'b0;
		end
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_speed_EIOS:begin
		repetion = infinity ;  
		type_OS = EIOS;
		lane_pad = (~(non_pad_link_lanes));
		link_pad = (~(non_pad_link_lanes)) ;
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	recovery_speed_EIEOS:begin
		repetion = rep_16;
		type_OS = EIEOS;
		lane_pad = (~(non_pad_link_lanes));
		link_pad = (~(non_pad_link_lanes)) ;
	end

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	default:begin
		type_os_one_lane = 'd0;
		os_enable = 1'b1;
		idle_16 = 'd0;
		repetion = infinity ;  
		type_OS = TS1;
		lane_pad = {(LANES_NUM){1'b1}} ;
		link_pad = {(LANES_NUM){1'b1}} ;
	end
	endcase
end


endmodule
