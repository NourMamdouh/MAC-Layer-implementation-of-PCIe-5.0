module LTSSM_TOP #(
    state_width		    = 'd5,
    DATA_WIDTH          = 'd256,
    MAX_LANES           = 'd32,
    CONFIG_WIDTH        = 'd3,
    SYMBOL_NUM_WIDTH    = 'd4,
    SYMBOL_WIDTH	    = 'd8
)
(
    input  logic                                clk,rst,
    input  logic      [0:DATA_WIDTH-1]          rx_OS_symbol   ,
    input  logic      [0:SYMBOL_NUM_WIDTH-1]    rx_symbol_count [0:MAX_LANES-1],
    input  logic      [0:MAX_LANES-1]           valid_gen3,
    input  logic      [0:MAX_LANES-1]           valid_lower_gen,
    input  logic                                gen,
    input  logic                                Block_Type,
    input  logic                                phy_rx_error,
    output logic                                PF_EN,
    output logic                                BA_EN,
    //Interface with Data Link Layer.
    output logic                                O_Link_Up,
    output logic                                O_Retrain_succ,
    output logic                                [0:1] O_Actual_pwr,
    input  logic                                [0:1] I_Pwr_States,
    input  logic                                Retrain,
    //Interface with PIPE.
    output logic        [0:MAX_LANES-1]         O_St_Detect,
    output logic        [1:0]                   powerDown_PIPE [0:31],
    output logic        [2:0]                   O_rate,
    output logic        [0:MAX_LANES-1]         type_IDL_TS,
    input  logic                                EIEOS_Flag,
    output logic                                Soft_RST_blocks,
    output logic                                PIPE_CNT_rst,
    input  logic        [0:MAX_LANES-1]         I_Rcv_Deteted,
    input  logic        [0:MAX_LANES-1]         I_RX_EIdle,
    output logic        [0:MAX_LANES-1]         TxElecIdle_PIPE ,
    output logic                                o_PIPE_rst,
    input  logic                                I_PhyStatus,
    output logic                                frame_skp_enable,
    output logic                                os_enable,
    input  logic                                ack_idle,
    output logic                                idle_16,
    input  logic                                back_pressure,
    input  logic                                enable_LTSSM, // sync_Sel + back_prssure
    output logic                                o_EN_blocks ,
    output logic        [0:DATA_WIDTH-1]        o_OS,
    output logic                                o_config_lanes,
    output logic                                IDL_rst,
    output logic 	                            Physical_recovery,
    output logic                                rst_BA,
    output logic        [0:MAX_LANES-1]         o_K   
);
    
logic [0:SYMBOL_WIDTH-1]   FTS            [MAX_LANES-1:0];
logic [0:SYMBOL_WIDTH-1]   UpConfig_DataR [MAX_LANES-1:0];
//////////////////Nour/////////////

logic  speed_change;


// Internal LTSSM 
//interface with decoder
logic   [0:MAX_LANES-1]           pad_link_flag;
logic   [0:SYMBOL_NUM_WIDTH-1]    cons_count [0:MAX_LANES-1];
logic                             disable_reg;
logic   [0:MAX_LANES-1]           loopback;
logic   [0:SYMBOL_WIDTH-1]        link_num [0:MAX_LANES-1];
logic   [0:MAX_LANES-1]           done_cnt;
logic   [0:MAX_LANES-1]           type_OS_dec ; // 32 bit per lane
logic   [0:MAX_LANES-1]           lane_pad;
logic   [0:MAX_LANES-1]           link_pad;
logic   [0:MAX_LANES-1]           controller_stop;
logic   		                  controller_rst; // input to OSs decoder to rst flags
logic   [0:SYMBOL_WIDTH-1]        rcv_link_num;
logic   [0:state_width-1]         current_state;
//interface with OS creator
logic   [0:1]                     repetion;
logic                             ack;
logic                             os_creator_done;
logic                             reset_ack;
logic   [0:CONFIG_WIDTH-1]        type_OS;
//output logic config_reg,
logic 		                      type_os_one_lane;  
//interface with Timer
logic                             time_out1;
logic                             time_out2; 
logic   [0:CONFIG_WIDTH-1]        time_value1; //options
logic                             time_value2;
logic                             start;
logic                             LTSSM_Count_rst;
logic                             skp_done;
logic                             skp_rst;
logic                             skp_enable;
logic                             start_speed_neg;
logic                             timeout3;
logic   [0:MAX_LANES-1]           recovr_recvrconfg;
logic   [0:MAX_LANES-1]           recovr_speedequ_config;
logic                             PIPE_CNT_rst_LTSSM;
logic   [0:MAX_LANES-1]           PIPE_CNT_rst_DEC;

assign PIPE_CNT_rst = PIPE_CNT_rst_LTSSM | PIPE_CNT_rst_DEC[0];

