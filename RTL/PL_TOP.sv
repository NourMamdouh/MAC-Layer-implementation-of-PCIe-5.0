module PL_TOP #(
    serdes                       = 0,
    DATA_WIDTH                   = 256,
    BUFFER_DEPTH                 = 8,
    ADDR_WIDTH                   = 3,
    PACKET_LENGTH	             = 'd11,    
    SYMBOL_PTR_WIDTH             = 'd5,					
    SYMBOL_NUM_WIDTH	         = 'd4, 								
    SYMBOL_WIDTH		         = 'd8,           		  	
    MAX_LANES			         = (2**SYMBOL_PTR_WIDTH),
    FILTERED_Buff_DATA_In_WIDTH  = 30,
    FILTERED_Buff_DATA_Out_WIDTH = 31,
    FRAME_DEPTH                  = 4,
    SYNC_WIDTH                   =2,
    BUFFER_WIDTH_ELSTC_BUFF      = 13,
    PTR_WIDTH                    =4,
    DEPTH_ELSTC_BUFF             =8,
    THRESHOLD_PTR_ELSTC_BUFF     =2,
    BITS_COUNT_WIDTH             =3,
    state_width                  =5,
    CONFIG_WIDTH                 =3
)( 
    input  logic                                     clk,rst,
    input  logic                                     rx_clk, rx_rst,
    input  logic    [0:DATA_WIDTH-1]                 rx_data,
    input  logic    [0:MAX_LANES-1]                  valid_lower_gen,
    input  logic                                     gen,
    //Interface with Data Link Layer.
    output logic                                     O_Link_Up,
    output logic                                     O_Retrain_succ,
    output logic    [0:1]                            O_Actual_pwr,
    input  logic    [0:1]                            I_Pwr_States,
    input  logic                                     Retrain,
    input  logic                                     i_RD_EN,
    input  logic                                     i_WR_EN,
    input  logic                                     i_SOP,i_End_Valid,i_Type,
    input  logic    [PACKET_LENGTH-1:0]              i_Length,
    input  logic    [SYMBOL_PTR_WIDTH-1:0]           i_Last_Byte,
    input  logic    [0:DATA_WIDTH-1]                 Data_IN,
    output logic                                     o_Full, // re consider the throttling of DATA LINK Layer
    output logic    [0:(SYMBOL_WIDTH*MAX_LANES)-1]	 out_data, // GEN 3 
    output logic    [0:MAX_LANES-1]                  valid_data, // GEN3
    output logic    [0:MAX_LANES-1]                  TxStartBlock,
    output logic    [0:1]                            TxSyncHeader [0:MAX_LANES-1], 
    //Interface with PIPE.
    input  logic    [0:MAX_LANES-1]                  PIPE_d_K,
    input  logic    [0:MAX_LANES-1]                  RX_Data_Valid,
    input  logic    [0:MAX_LANES-1]                  RX_Start_Block,
    input  logic    [0:1]                            RX_SYNC_Header [0:MAX_LANES-1],  
    output logic    [0:MAX_LANES-1]                  O_St_Detect,
    output logic    [1:0]                            powerDown_PIPE [0:MAX_LANES-1],
    output logic    [2:0]                            O_rate,
    //output logic O_Block_align,    
    input  logic    [0:MAX_LANES-1]                  I_Rcv_Deteted,
    input  logic    [0:MAX_LANES-1]                  I_RX_EIdle,
    output logic    [0:MAX_LANES-1]                  TxElecIdle_PIPE ,
    output logic                                     o_PIPE_rst,
    input  logic                                     I_PhyStatus,
    output logic                                     o_Empty,
    output logic    [0:DATA_WIDTH-1]                 Data_Out,
    output logic                                     o_SOP,o_End_Valid,o_Type,
    output logic    [PACKET_LENGTH-1:0]              o_Length,
    output logic    [0:MAX_LANES-1]                  o_K_PIPE,
    output logic    [SYMBOL_PTR_WIDTH-1:0]           o_Last_Byte,
    output logic                                     Physical_recovery   
);
    
