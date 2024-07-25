module PHY_RX #(
    SYMBOL_WIDTH				    = 'd8,           		  	// in bits
    PACKET_LENGTH				    = 'd11,        			    // in DW
    SYMBOL_NUM_WIDTH			    = 'd4, 								
    SYMBOL_PTR_WIDTH 			    = 'd5,						// for framing buffer data_width && Last_Byte
    MAX_LANES					    = (2**SYMBOL_PTR_WIDTH),    // max number of lanes
    FILTERED_Buff_DATA_In_WIDTH 	= 'd30,
    FILTERED_Buff_DATA_Out_WIDTH 	= 'd31,
    FRAME_DEPTH                     = 4,
    DATA_WIDTH                      = 256,
    BUFFER_DEPTH                    = 8,
    ADDR_WIDTH                      = 3,
    serdes                          = 0,
    SYNC_WIDTH                      = 2,
    BUFFER_WIDTH                    = 13,
    PTR_WIDTH                       =4,
    DEPTH                           =8,
    THRESHOLD                       =2,
    BITS_COUNT_WIDTH                =3
) (
    input										CLK,RST_L,
    input                                       i_EN_BA,
    input                                       rx_clk, rx_rst,
    input [0:255]                               rx_data,
    input                                       GEN,  
    input	    								i_Lanes,   			// 32 lanes or only one lane
    input                                       i_RD_EN,
    input [0:31]                                PIPE_d_K,
    input [0:31]                                RXValid,   
    input                                       i_EN_PF,
    input                                       enable_LDS,
    input  [0:31]                               RX_Data_Valid,
    input  [0:31]                               RX_Start_Block,
    input  [0:1]                                RX_SYNC_Header [0:31], 
    input                                       Soft_RST_blocks,
    input                                       type_IDL_TS,
    input                                       PIPE_CNT_rst,
    input                                       rst_BA,
    output [0:31]                               BA_error,
    output                                      Deskew_error,
    output                                      o_Empty,
    output [0:DATA_WIDTH-1]                     Data_Out,
    output                                      o_SOP,o_End_Valid,o_Type,
    output [PACKET_LENGTH-1:0]                  o_Length,
    output [SYMBOL_PTR_WIDTH-1:0]               o_Last_Byte,
    output                                      PF_Error,
    output [3:0]                                deskewed_RX_count [0:31],
    output [0:255]                              Des_Data_Out,
    output [0:31]                               deskewed_RX_sync,
    output                                      EIEOS_Flag,
    output                                      valid_deskew


);
////////////////////// Internal Signals ///////////////////////////
    logic   [0:31]                                          deskewed_RX_valid;

////////////////////// Instantiation //////////////////////////////
generate
    if(serdes) begin
        RX_TOP #(
            .BUFFER_DEPTH(BUFFER_DEPTH),
            .ADDR_WIDTH(ADDR_WIDTH)
        ) RT(
            .CLK(CLK), 
            .RST_L(RST_L), 
            .i_EN(i_EN_PF && deskewed_RX_valid[0]), 
            .i_Lanes(i_Lanes), 
            .i_RCV_Data(Des_Data_Out), 
            .i_Block_Type(deskewed_RX_sync[0]), 
            .i_Symbol_Num(deskewed_RX_count[0]),
            .i_RD_EN(i_RD_EN),    
            .Data_Out(Data_Out),          
            .o_Empty(o_Empty),
            .o_SOP(o_SOP),
            .o_End_Valid(o_End_Valid),
            .o_Type(o_Type),
            .o_Length(o_Length),
            .o_Last_Byte(o_Last_Byte),
            .EIEOS_Flag(EIEOS_Flag),  
            .Soft_RST_blocks(Soft_RST_blocks), 
            .o_Error(PF_Error)
        );
    end

    else begin
        RX_TOP #(
            .BUFFER_DEPTH(BUFFER_DEPTH),
            .ADDR_WIDTH(ADDR_WIDTH)
        ) RT(
            .CLK(CLK), 
            .RST_L(RST_L), 
            .i_EN(i_EN_PF && RX_Data_Valid[0]), 
            .i_Lanes(i_Lanes), 
            .i_RCV_Data(Des_Data_Out), 
            .i_Block_Type(deskewed_RX_sync[0]), 
            .i_Symbol_Num(deskewed_RX_count[0]),
            .i_RD_EN(i_RD_EN),    
            .Data_Out(Data_Out),          
            .o_Empty(o_Empty),
            .o_SOP(o_SOP),
            .o_End_Valid(o_End_Valid),
            .o_Type(o_Type),
            .o_Length(o_Length),
            .o_Last_Byte(o_Last_Byte),
            .Soft_RST_blocks(Soft_RST_blocks),
            .EIEOS_Flag(EIEOS_Flag),  
            .o_Error(PF_Error)
        );
    end
endgenerate
    
top_RX #(
    .serdes(serdes),
    .CNT_WIDTH(SYMBOL_NUM_WIDTH),       
    .DATA_WIDTH(DATA_WIDTH),      
    .MAX_LANES(MAX_LANES),        
    .SYNC_WIDTH(SYNC_WIDTH),       
    .BUFFER_WIDTH(BUFFER_WIDTH),     
    .PTR_WIDTH(PTR_WIDTH),        
    .ADDR_WIDTH(ADDR_WIDTH),       
    .DEPTH(DEPTH),            
    .THRESHOLD(THRESHOLD),        
    .SYMBOL_WIDTH(SYMBOL_WIDTH),     
    .BITS_COUNT_WIDTH(BITS_COUNT_WIDTH) 
)DUT( 
    .local_clk(CLK), 
    .local_rst(RST_L), 
    .rx_clk(rx_clk), 
    .rx_rst(rx_rst),
    .rx_data(rx_data),
    .GEN(GEN),
    .enable(i_EN_BA),
    .PIPE_d_K(PIPE_d_K),
    .enable_ltssm(enable_LDS),
    .Des_Data_Out(Des_Data_Out),
    .BA_error(BA_error),
    .Deskew_error(Deskew_error),
    .deskewed_RX_valid(deskewed_RX_valid),
    .valid_deskew(valid_deskew),
    .deskewed_RX_sync(deskewed_RX_sync),
    .output_count(deskewed_RX_count),
    .RX_Data_Valid(RX_Data_Valid),
    .RXValid(RXValid),
    .RX_Start_Block(RX_Start_Block),
    .Soft_RST_blocks(Soft_RST_blocks), 
    .PIPE_CNT_rst(PIPE_CNT_rst),  
    .type_IDL_TS(type_IDL_TS), 
    .RX_SYNC_Header(RX_SYNC_Header),
    .rst_BA(rst_BA)
);

endmodule
