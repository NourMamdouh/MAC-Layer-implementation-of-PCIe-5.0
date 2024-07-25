/* -----------------------------------------------------------------------------
Describtion : Decoder block is used to receive OS’s Symbols from RX path and decode, analyze, check these symbols if they are matched to required OS’s symbols 
in each state in LTSSM and also count the required number of OS’s symbols in each state in LTSSM and based on that LTSSM can take the decision to move 
to other states.
-----------------------------------------------------------------------------*/

module decoder #(
    SYMBOL_WIDTH				= 'd8,           		  	// in bits
    SYMBOL_NUM_WIDTH			= 'd4,
    state_width                 = 'd5, 								
    lane_num                    = 0
)(
    //RX Path
    input                                           clk,rst,
    input               [0:SYMBOL_WIDTH-1]          OS_symbol, // Recieved OS symbol in each lane
    input               [0:SYMBOL_NUM_WIDTH-1]      symbol_count, // RX count
    input                                           valid_gen3,
    input                                           valid_lower_gen,
    input                                           gen,
    input  logic                                    Block_Type,
    // LTSSM                
    input               [0:state_width-1]           current_state,
    input               [0:SYMBOL_WIDTH-1]          rcv_link_num, 
    input                                           controller_rst,
    input                                           controller_stop,
    input  logic                                    directed_speed_change,
    output logic        [0:SYMBOL_NUM_WIDTH-1]      cons_count,
    output logic        [0:SYMBOL_WIDTH-1]          link_num,
    output logic                                    type_OS ,
    output logic                                    pad_link_flag, // to indicate PAD link and lane numbers
    output logic                                    done_cnt,
    output logic                                    recovr_speedequ_config, //  to indicate directed speed change == speed change bit
    output logic                                    recovr_recvrconfg, // to indicate speed change bit = 1
    output logic                                    type_IDL_TS, 
    output logic                                    PIPE_CNT_rst,
    output logic                                    loopback,
    output logic        [0:SYMBOL_WIDTH-1]          FTS,
    output logic        [0:SYMBOL_WIDTH-1]          UpConfig_DataR
);      

logic                           type_OS_comb , type_OS_enable;
logic                           cons_rst , cons_set , enable_link_num;
logic                           enable_cons,enable_comp_loop,enable_OS_match,enable_TS1_match;
logic   [0:SYMBOL_WIDTH-1]      link_num_comb  ;
logic                           done_Cnt_comb , done_cnt_enable;
logic                           recovr_speedequ_config_comb,recovr_speedequ_config_enable;
logic                           recovr_recvrconfg_comb,recovr_recvrconfg_enable;
logic                           skp_rcv , skp_rcv_comb , skp_rcv_enable;
logic                           FTS_EN;
logic                           UpConfig_DataR_EN;
logic   [0:SYMBOL_WIDTH-1]      Symbol_6;
logic                           Symbol_6_EN;
logic                           OS_match, TS1_match, complience; 
logic                           OS_match_comb, TS1_match_comb, complience_comb, loopback_comb; 
logic                           pad_link_flag_comb ;
logic                           enable_pad_link_flag ; 

localparam                      Up_Configure_bit = 6;         //symbol 4
localparam                      LOW_SKP_SYMBOL = 8'h1C;
localparam                      Data_Rate_ID_End_Bit = 5;	 //symbol 4
localparam                      Data_Rate_ID_Start_Bit = 0;	 //symbol 4
localparam                      HIGH_GEN = 1;
localparam                      LOW_GEN  = 0;
localparam                      BLOCK_TYPE_DATA = 1'b0;
localparam                      BLOCK_TYPE_OS 	= 1'b1;
localparam                      TS1 = 0 , TS2 = 1 ;
localparam                      idle = 'h00;
localparam                      COM = 188 ;
localparam                      TS1_first_syb = 'h1E, TS2_first_syb = 'h2D ;
localparam                      TS1_ID = 'h4A, TS2_ID = 'h45 ;
localparam                      PAD= 'hF7 ;
localparam  	                Reset = 'd0,
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

////////////// Registers initialisation and Assignment ///////////////
always_ff @(posedge clk or negedge rst) begin
    if(!rst) begin
        FTS <= 0 ;
        UpConfig_DataR <= 0 ;
        Symbol_6 <= 0 ;
        link_num <= 0 ;
    end
    else begin
        if (FTS_EN) begin
            FTS <= OS_symbol ;
        end
        if (UpConfig_DataR_EN)begin
            UpConfig_DataR <= OS_symbol ;
        end
        if (Symbol_6_EN)begin
            Symbol_6 <= OS_symbol ;
        end
        if(enable_link_num)begin
            link_num <= link_num_comb;
        end
    end
end
always_ff @(posedge clk or negedge rst) begin
    if(!rst) begin
        OS_match <= 0 ;
        complience <= 0 ;
        loopback <= 0 ;
        TS1_match <= 0 ;
        pad_link_flag <= 0 ;
        type_OS <= 0;
        done_cnt <= 0;
        recovr_speedequ_config <= 0;
        recovr_recvrconfg <=0 ;
        skp_rcv <= 0;
    end
    else if(controller_rst) begin
        OS_match <= 0 ;
        complience <= 0 ;
        loopback <= 0 ;
        TS1_match <= 0 ;
        pad_link_flag <= 0 ;
        type_OS <= 0;
        done_cnt <= 0;
        recovr_speedequ_config <= 0;
        recovr_recvrconfg <=0 ;
    end
    else begin
        if(enable_comp_loop)  begin
            complience <= complience_comb;
            loopback <= loopback_comb ;
        end
        if(enable_OS_match)  begin
            OS_match <= OS_match_comb;
        end
        if(enable_TS1_match)  begin
            TS1_match <= TS1_match_comb ;
        end
        if(enable_pad_link_flag)  begin
            pad_link_flag <= pad_link_flag_comb ;
        end
        if(type_OS_enable)begin
            type_OS <= type_OS_comb;
        end
        if(done_cnt_enable)begin
            done_cnt <= done_Cnt_comb;
        end
        if(recovr_speedequ_config_enable)begin
            recovr_speedequ_config <= recovr_speedequ_config_comb;
        end
        if(recovr_recvrconfg_enable)begin
            recovr_recvrconfg <= recovr_recvrconfg_comb;
        end
        if(skp_rcv_enable)begin
            skp_rcv <= skp_rcv_comb;
        end
    end