// LTSSM Internal sigs
logic  [0:DATA_WIDTH-1]          rx_OS_symbol   ;
logic  [0:SYMBOL_NUM_WIDTH-1]    rx_symbol_count [0:MAX_LANES-1];
logic                            os_enable;
logic                            frame_skp_enable;
logic                            ack_idle;
logic                            idle_16;
logic  [0:DATA_WIDTH-1]          o_OS; 
logic                            o_Sync_Sel;

// TX-RX Internal sigs
logic [0:MAX_LANES-1]            o_K;
logic                            i_EN_BA;
logic	    	                 i_Lanes;  // 32 lanes or only one lane
logic                            i_EN_PF;
logic    						 o_Idle_Indicator;  //raised one when sending idles (no more TLPs or DLLPs to send)
logic                            valid_deskew;
logic [0:MAX_LANES-1]            back_pressures;
logic                            o_EN_blocks;
logic [0:MAX_LANES-1]            Block_Type;
logic                            EIEOS_Flag;
logic                            Soft_RST_blocks;
logic [0:MAX_LANES-1]            type_IDL_TS;
logic                            PIPE_CNT_rst;
logic                            RX_Error; //to be raised when an error is detecteds
logic                            rst_BA;
logic                            IDL_rst;

localparam HIGH_GEN = 1;
localparam LOW_GEN  = 0;

