/*	Gen3_Top form the Tokens and control the output framed data to frame the packets according to packet indicators and logic of each block
    and is divided into 2 parts as first part to control and out the framed data in 32 lane and second part to control and out the data 
    in 1 lane but out the read enable, IDLE Indicator and sync sel by Oring each of them in 1 lane and 32 lane.*/

module Gen3_Top #(
    parameter SYMBOL_WIDTH		= 'd8,           		  	// in bits
    parameter PACKET_LENGTH		= 'd11,        			    // in DW
    parameter SYMBOL_NUM_WIDTH	= 'd4, 								
    parameter SYMBOL_PTR_WIDTH  = 'd5,						// for framing buffer data_width && Last_Byte
    parameter MAX_LANES			= (2**SYMBOL_PTR_WIDTH),    // max number of lanes
    parameter EDS_DIPTH			= 4, 
    parameter STP_DIPTH			= 4, 
    parameter SDP_DIPTH			= 2,
    parameter FRAMING_DATA_WIDTH= SYMBOL_WIDTH*2,
    parameter SEQ_NUM_WIDTH	    = 12,   
    parameter CNT_WIDTH         = 5,
    parameter DATA_WIDTH        = 1 // Data of OR Gate

)(
    input                                       CLK,
    input                                       RST_L,
    input                                       i_EN_1,
    input                                       i_EN_32,
    // inputs from TX_Buffer
    input       [0:(SYMBOL_WIDTH*MAX_LANES)-1]  i_Buffer_Data,
    input                                       i_SOP, i_End_Valid , i_Type,i_Buffer_Empty,
    input       [SYMBOL_PTR_WIDTH-1:0]          i_Last_Byte,
    input       [PACKET_LENGTH-1:0]             i_Length,
    // inputs from LTSSM
    input                                       i_Os_Enable,
    // inputs from sync logic
    input       [SYMBOL_NUM_WIDTH-1:0]          i_Symbol_Num,
    // Outputs to TX_Buffer
    output logic                                 o_Buffer_R_EN,
    // Outputs to Sync logic
    output logic                                 o_Idle_Indicator,
    output logic                                 o_Sync_Sel,
    // outputs to TX_Frame TOP 
    output logic [0:(SYMBOL_WIDTH*MAX_LANES)-1]	o_Framed_Data_32,
    output logic [0:(SYMBOL_WIDTH*MAX_LANES)-1]	o_Framed_Data_1,
    output logic [1:0]                           o_Fram_Sel_32,
    output logic [1:0]                           o_Fram_Sel_1
);
    ////////////////////Internal signals ///////////////////////
    // from Framing Control 32 lane
    logic [0:FRAMING_DATA_WIDTH-1]       i_Fram_Buff_Data , o_Fram_Buff_Data;
    logic [0:(SDP_DIPTH*SYMBOL_WIDTH-1)] i_SDP;
    logic [0:(STP_DIPTH*SYMBOL_WIDTH-1)] i_STP;
    logic [0:(EDS_DIPTH*SYMBOL_WIDTH-1)] i_EDS;
    logic [0:(SYMBOL_WIDTH-1)]           i_IDL;
    logic                                o_Buffer_R_EN_32, o_Fram_Buff_W_EN , o_Idle_Indicator_32 , o_Sync_Sel_32;

    // from Framing Control 1 lane
    logic                                i_CNT_Done , o_CNT_EN , o_CNT_RST , o_Buffer_R_EN_1 , o_Idle_Indicator_1 , o_Sync_Sel_1;
    logic [SYMBOL_PTR_WIDTH-1:0]	        i_Count , o_CNT_END_VAL , o_CNT_RST_VAL;

    // from Tokens module

    /////////////////Instnatiation//////////////////////////////
    // Framing Control 32 lane instance
    Framing_fsm FSM32(
        .CLK(CLK),
        .RST_L(RST_L),
        .i_EN(i_EN_32),
        .i_Buffer_Data(i_Buffer_Data),
        .i_SOP(i_SOP),
        .i_Last_Byte(i_Last_Byte),
        .i_End_Valid(i_End_Valid),
        .i_Type(i_Type),
        .i_Length(i_Length),
        .i_Buffer_Empty(i_Buffer_Empty),
        .i_Fram_Buff_Data(i_Fram_Buff_Data),
        .i_SDP(i_SDP),
        .i_STP(i_STP),
        .i_EDS(i_EDS),
        .i_IDL(i_IDL),
        .i_Os_Enable(i_Os_Enable),
        .i_Symbol_Num(i_Symbol_Num),
        .o_Buffer_R_EN(o_Buffer_R_EN_32),
        .o_Fram_Buff_Data(o_Fram_Buff_Data),
        .o_Fram_Buff_W_EN(o_Fram_Buff_W_EN),
        .o_Idle_Indicator(o_Idle_Indicator_32),
        .o_Sync_Sel(o_Sync_Sel_32),
        .o_Framed_Data(o_Framed_Data_32),
        .o_Fram_Sel(o_Fram_Sel_32)
    );

    // Framing Control 1 lane instance
    Framing_fsm_one_lane FSM1(
        .CLK(CLK),
        .RST_L(RST_L),
        .i_EN(i_EN_1),
        .i_Buffer_Data(i_Buffer_Data),
        .i_SOP(i_SOP),
        .i_Last_Byte(i_Last_Byte),
        .i_End_Valid(i_End_Valid),
        .i_Type(i_Type),
        .i_Length(i_Length),
        .i_Buffer_Empty(i_Buffer_Empty),
        .i_SDP(i_SDP),
        .i_STP(i_STP),
        .i_EDS(i_EDS),
        .i_IDL(i_IDL),
        .i_Os_Enable(i_Os_Enable),
        .i_Symbol_Num(i_Symbol_Num),
        .i_CNT_Done(i_CNT_Done),
        .i_Count(i_Count),
        .o_CNT_EN(o_CNT_EN),
        .o_CNT_RST(o_CNT_RST),
        .o_CNT_RST_VAL(o_CNT_RST_VAL),
        .o_CNT_END_VAL(o_CNT_END_VAL),
        .o_Buffer_R_EN(o_Buffer_R_EN_1),
        .o_Idle_Indicator(o_Idle_Indicator_1),
        .o_Sync_Sel(o_Sync_Sel_1),
        .o_Framed_Data(o_Framed_Data_1),
        .o_Fram_Sel(o_Fram_Sel_1)
    );

    // Tokens instance 
    tokens TKS(
        .i_Length(i_Length),
        .i_Sequence_number(i_Buffer_Data[4:15]), 
        .o_SDP(i_SDP),
        .o_STP(i_STP),
        .o_EDS(i_EDS),
        .o_IDL(i_IDL)
    );

    //Counter instance
    Counter CTR(
        .CLK(CLK),
        .Hard_RST_L(RST_L),
        .Soft_RST(o_CNT_RST),
        .i_CNT_EN(o_CNT_EN),
        .i_CNT_RST_VAL(o_CNT_RST_VAL),
        .i_CNT_END_VAL(o_CNT_END_VAL),
        .o_CNT(i_Count),
        .o_CNT_Done(i_CNT_Done)
    );

    //Framing Buffer instance
    Framing_Buffer FB(
        .CLK(CLK),
        .RST_L(RST_L),
        .i_Fram_Buff_W_EN(o_Fram_Buff_W_EN),
        .i_Fram_Buff_Data(o_Fram_Buff_Data),
        .o_Fram_Buff_Data(i_Fram_Buff_Data)
    );

    //OR GATE for o_Buffer_R_EN
    OR_Gate REN(
        .x32(o_Buffer_R_EN_32),
        .x1(o_Buffer_R_EN_1),
        .x(o_Buffer_R_EN)
    );

    //OR GATE for o_Idle_Indicator
    OR_Gate II(
        .x32(o_Idle_Indicator_32),
        .x1(o_Idle_Indicator_1),
        .x(o_Idle_Indicator)
    );

    //OR GATE for o_Sync_Sel
    OR_Gate SS(
        .x32(o_Sync_Sel_32),
        .x1(o_Sync_Sel_1),
        .x(o_Sync_Sel)
    );

endmodule