end

/* cons_count definition as it continue in counting until reach required os's then it stop through (controller stop = 1) from LTSSM and reset after move to other 
state in LTSSM through (controller rst) and it sets when find 1 required os but not consecutive*/
always_ff @(posedge clk or negedge rst) begin
    if(!rst) begin
        cons_count <= 0 ;
    end
    else if(cons_rst || controller_rst)begin
        cons_count <= 0 ;
    end
    else if (cons_set) begin
        cons_count <= 1 ;
    end
    else if(enable_cons && !controller_stop)  begin
        cons_count <= cons_count + 1'b1 ;
    end
end

// case on Symbols and check on required os's according to current state  
always_comb begin
    // Defaults
    FTS_EN = 0;
    OS_match_comb = 0 ; 
    loopback_comb = 0;
    complience_comb = 0 ;
    cons_rst = 0;
    cons_set =0 ;
    enable_cons = 0;
    enable_comp_loop = 0;
    enable_OS_match = 0 ;
    enable_TS1_match = 0;
    UpConfig_DataR_EN = 0;
    Symbol_6_EN = 0;
    pad_link_flag_comb = 0;
    enable_pad_link_flag =0;
    TS1_match_comb = 0;
    done_Cnt_comb = 0;
    done_cnt_enable = 0; 
    recovr_speedequ_config_comb = 0;
    recovr_speedequ_config_enable = 0;
    recovr_recvrconfg_comb = 0;
    recovr_recvrconfg_enable = 0;
    type_IDL_TS = 1'b0;
    skp_rcv_enable = 1'b0;
    skp_rcv_comb = 1'b0;
    PIPE_CNT_rst = 1'b0;
    type_OS_comb = 0;
    type_OS_enable =0;
    link_num_comb = 0;
    enable_link_num =0;
    // check if we recieve the Last symbol in Config linkwidth start
    if(symbol_count == 'd15 && current_state == config_linkwidth_start && cons_count == 'd2)begin
        done_Cnt_comb = 1;
        done_cnt_enable = 1; 
    end
    else begin
        done_Cnt_comb = 0;
        done_cnt_enable = 0;        
    end

    // skp symbol 
    case(symbol_count)
        'd3:begin
            if(gen == LOW_GEN && OS_symbol == LOW_SKP_SYMBOL)begin
                PIPE_CNT_rst = 1'b1;
            end
        end
    endcase

    if(!controller_stop && (valid_lower_gen && (gen == LOW_GEN) ) || ((valid_gen3 && (gen == HIGH_GEN)))) begin /////////check symols validation ///////////
        case (symbol_count)  // each lane has its own symbol count
            'd0 : begin
                    case(current_state) 
                        polling_active,polling_config:begin
                            // check of recieving TS1s or TS2s in LOW GEN
                            if(OS_symbol==COM) begin 
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1 ;
                            end
                            else begin
                                cons_rst = 1'b1 ;
                                OS_match_comb = 1'b0 ;
                            end
                        end

                        config_linkwidth_accept,config_linkwidth_start:begin
                            // check of recieving TS1
                            if(((gen==LOW_GEN) && (OS_symbol==COM)) || ((gen==HIGH_GEN) && (OS_symbol==TS1_first_syb)))begin
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1 ;
                            end
                            else begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1 ;
                                cons_rst = 1'b1 ;
                            end
                        end

                        config_complete:begin 
                            // check of recieving TS2              
                            if(((gen==LOW_GEN) && (OS_symbol==COM)) || ((gen==HIGH_GEN) && (OS_symbol==TS2_first_syb)) )begin
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1 ;
                            end
                            else begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1 ;
                                cons_rst = 1'b1 ;
                            end        
                        end
                        config_lanenum_wait,config_lanenum_accept,recovery_rcvrlock, recovery_rcvrconfig:begin
                            // check of recieving TS1 or TS2
                            if(((gen==LOW_GEN) && (OS_symbol==COM)) || ((gen==HIGH_GEN) && (OS_symbol==TS1_first_syb))  || ((gen==HIGH_GEN) && (OS_symbol==TS2_first_syb)))begin
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1 ;
                            end
                            else begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1 ;
                                cons_rst = 1'b1 ;
                            end
                        end
                        
                        config_idle_2:begin
                            // check recieving IDL
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end
                                
                        recovery_idle_skp,recovery_idle_sds,recovery_idle_idl:begin
                            // check Recieveing TS1 or IDL
                            if(Block_Type==BLOCK_TYPE_OS)begin	
                                if(OS_symbol==TS1_first_syb)begin
                                    OS_match_comb = 1'b1;
                                    enable_OS_match = 1'b1 ;
                                end
                                else begin
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1 ;
                                    cons_rst = 1'b1 ;
                                end
                            end
                            else begin
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1 ;
                                if(OS_symbol==idle)begin
                                    if(OS_match)begin
                                        enable_cons = 1'b1 ;
                                    end
                                    else begin
                                        cons_set = 'd1;
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1 ;
                                    end
                                end
                                else begin
                                    cons_rst = 1'b1 ;
                                end
                            end   
                        end
                        L0:begin
                            // check recieving TS1 in LOW GEN 
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                end
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        pre_recovery:begin
                            // check recieving TS1 in LOW GEN 
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                    OS_match_comb = 1'b1;
                                    enable_OS_match = 1'b1;
                                end
                            end
                        end
                endcase
            end
            'd1:begin
                // check matching before propagating in the symbol
                if(OS_match) begin 
                    case(current_state) 
                        polling_active,polling_config:begin
                            // reset matching and cons_count if link_num not equal PAD and reset matching only if equal SKP
                            if(OS_symbol != PAD  &&  OS_symbol != LOW_SKP_SYMBOL ) begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1 ;
                                cons_rst = 1'b1 ;
                            end
                            else if((OS_symbol == LOW_SKP_SYMBOL))begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1;
                            end
                        end
                        config_linkwidth_start:begin
                            // reset cons_count if link_num equal PAD and reset matching only if equal SKP
                            enable_link_num = 1'b1;
                            link_num_comb = OS_symbol;
                            if(OS_symbol == PAD ) begin
                                cons_rst = 1'b1 ;     
                            end
                            else if((OS_symbol == LOW_SKP_SYMBOL))begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1;
                            end       
                        end  
                        config_linkwidth_accept,config_lanenum_wait:begin
                            // reset matching and cons_count if link_num not equal transmitted link number and reset matching only if equal SKP
                            if(OS_symbol != rcv_link_num && OS_symbol != LOW_SKP_SYMBOL) begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1 ;
                                cons_rst = 1'b1 ;
                            end
                            else if((OS_symbol == LOW_SKP_SYMBOL))begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1;
                            end  
                        end
                        config_lanenum_accept:begin
                            // reset matching and cons_count if link_num not equal transmitted link num and enable PAD link flag and reset matching only if equal SKP
                            if(OS_symbol != rcv_link_num && OS_symbol != LOW_SKP_SYMBOL) begin
                                    pad_link_flag_comb = 1'b1 ;
                                    enable_pad_link_flag = 1'b1 ;
                            end
                            else if((OS_symbol == LOW_SKP_SYMBOL))begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1;
                            end  
                            if(pad_link_flag != pad_link_flag_comb)
                                cons_rst = 1'b1 ;
                            else
                                cons_rst = 1'b0 ; 
                        end
                        recovery_rcvrlock, recovery_rcvrconfig:begin
                            // reset matching and cons_count if link_num not equal transmitted link number and enable PAD link flag and reset matching only if equal SKP
                            if(OS_symbol != rcv_link_num && OS_symbol != LOW_SKP_SYMBOL) begin
                                pad_link_flag_comb = 1'b1 ;
                                enable_pad_link_flag = 1'b1 ;
                            end
                            else if((OS_symbol == LOW_SKP_SYMBOL))begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1;
                            end  
                            else begin
                                pad_link_flag_comb = 1'b0 ;
                                enable_pad_link_flag = 1'b1 ;
                            end
                            if(pad_link_flag != pad_link_flag_comb)begin
                                cons_rst = 1'b1;
                            end
                            else begin
                                cons_rst = 1'b0;
                            end
                        end
                        config_complete:begin
                            // reset matching and cons_count if link_num not equal transmitted link num and reset matching only if equal SKP
                            if(OS_symbol != rcv_link_num && OS_symbol != LOW_SKP_SYMBOL)begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1 ;
                                cons_rst = 1'b1 ;
                            end
                            else if((OS_symbol == LOW_SKP_SYMBOL))begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1;
                            end 
                        end
                        config_idle_2 : begin
                            // reset matching and cons_count if os_symbol not equal idle and reset matching only if equal SKP
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else if((OS_symbol == LOW_SKP_SYMBOL))begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1;
                            end 
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        recovery_idle_skp,recovery_idle_sds,recovery_idle_idl:begin 
                            /* reset cons_count if os_symbol not equal idle nor os and only enable counts if recievung 
                            IDLS equal PAD and reset matching only if equal SKP */       
                            if(Block_Type==BLOCK_TYPE_OS)begin	
                                enable_cons = 1'b0 ;
                                cons_rst = 'd0;
                            end
                            else begin
                                if(OS_symbol==idle)begin
                                    enable_cons = 1'b1 ;
                                end
                                else begin
                                    cons_rst = 1'b1 ;
                                end
                            end
                        end
                        L0:begin
                            //  set type_IDL_TS if reciveing TS1 os's and reset matching only if equal SKP
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                    OS_match_comb = 1'b1;
                                    enable_OS_match = 1'b1;
                                end
                                else if((OS_symbol == LOW_SKP_SYMBOL))begin
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                end 
                                else begin
                                    OS_match_comb = 1'b1;
                                    enable_OS_match = 1'b1;
                                end
                            end
                        end
                        pre_recovery:begin
                            // set type_IDL_TS if recieving TS1 OS and reset matching only if equal SKP
                            if(OS_symbol  == COM )begin
                                type_IDL_TS = 1;
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                            else if((OS_symbol == LOW_SKP_SYMBOL))begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1;
                            end
                        end              
                    endcase
                end
            end
            'd2:begin
                if(OS_match) begin
                    case(current_state) 
                        polling_active,polling_config, config_linkwidth_start: begin
                            // reset matching and cons_Count if lane number not equal PAD
                            if(OS_symbol != PAD) begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1 ;
                                cons_rst = 1'b1 ;
                            end
                        end
                        config_linkwidth_accept: begin
                            // reset matching and cons_Count if lane number not equal PAD
                            if(OS_symbol == PAD) begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1 ;
                                cons_rst = 1'b1 ;
                            end
                        end
                        config_lanenum_wait: begin
                            // reset matching and cons_Count if lane number equal PAD and set TS1_match reg to ckeck it in symbol 6
                            if(OS_symbol == lane_num) begin
                                enable_TS1_match = 1'b1 ;
                                TS1_match_comb = 1'b0 ;
                            end
                            else begin
                                enable_TS1_match = 1'b1 ;
                                TS1_match_comb = 1'b1 ;
                            end
                        end
                        config_lanenum_accept: begin
                            // reset matching and cons_Count if lane number not equal PAD and set PAD Link flag reg
                            if(OS_symbol != lane_num) begin
                                pad_link_flag_comb = 1'b1 ;
                                enable_pad_link_flag = 1'b1 ;
                            end
                            if(pad_link_flag != pad_link_flag_comb)
                                cons_rst = 1'b1 ;
                            else
                                cons_rst = 1'b0 ; 
                        end
                        config_complete:begin
                            // reset matching and cons_Count if lane number not equal PAD
                            if(OS_symbol != lane_num)begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1 ;
                                cons_rst = 1'b1 ;
                            end
                        end
                        recovery_rcvrlock, recovery_rcvrconfig : begin
                            // reset matching and cons_Count if lane number not equal PAD and set PAD link flag reg
                            if(OS_symbol != lane_num) begin
                                pad_link_flag_comb = 1'b1 ;
                                enable_pad_link_flag = 1'b1 ;
                            end
                            else begin
                                pad_link_flag_comb = 1'b0 ;
                                enable_pad_link_flag = 1'b1 ;
                            end
                            if(pad_link_flag != pad_link_flag_comb)begin
                                cons_rst = 1'b1;
                            end
                            else begin
                                cons_rst = 1'b0;
                            end
                        end
                        config_idle_2 : begin
                            // reset matching and cons_Count if os_symbol not equal IDL
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        recovery_idle_skp,recovery_idle_sds,recovery_idle_idl:begin
                            // reset matching and cons_Count if os_symbol not equal IDLES or OS'S and only enable count if recieving IDL
                            if(Block_Type==BLOCK_TYPE_OS)begin	
                                if(OS_symbol==PAD)begin
                                    enable_OS_match = 1'b0 ;
                                end
                                else begin
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1 ;
                                    cons_rst = 1'b1 ;
                                end
                            end
                            else begin
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1 ;
                                if(OS_symbol==idle)begin
                                    enable_cons = 1'b1 ;
                                end
                                else begin
                                    cons_rst = 1'b1 ;
                                end
                            end        
                        end
                        L0:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                end
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        pre_recovery:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(OS_symbol  == COM )begin
                                type_IDL_TS = 1;
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                    endcase
                end
            end
            'd3:begin
                if(OS_match)begin
                    case(current_state)
                        config_complete:begin
                            // enable FTS reg to store sequence number in symbol 3
                            FTS_EN = 1;
                        end
                        config_idle_2 : begin
                            // reset cons counter if os_symbol mot equal IDL
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        L0:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                end
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        pre_recovery:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(OS_symbol  == COM )begin
                                type_IDL_TS = 1;
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                    endcase
                end
            end      
            'd4: begin
                if(OS_match)begin
                    case(current_state)
                        config_complete:begin
                            // reset cons count if os_symbol not equal Upconfig_DataR reg value
                            if(OS_symbol!= UpConfig_DataR )begin
                                cons_rst = 1'b1 ;
                                UpConfig_DataR_EN = 'd1;
                            end
                        end
                        recovery_rcvrconfig : begin 
                            // reset cons count if os_symbol not equal Upconfig_DataR reg value
                            UpConfig_DataR_EN = 'd1;
                            if(OS_symbol != UpConfig_DataR)
                                cons_rst = 1'b1;
                        end
                        recovery_rcvrlock : begin
                            // check if dircted speed chnage variable equal to speed change bit to set recovr_speedequ_config reg
                            if(OS_symbol[7] == directed_speed_change)begin
                                if(pad_link_flag)begin
                                    if(OS_symbol[7] == 1'b0)begin
                                        recovr_speedequ_config_comb = 1'b1;
                                        recovr_speedequ_config_enable = 1'b1;
                                    end
                                    if(recovr_speedequ_config_comb != recovr_speedequ_config)begin
                                        cons_rst =1;
                                    end
                                    else begin
                                        cons_rst = 0;
                                    end
                                end
                                else begin
                                    recovr_speedequ_config_enable = 1'b1;
                                    recovr_speedequ_config_comb = 1'b0;
                                    if(recovr_speedequ_config != recovr_speedequ_config_comb)begin
                                        cons_rst =1;
                                    end
                                    else begin
                                        cons_rst = 0;
                                    end
                                end
                            end
                            // check if speed change bit equal 1 to set recovr_recvrconfig reg
                            else if (OS_symbol[7] == 1'b1)begin
                                recovr_recvrconfg_enable = 1'b1;
                                recovr_recvrconfg_comb = 1'b1;
                                if(recovr_recvrconfg != recovr_recvrconfg_comb)begin
                                    cons_rst =1;
                                end
                                else begin
                                    cons_rst = 0;
                                end
                            end
                            else begin
                                cons_rst = 1;
                                OS_match_comb = 0;
                                enable_OS_match = 1;
                            end
                        end
                        config_idle_2 : begin
                            // reset cons counter if OS_symbol not equal IDL
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        L0:begin
                             // set type_IDL_ts if recieving TS1 symbol
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                end
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        pre_recovery:begin
                             // set type_IDL_ts if recieving TS1 symbol
                            if(OS_symbol  == COM )begin
                                type_IDL_TS = 1;
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                    endcase
                end
            end
            'd5: begin
                if(OS_match == 1) begin
                    case(current_state) 
                        polling_active: begin
                            // case on loopbackbit and compliance bit to set cons count or reset it and set loopback and compliance reg 
                            case({OS_symbol[4],OS_symbol[2] })
                                'b00: begin
                                    complience_comb = 1'b1 ;
                                    loopback_comb   = 1'b0 ;
                                    enable_comp_loop = 1'b1 ;
                                    enable_TS1_match = 1'b1 ;
                                    TS1_match_comb = 1'b1 ;
                                    if (complience != 1 && cons_count !=0 && type_OS == TS1)  
                                        cons_rst = 1'b1 ;
                                end
                                'b01: begin
                                    complience_comb = 1'b1 ;
                                    loopback_comb   = 1'b1 ;
                                    enable_comp_loop = 1'b1 ;
                                    enable_TS1_match = 1'b1 ;
                                    TS1_match_comb = 1'b1 ;
                                    if (complience != 1 && loopback != 1 && cons_count !=0 && type_OS == TS1)  
                                        cons_rst = 1'b1 ;
                                end
                                'b11: begin
                                    complience_comb = 1'b0 ;
                                    loopback_comb   = 1'b1 ;
                                    enable_comp_loop = 1'b1 ;
                                    enable_TS1_match = 1'b1 ;
                                    TS1_match_comb = 1'b1 ;
                                    if (loopback != 1 && cons_count !=0 && type_OS == TS1)  
                                    cons_rst = 1'b1 ;
                                end
                                'b10: begin
                                    complience_comb = 1'b0 ;
                                    loopback_comb   = 1'b0 ;
                                    enable_comp_loop = 1'b1 ;
                                    enable_TS1_match = 1'b1 ;
                                    TS1_match_comb = 1'b0 ;
                                    if (cons_count !=0 && type_OS == TS1)
                                        cons_rst = 1'b1 ;
                                end
                            endcase
                        end
                        config_linkwidth_start : begin 
                            // case on loopback bit and compliance bit to set cons count or reset it and set loopback and compliance reg 
                            case(OS_symbol[1:2])
                                2'b00: begin  
                                    {complience_comb, loopback_comb} = OS_symbol[1:2];
                                    enable_comp_loop = 1'b1;
                                    if((loopback_comb != loopback) || (complience_comb != complience))
                                    cons_rst = 1'b1; 
                                end
                                2'b01:begin 
                                    {complience_comb, loopback_comb} = OS_symbol[1:2];
                                    enable_comp_loop = 1'b1; 
                                    if(loopback_comb != loopback)
                                    cons_rst = 1'b1;
                                end
                                2'b10:begin 
                                    {complience_comb, loopback_comb} = OS_symbol[1:2];                                        
                                    enable_comp_loop = 1'b1;
                                    if(complience_comb != complience)
                                    cons_rst = 1'b1;
                                end
                                2'b11:begin
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1 ;
                                    cons_rst = 1'b1;
                                end
                            endcase
                        end      
                        config_idle_2 : begin
                            // reset cons counter if OS_symbol not equal IDL
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end	
                        L0:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                end
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        pre_recovery:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(OS_symbol  == COM )begin
                                type_IDL_TS = 1;
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end	
                    endcase
                end            
            end
            'd6:begin
                if(OS_match == 1) begin
                    case(current_state) 
                        polling_active: begin
                            // check if type of os_symbol is matched to previous os_symbol to enable count or set the count
                            OS_match_comb = 1'b0;
                            enable_OS_match = 1'b1;
                            case (OS_symbol)
                                TS1_ID:  begin
                                    if (TS1_match) begin
                                        enable_cons = 1'b1 ;
                                        type_OS_enable = 1;
                                        type_OS_comb = TS1 ;
                                    end
                                end
                                TS2_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS2 ;                        
                                    if (cons_count !=0 && type_OS == TS1) begin
                                        cons_set = 1'b1 ; //??  
                                    end
                                    else begin	
                                        enable_cons = 1'b1 ;
                                    end 
                                end
                                default :  cons_rst = 1'b1 ;   // any other type of os
                            endcase
                        end
                        polling_config:begin
                            // enable cont if recieving TS2 identifier
                            OS_match_comb = 1'b0;
                            enable_OS_match = 1'b1;
                            if(OS_symbol == TS2_ID) begin
                                enable_cons = 1'b1 ;
                            end
                            else begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        config_linkwidth_start : begin 
                            // enable count if os_symbol is ts1 identifier and compliance or loopback bit equal to 1 and LOW gen
                            if(OS_symbol == TS1_ID)begin
                                if((link_num !=PAD)|| complience || loopback )begin
                                    if(gen == LOW_GEN)begin
                                        enable_cons = 1'b1 ;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                    end
                                    else begin
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end 
                                end 
                            end
                            else begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1;  
                                cons_rst = 1'b1; 
                            end
                        end
                        config_linkwidth_accept:begin
                            // enable cons_count if os_symbol is TS1 identifier and LOW gen 
                            if(OS_symbol == TS1_ID) begin
                                if(gen == LOW_GEN)begin
                                    enable_cons = 1'b1 ;
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1;
                                end
                                else begin
                                    OS_match_comb = 1'b1;
                                    enable_OS_match = 1'b1;
                                end
                            end
                            else begin
                                cons_rst = 1'b1 ;
                            end
                        end 
                        recovery_rcvrlock:begin
                            // check if type of os_symbol is matched to previous os_symbol to enable count or set the count
                            case(OS_symbol)
                                TS1_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS1 ;
                                    if (cons_count !=0 && type_OS == TS2 ) begin
                                        if(gen == LOW_GEN)begin
                                            cons_set = 1'b1 ;
                                            OS_match_comb = 1'b0;
                                            enable_OS_match = 1'b1;
                                        end 
                                    end
                                    else begin	
                                        if(gen == LOW_GEN )begin
                                            enable_cons = 1'b1 ;
                                            OS_match_comb = 1'b0;
                                            enable_OS_match = 1'b1;
                                        end
                                        else begin
                                            OS_match_comb = 1'b1;
                                            enable_OS_match = 1'b1;
                                        end
                                    end
                                end 
                                TS2_ID: begin
                                    type_OS_enable = 1; 
                                    type_OS_comb = TS2 ;
                                    if (cons_count !=0 && type_OS == TS1) begin
                                        if(gen == LOW_GEN)begin
                                        cons_set = 1'b1 ;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                    end  
                                    end
                                    else begin	
                                    if(gen == LOW_GEN)begin
                                        enable_cons = 1'b1 ;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                    end
                                    else begin
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end
                                    end 
                                end
                            endcase
                        end
                        config_lanenum_accept:begin
                            // check if type of os_symbol is matched to previous os_symbol to enable count or set the count
                            case(OS_symbol)
                                TS1_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS1 ;
                                    if (cons_count !=0 && type_OS == TS2 ) begin
                                        if(gen == LOW_GEN)begin
                                            cons_set = 1'b1 ;
                                            OS_match_comb = 1'b0;
                                            enable_OS_match = 1'b1;
                                        end 
                                    end
                                    else begin	
                                        if(gen == LOW_GEN )begin
                                            enable_cons = 1'b1 ;
                                            OS_match_comb = 1'b0;
                                            enable_OS_match = 1'b1;
                                        end
                                        else begin
                                            OS_match_comb = 1'b1;
                                            enable_OS_match = 1'b1;
                                        end
                                    end 
                                end 
                                TS2_ID: begin
                                    type_OS_enable = 1; 
                                    type_OS_comb = TS2 ;
                                    if (cons_count !=0 && type_OS == TS1) begin
                                        if(gen == LOW_GEN)begin
                                        cons_set = 1'b1 ;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                    end  
                                    end
                                    else begin	
                                    if(gen == LOW_GEN)begin
                                        enable_cons = 1'b1 ;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                    end
                                    else begin
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end
                                    end 
                                end
                            endcase
                        end
                        config_lanenum_wait:begin
                            /* check if type of os_symbol is matched to previous os_symbol to enable count or set the count 
                            and link num is not matched according to TS1 match value*/
                            case(OS_symbol)
                                TS1_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS1 ;
                                    if (cons_count !=0 && type_OS == TS2 && TS1_match) begin
                                        if(gen == LOW_GEN)begin
                                            cons_set = 1'b1 ;
                                            OS_match_comb = 1'b0;
                                            enable_OS_match = 1'b1;
                                        end 
                                    end
                                    else begin	
                                        if(TS1_match == 0)begin
                                            cons_rst = 1;
                                            OS_match_comb = 1'b0;
                                            enable_OS_match = 1'b1;
                                        end
                                        else begin
                                            if(gen == LOW_GEN )begin
                                                enable_cons = 1'b1 ;
                                                OS_match_comb = 1'b0;
                                                enable_OS_match = 1'b1;
                                            end
                                            else begin
                                                OS_match_comb = 1'b1;
                                                enable_OS_match = 1'b1;
                                            end
                                        end
                                    end 
                                end
                                TS2_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS2 ;
                                    if (cons_count !=0 && type_OS == TS1) begin
                                        if(gen == LOW_GEN)begin
                                        cons_set = 1'b1 ;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                    end  
                                    end
                                    else begin	
                                    if(gen == LOW_GEN)begin
                                        enable_cons = 1'b1 ;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                    end
                                    else begin
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end
                                    end 
                                end
                            endcase
                        end
                        config_complete:begin
                            // enable count if os_Symbol is TS2 Identifier and LOW GEN
                            if(gen==LOW_GEN)begin
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1 ;
                                if(OS_symbol == TS2_ID)begin
                                    enable_cons = 'd1;
                                end
                                else begin
                                    cons_rst = 'd1;
                                end
                            end
                            else begin
                                if(OS_symbol != Symbol_6 )begin
                                    cons_rst = 1'b1 ;
                                    Symbol_6_EN = 'd1;
                                end
                            end
                        end	
                        config_idle_2 : begin
                            // reset cons counter if OS_symbol not equal IDL
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        recovery_rcvrconfig:begin
                            // check if type of os_symbol is matched to previous os_symbol to enable count or set the count and PAD Link flag is set
                            case(OS_symbol)
                                TS1_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS1 ;
                                    if (cons_count !=0 && type_OS == TS2 && pad_link_flag ) begin
                                        if(gen == LOW_GEN)begin
                                            cons_set = 1'b1 ;
                                            OS_match_comb = 1'b0;
                                            enable_OS_match = 1'b1;
                                        end 
                                    end
                                    else if(gen == LOW_GEN && pad_link_flag)begin
                                        enable_cons = 1'b1 ;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                    end   
                                    else if (HIGH_GEN && pad_link_flag) begin
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end
                                    else begin
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                        cons_rst = 1'b1;
                                    end 
                                end
                                TS2_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS2 ;
                                    if (cons_count !=0 && type_OS == TS1 && !pad_link_flag ) begin
                                        if(gen == LOW_GEN)begin
                                            cons_set = 1'b1 ;
                                            OS_match_comb = 1'b0;
                                            enable_OS_match = 1'b1;
                                        end 
                                    end
                                    else if(gen == LOW_GEN && !pad_link_flag)begin
                                        enable_cons = 1'b1 ;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                    end   
                                    else if (HIGH_GEN && !pad_link_flag) begin
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end
                                    else begin
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1;
                                        cons_rst = 1'b1;
                                        
                                    end 
                                end
                            endcase
                        end	 
                        L0:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                end
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        pre_recovery:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(OS_symbol  == COM )begin
                                type_IDL_TS = 1;
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        recovery_idle_skp,recovery_idle_sds,recovery_idle_idl:	begin
                            if(Block_Type==BLOCK_TYPE_OS)begin	
                                if(OS_symbol != Symbol_6 )begin
                                    cons_rst = 1'b1 ;
                                    Symbol_6_EN = 'd1;
                                end
                            end
                            else begin
                                if(OS_symbol==idle)begin
                                    enable_cons = 1'b1 ;
                                end
                                else begin
                                    cons_rst = 1'b1 ;
                                end
                            end
                        end  
                    endcase
                end
            end
            'd7 : begin
                if(OS_match == 1) begin
                    case(current_state) 
                        config_linkwidth_start : begin
                            // reset match if os_symbol isn't TS1 identifier
                            if(gen == HIGH_GEN) begin 
                                if(OS_symbol == TS1_ID)begin
                                    OS_match_comb = 1'b1;
                                    enable_OS_match = 1'b1;
                                end 
                                else begin
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1; 
                                    cons_rst = 1'b1;  
                                end
                            end
                        end
                        config_linkwidth_accept :begin
                            // reset match if os_symbol isn't TS1 identifier
                            if(OS_symbol == TS1_ID) begin
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                            else begin
                                cons_rst = 1'b1 ;
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1;
                            end
                        end
                        config_lanenum_wait,config_lanenum_accept,recovery_rcvrlock:begin
                            // check if type of os_symbol is matched to previous os_symbol to enable count
                            case(OS_symbol)
                                TS1_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS1 ;
                                    if (cons_count !=0 && type_OS == TS2) begin
                                        cons_rst = 1;                  
                                    end
                                    else begin	
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end 
                                end
                                TS2_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS2 ;
                                    if (cons_count !=0 && type_OS == TS1) begin
                                        cons_rst = 1'b1 ; 
                                    end
                                    else begin	
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end 
                                end
                                default: begin
                                    cons_rst = 1'b1 ;
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1;
                                end
                            endcase
                        end
                        config_complete:begin
                            // reset match if os_symbol is not TS2 identifier
                            if(OS_symbol != TS2_ID)begin
                                cons_rst = 1'b1 ;
                                OS_match_comb = 1'b0 ;
                                cons_rst = 'd1;
                            end
                        end
                        config_idle_2 : begin
                            // reset cons counter if OS_symbol not equal IDL
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        L0:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                end
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        pre_recovery:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(OS_symbol  == COM )begin
                                type_IDL_TS = 1;
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        recovery_rcvrconfig: begin 
                            // check if type of os_symbol is matched to previous os_symbol to enable count
                            case(OS_symbol)
                                TS1_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS1 ;
                                    if (cons_count !=0 && type_OS == TS2 && pad_link_flag) begin
                                        cons_rst = 1;                           
                                    end
                                    else if (pad_link_flag)begin	
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end 
                                    else begin
                                        cons_rst = 1'b1;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1; 
                                    end
                                end
                                TS2_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS2 ;
                                    if (cons_count !=0 && type_OS == TS1 && ! pad_link_flag) begin
                                        cons_rst = 1'b1 ; 
                                    end
                                    else if (!pad_link_flag) begin	
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end 
                                    else begin
                                        cons_rst = 1'b1;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1; 
                                    end
                                end
                            endcase
                        end
                        recovery_idle_skp,recovery_idle_sds,recovery_idle_idl:	begin
                            // reset cons count if os_symbol isn't TS1 identifier and if block type is os or os_symbol is IDL        
                            if(Block_Type==BLOCK_TYPE_OS)begin	
                                if(OS_symbol != TS1_ID)begin
                                    cons_rst = 1'b1 ;
                                    OS_match_comb = 1'b0 ;
                                    enable_OS_match = 1'b1;
                                end
                            end
                            else begin
                                if(OS_symbol==idle)begin
                                    enable_cons = 1'b1 ;
                                end
                                else begin
                                    cons_rst = 1'b1 ;
                                end
                            end
                        end 
                    endcase
                end     
            end
            'd8 : begin
                if(OS_match == 1) begin
                    case(current_state) 
                        config_linkwidth_start:begin
                            // reset match if os_symbol isn't TS1 identifier
                            if(gen == HIGH_GEN) begin 
                                if(OS_symbol == TS1_ID)begin
                                    OS_match_comb = 1'b1;
                                    enable_OS_match = 1'b1;
                                end 
                                else begin
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1; 
                                    cons_rst = 1'b1;  
                                end
                            end
                        end
                        config_linkwidth_accept:begin
                            // reset match if os_symbol isn't TS1 identifier
                            if(OS_symbol == TS1_ID) begin
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                            else begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        config_lanenum_wait,config_lanenum_accept,recovery_rcvrlock:begin
                            // check if type of os_symbol is matched to previous os_symbol to enable count
                            case(OS_symbol)
                                TS1_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS1 ;
                                    if (cons_count !=0 && type_OS == TS2) begin
                                        cons_rst = 1'b1 ;  
                                    end
                                    else begin	
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end 
                                end
                                TS2_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS2 ;
                                    if (cons_count !=0 && type_OS == TS1) begin
                                        cons_rst = 1'b1 ; 
                                    end
                                    else begin	
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end 
                                end
                                default: begin
                                    cons_rst = 1'b1 ;
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1;
                                end
                            endcase
                        end
                        config_complete:begin
                            // reset match if os_symbol isn't TS2 identifier
                            if(OS_symbol != TS2_ID)begin
                                cons_rst = 1'b1 ;
                                OS_match_comb = 1'b0 ;
                                cons_rst = 'd1;
                            end
                        end		
                        config_idle_2 : begin
                            // reset cons counter if OS_symbol not equal IDL
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        L0:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                end
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        pre_recovery:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(OS_symbol  == COM )begin
                                type_IDL_TS = 1;
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        recovery_rcvrconfig: begin 
                            // check if type of os_symbol is matched to previous os_symbol to enable count and PAD link flag is set
                            case(OS_symbol)
                                TS1_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS1 ;
                                    if (cons_count !=0 && type_OS == TS2 && pad_link_flag) begin
                                        cons_rst = 1;                           
                                    end
                                    else if (pad_link_flag)begin	
                                            OS_match_comb = 1'b1;
                                            enable_OS_match = 1'b1;
                                    end 
                                    else begin
                                        cons_rst = 1'b1;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1; 
                                    end
                                end
                                TS2_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS2 ;
                                    if (cons_count !=0 && type_OS == TS1 && ! pad_link_flag) begin
                                        cons_rst = 1'b1 ; 
                                    end
                                    else if (!pad_link_flag) begin	
                                        OS_match_comb = 1'b1;
                                        enable_OS_match = 1'b1;
                                    end 
                                    else begin
                                        cons_rst = 1'b1;
                                        OS_match_comb = 1'b0;
                                        enable_OS_match = 1'b1; 
                                    end
                                end
                            endcase
                        end                       
                        recovery_idle_skp,recovery_idle_sds,recovery_idle_idl:	begin  
                            // reset match if os_symbol isn't TS1 identifier and block type is os nor IDL symbol                                     
                            if(Block_Type==BLOCK_TYPE_OS)begin	
                                if(OS_symbol != TS1_ID)begin
                                    cons_rst = 1'b1 ;
                                    OS_match_comb = 1'b0 ;
                                    enable_OS_match = 1'b1;
                                end
                                
                            end
                            else begin
                                if(OS_symbol==idle)begin
                                    enable_cons = 1'b1 ;
                                end
                                else begin
                                    cons_rst = 1'b1 ;
                                end
                            end                                       
                        end				 
                    endcase
                end 
            end
            'd9 : begin
                if(OS_match == 1) begin
                    case(current_state) 
                        config_linkwidth_start : begin
                            // enable cons_count if os_symbol is TS1 identifier
                            if(gen == HIGH_GEN) begin 
                                if(OS_symbol == TS1_ID)begin
                                    enable_cons = 1'b1;
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1;
                                end 
                                else begin
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1; 
                                    cons_rst = 1'b1;  
                                end
                            end
                        end
                        config_linkwidth_accept:begin
                            // enable cons_count if os_symbol is TS1 identifier
                            if(OS_symbol == TS1_ID) begin
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b0;
                                enable_cons = 1'b1 ;
                            end
                            else begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        config_lanenum_wait,config_lanenum_accept,recovery_rcvrlock:begin
                            // check if type of os_symbol is matched to previous os_symbol to enable count 
                            OS_match_comb = 1'b0;
                            enable_OS_match = 1'b1;
                            case(OS_symbol)
                                TS1_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS1 ;
                                    if (cons_count !=0 && type_OS == TS2) begin
                                        cons_set = 1'b1 ;  
                                    end
                                    else begin	
                                        enable_cons = 1'b1 ;
                                    end 
                                end
                                TS2_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS2 ;
                                    if (cons_count !=0 && type_OS == TS1) begin
                                        cons_set = 1'b1 ; 
                                    end
                                    else begin	
                                        enable_cons = 1'b1 ;
                                    end 
                                end
                                default: begin
                                    cons_rst = 1'b1 ;
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1;
                                end
                            endcase
                        end
                        config_complete:begin
                            // enable cons_count if os_symbol is TS2 identifier
                            OS_match_comb = 1'b0;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol == TS2_ID)begin
                                enable_cons = 'd1;
                            end
                            else begin
                                cons_rst = 'd1;
                            end
                        end		
                        config_idle_2 : begin
                            // reset cons counter if OS_symbol not equal IDL
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end	
                        L0:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                end
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        pre_recovery:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(OS_symbol  == COM )begin
                                type_IDL_TS = 1;
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        recovery_rcvrconfig:begin
                            // check if type of os_symbol is matched to previous os_symbol to enable count and PAD link flag is set
                            OS_match_comb = 1'b0;
                            enable_OS_match = 1'b1;
                            case(OS_symbol)
                                TS1_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS1 ;
                                    if (cons_count !=0 && type_OS == TS2 && pad_link_flag) begin
                                        cons_set = 1'b1 ;  
                                    end
                                    else if (pad_link_flag)begin	
                                        enable_cons = 1'b1 ;
                                    end 
                                    else begin 
                                        cons_rst = 1'b1;
                                    end
                                end
                                TS2_ID: begin
                                    type_OS_enable = 1;
                                    type_OS_comb = TS2 ;
                                    if (cons_count !=0 && type_OS == TS1 && !pad_link_flag) begin
                                        cons_set = 1'b1 ; 
                                    end
                                    else if (!pad_link_flag) begin	
                                        enable_cons = 1'b1 ;
                                    end 
                                    else begin
                                        cons_rst = 1'b1; 
                                    end
                                end
                                default: begin
                                    cons_rst = 1'b1 ;
                                    OS_match_comb = 1'b0;
                                    enable_OS_match = 1'b1;
                                end
                            endcase
                        end                        
                        recovery_idle_skp,recovery_idle_sds,recovery_idle_idl:	begin  
                            // enable cons_count if os_symbol is TS1 identifier and block type is os or os_symbol is IDL                                     
                            if(Block_Type==BLOCK_TYPE_OS)begin	
                                OS_match_comb = 1'b0;
                                enable_OS_match = 1'b1; 
                                if(OS_symbol != TS1_ID)begin
                                    cons_rst = 1'b1 ;
                                end
                                else begin
                                    enable_cons = 'd1;
                                end                           
                            end
                            else begin
                                if(OS_symbol==idle)begin
                                    enable_cons = 1'b1 ;
                                end
                                else begin
                                    cons_rst = 1'b1 ;
                                end
                            end                                       
                        end				     
                    endcase
                end
            end
            default : begin
                if(OS_match)begin
                    case(current_state)
                        L0:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(gen == LOW_GEN)begin
                                if(OS_symbol  == COM )begin
                                    type_IDL_TS = 1;
                                end
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        pre_recovery:begin
                            // set type_IDL_ts if recieving TS1 symbol
                            if(OS_symbol  == COM )begin
                                type_IDL_TS = 1;
                                OS_match_comb = 1'b1;
                                enable_OS_match = 1'b1;
                            end
                        end
                        config_idle_2 : begin
                            // reset cons counter if OS_symbol not equal IDL
                            OS_match_comb = 1'b1;
                            enable_OS_match = 1'b1 ;
                            if(OS_symbol== idle) begin
                                enable_cons = 1'b1 ;
                            end
                            else  begin
                                cons_rst = 1'b1 ;
                            end
                        end
                        recovery_idle_skp,recovery_idle_sds,recovery_idle_idl:	begin      
                            // enable cons_count if os_symbol is TS1 identifier and block type is os or os_symbol is IDL                                 
                            if(Block_Type==BLOCK_TYPE_OS)begin	
                                enable_cons = 1'b0 ;
                                cons_rst = 'd0;
                            end
                            else begin
                                if(OS_symbol==idle)begin
                                    enable_cons = 1'b1 ;
                                end
                                else begin
                                    cons_rst = 1'b1 ;
                                end
                            end                                       
                        end
                    endcase
                end
            end
        endcase
    end
end
endmodule