assign o_K_PIPE = (o_K & {'d32{(os_enable | frame_skp_enable)}});
    
phy_top #(
    .serdes(serdes),                       
    .DATA_WIDTH(DATA_WIDTH),                   
    .BUFFER_DEPTH(BUFFER_DEPTH),                 
    .ADDR_WIDTH(ADDR_WIDTH),                   
    .PACKET_LENGTH(PACKET_LENGTH),	             
    .SYMBOL_PTR_WIDTH(SYMBOL_PTR_WIDTH),             
    .SYMBOL_NUM_WIDTH(SYMBOL_NUM_WIDTH),	         		
    .SYMBOL_WIDTH(SYMBOL_WIDTH),		         	
    .MAX_LANES(MAX_LANES),			         
    .FILTERED_Buff_DATA_In_WIDTH(FILTERED_Buff_DATA_In_WIDTH),  
    .FILTERED_Buff_DATA_Out_WIDTH(FILTERED_Buff_DATA_Out_WIDTH), 
    .FRAME_DEPTH(FRAME_DEPTH),                  
    .SYNC_WIDTH(SYNC_WIDTH),                   
    .BUFFER_WIDTH_ELSTC_BUFF(BUFFER_WIDTH_ELSTC_BUFF),      
    .PTR_WIDTH(PTR_WIDTH),                    
    .DEPTH_ELSTC_BUFF(DEPTH_ELSTC_BUFF),             
    .THRESHOLD_PTR_ELSTC_BUFF(THRESHOLD_PTR_ELSTC_BUFF),     
    .BITS_COUNT_WIDTH(BITS_COUNT_WIDTH)             
) pt(
    .CLK(clk),
    .rx_clk(rx_clk), 
    .rx_rst(rx_rst),
    .rx_data(rx_data),
    .RST_L(rst),
    .i_EN(o_EN_blocks),
    .GEN(gen), 
    .Block_Type(Block_Type), 
    .EIEOS_Flag(EIEOS_Flag),
    .Soft_RST_blocks(Soft_RST_blocks), 
    .type_IDL_TS(type_IDL_TS[0]),   
    .PIPE_CNT_rst(PIPE_CNT_rst),
    .i_EN_BA(i_EN_BA),
    .i_Lanes(i_Lanes),   			
    .i_RD_EN(i_RD_EN),
    .PIPE_d_K(PIPE_d_K),
    .i_EN_PF(i_EN_PF),
    .RXValid(valid_lower_gen),
    .RX_Data_Valid(RX_Data_Valid),
    .RX_Start_Block(RX_Start_Block),
    .RX_SYNC_Header(RX_SYNC_Header), 
    .i_GEN_Lanes({i_Lanes,gen}),
    .i_Os_Enable(os_enable || frame_skp_enable),
    .i_OS(o_OS),
    .i_WR_EN(i_WR_EN),
    .i_SOP(i_SOP),
    .i_End_Valid(i_End_Valid),
    .i_Type(i_Type),
    .i_Length(i_Length),
    .i_Last_Byte(i_Last_Byte),
    .Data_IN(Data_IN),
    .o_Full(o_Full), 
    .out_data(out_data), 
    .valid_data(valid_data), 
    .TxStartBlock(TxStartBlock),
    .TxSyncHeader(TxSyncHeader),
    .o_Idle_Indicator(o_Idle_Indicator),  
    .RX_Error(RX_Error),
    .o_Empty(o_Empty),
    .Data_Out(Data_Out),
    .o_SOP(o_SOP),
    .o_End_Valid(o_End_Valid),
    .o_Type(o_Type),
    .o_Length(o_Length),
    .o_Last_Byte(o_Last_Byte),
    .deskewed_RX_count(rx_symbol_count),
    .o_Sync_Sel(o_Sync_Sel),
    .back_pressures(back_pressures),
    .idle_cnt_enable(idle_16),
    .IDL_rst(IDL_rst),  
    .ack_done(ack_idle),
    .o_D_K(o_K_PIPE),
    .Des_Data_Out(rx_OS_symbol),
    .valid_deskew(valid_deskew),
    .rst_BA(rst_BA)
);

LTSSM_TOP #(
    .state_width(state_width),		    
    .DATA_WIDTH(DATA_WIDTH),          
    .MAX_LANES(MAX_LANES),           
    .CONFIG_WIDTH(CONFIG_WIDTH),        
    .SYMBOL_NUM_WIDTH(SYMBOL_NUM_WIDTH),    
    .SYMBOL_WIDTH(SYMBOL_WIDTH)	    
)LT(
    .clk(clk),
    .rst(rst),
    .rx_OS_symbol(rx_OS_symbol),
    .rx_symbol_count(rx_symbol_count),
    .valid_gen3(RX_Data_Valid),
    .valid_lower_gen(valid_lower_gen),
    .gen(gen),
    .Block_Type(Block_Type[0]),
    .PF_EN(i_EN_PF),
    .BA_EN(i_EN_BA),
    .EIEOS_Flag(EIEOS_Flag),
    .Soft_RST_blocks(Soft_RST_blocks),
    .PIPE_CNT_rst(PIPE_CNT_rst),
    .O_Link_Up(O_Link_Up),
    .O_Retrain_succ(O_Retrain_succ),
    .O_Actual_pwr(O_Actual_pwr),
    .I_Pwr_States(I_Pwr_States),
    .Retrain(Retrain),
    .O_St_Detect(O_St_Detect),
    .powerDown_PIPE(powerDown_PIPE),
    .O_rate(O_rate),
    .type_IDL_TS(type_IDL_TS),
    .I_Rcv_Deteted(I_Rcv_Deteted),
    .I_RX_EIdle(I_RX_EIdle),
    .TxElecIdle_PIPE(TxElecIdle_PIPE) ,
    .o_PIPE_rst(o_PIPE_rst),
    .I_PhyStatus(I_PhyStatus),
    .os_enable(os_enable),
    .ack_idle(ack_idle),
    .idle_16(idle_16),
    .enable_LTSSM((o_Sync_Sel && !back_pressures[0] && (gen == HIGH_GEN))|| (gen == LOW_GEN)),
    .o_OS(o_OS), 
    .o_EN_blocks(o_EN_blocks),
    .back_pressure(back_pressures[0]),
    .frame_skp_enable(frame_skp_enable),
    .IDL_rst(IDL_rst),
    .o_config_lanes(i_Lanes),
    .o_K(o_K),
    .Physical_recovery(Physical_recovery),
    .phy_rx_error(RX_Error),
    .rst_BA(rst_BA)
);

endmodule