LTSSM #(
    .SYMBOL_WIDTH(SYMBOL_WIDTH),		
    .state_width(state_width),		
    .LANES_NUM(MAX_LANES)			
)LT_DUT(
    .clk(clk),
    .rst(rst),
    .LTSSM_Count_rst(LTSSM_Count_rst),
    .O_Link_Up(O_Link_Up),
    .O_Retrain_succ(O_Retrain_succ),
    .O_Actual_pwr(O_Actual_pwr),
    .I_Pwr_States(I_Pwr_States),
    .Retrain(Retrain),
    .O_St_Detect(O_St_Detect),
    .powerDown_PIPE(powerDown_PIPE) ,
    .O_rate_PIPE(O_rate),
    .I_Rcv_Deteted(I_Rcv_Deteted),
    .I_RX_EIdle(I_RX_EIdle),
    .TxElecIdle_PIPE(TxElecIdle_PIPE) ,
    .o_PIPE_rst(o_PIPE_rst),
    .I_PhyStatus(I_PhyStatus),
    .pad_link_flag(pad_link_flag),
    .cons_count(cons_count),
    .disable_reg(disable_reg),
    .loopback(loopback[0]),
    .link_num(link_num),
    .done_cnt(done_cnt),
    .type_OS_dec(type_OS_dec) ,
    .UpConfig_DataR(UpConfig_DataR[0]),
    .lane_pad(lane_pad),
    .link_pad(link_pad),
    .controller_stop(controller_stop),
    .controller_rst(controller_rst),   // input to OSs decoder to rst flags
    .rcv_link_num(rcv_link_num),
    .current_state(current_state),
    .IDL_rst(IDL_rst),
    .repetion(repetion), 
    .ack(ack),
    .os_creator_done(os_creator_done),
    .reset_ack(reset_ack),
    .type_OS(type_OS),
    .type_os_one_lane(type_os_one_lane),   
    .time_out1(time_out1),
    .time_out2(time_out2), 
    .timeout3(timeout3),
    .time_value1(time_value1),//options
    .time_value2(time_value2),
    .start(start),
    .start_speed_neg(start_speed_neg),
    .gen(gen),
    .o_config_lanes(o_config_lanes),
    .os_enable(os_enable),
    .ack_idle(ack_idle),
    .directed_speed_change(speed_change),
    .o_EN_blocks(o_EN_blocks),
    .skp_rst(skp_rst),
    .Block_Type(Block_Type),
    .PF_EN(PF_EN),
    .BA_EN(BA_EN),
    .recovr_speedequ_config(recovr_speedequ_config),
    .recovr_recvrconfg(recovr_recvrconfg),
    .type_IDL_TS(type_IDL_TS[0]),
    .EIEOS_Flag(EIEOS_Flag),
    .Soft_RST_blocks(Soft_RST_blocks),
    .PIPE_CNT_rst(PIPE_CNT_rst_LTSSM),
    .idle_16(idle_16),
    .Physical_recovery(Physical_recovery),
    .phy_rx_error(phy_rx_error),
    .rst_BA(rst_BA)
);

OS_CREATOR #(
    .DATA_WIDTH(DATA_WIDTH),       
    .MAX_LANES (MAX_LANES),       
    .LINK_NUM_WIDTH(SYMBOL_WIDTH),   
    .CONFIG_WIDTH(CONFIG_WIDTH),     
    .SYMBOL_NUM_WIDTH(SYMBOL_NUM_WIDTH) 
)OC_DUT (
    .clk(clk), 
    .rst(rst), 
    .LTSSM_Count_rst(LTSSM_Count_rst),
    .type_OS(type_OS), 
    .repetion(repetion), 
    .link_num(rcv_link_num), 
    .gen(gen), 
    .lane_pad(lane_pad), 
    .link_pad(link_pad), 
    .type_os_one_lane(type_os_one_lane), 
    .enable_LTSSM(enable_LTSSM), 
    .speed_change(speed_change), 
    .ack_reset(reset_ack), 
    .o_OS(o_OS), 
    .o_K(o_K), 
    .ack(ack), 
    .skp_done(skp_done),
    .skp_enable(skp_enable),
    .frame_skp_enable(frame_skp_enable),
    .os_creator_done(os_creator_done)
    );

generate
genvar i;
for(i = 0 ; i < 32 ; i = i+ 1)begin: dec
    decoder #(
        .SYMBOL_WIDTH(SYMBOL_WIDTH),				
        .SYMBOL_NUM_WIDTH(SYMBOL_NUM_WIDTH),			
        .state_width(state_width),                 
        .lane_num(i)                    
    )D_DUT (
        .clk(clk), 
        .rst(rst), 
        .OS_symbol(rx_OS_symbol[i*8 : ((i+1)*8)-1]), 
        .symbol_count(rx_symbol_count[i]), 
        .valid_gen3(valid_gen3[i]), 
        .valid_lower_gen(valid_lower_gen[i]), 
        .current_state(current_state), 
        .gen(gen), 
        .rcv_link_num(rcv_link_num), 
        .controller_rst(controller_rst), 
        .controller_stop(controller_stop[i]), 
        .cons_count(cons_count[i]), 
        .link_num(link_num[i]), 
        .type_OS(type_OS_dec[i]), 
        .pad_link_flag(pad_link_flag[i]), 
        .FTS(FTS[i]), 
        .done_cnt(done_cnt[i]),
        .directed_speed_change(speed_change),
        .recovr_speedequ_config(recovr_speedequ_config[i]),
        .recovr_recvrconfg(recovr_recvrconfg[i]),
        .type_IDL_TS(type_IDL_TS[i]),
        .PIPE_CNT_rst(PIPE_CNT_rst_DEC[i]),
        .Block_Type(Block_Type),
        .UpConfig_DataR(UpConfig_DataR[i]),
        .loopback (loopback[i])
    );
end
endgenerate
    
    Timer T_DUT (
    .clk(clk), 
    .rst(rst), 
    .start(start), 
    .timeout_value1(time_value1), 
    .timeout_value2(time_value2), 
    .timeout3(timeout3),
    .start_speed_neg(start_speed_neg),
    .timeout1(time_out1), 
    .timeout2(time_out2)
    );

    SKP_Counter sc(
    .clk(clk), 
    .rst(rst),
    .gen(gen),
    .back_pressure(back_pressure),
    .skp_done(skp_done),
    .skp_rst(skp_rst),
    .skp_enable(skp_enable)
    );
endmodule