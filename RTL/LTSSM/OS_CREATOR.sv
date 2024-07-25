/* -----------------------------------------------------------------------------
This module serves to:
1- Generates the contents of the Ordered Sets to be sent as directed by the LTSSM module
2- count the number of OS sent 
3- Feed the LTSSM module with a ack signal indicating the sent of requested OS
4- Feed the SKP Counter module with skp done inducating the sent of SKP successfully 
-----------------------------------------------------------------------------*/

module OS_CREATOR #(
    DATA_WIDTH       = 'd256,
    MAX_LANES        = 'd32,
    LINK_NUM_WIDTH   = 'd8,
    CONFIG_WIDTH     = 'd3,
    SYMBOL_NUM_WIDTH = 'd4
)(
    input                                 clk , rst,
    input        [0:CONFIG_WIDTH-1]       type_OS,
    input        [0:CONFIG_WIDTH-2]       repetion, 
    input        [0:LINK_NUM_WIDTH-1]     link_num,
    input                                 gen,
    input        [0:MAX_LANES -1]         lane_pad,
    input        [0:MAX_LANES -1]         link_pad,
    input		                          type_os_one_lane, 
    input                                 skp_enable,   
    input                                 enable_LTSSM,
    input                                 speed_change, 
    input                                 ack_reset,
    input                                 LTSSM_Count_rst,
    output  logic [0:DATA_WIDTH-1]        o_OS,
    output  logic [0:MAX_LANES -1]        o_K,
    output  logic                         ack,
    output  logic                         os_creator_done,
    output  logic                         skp_done,
    output  logic                         frame_skp_enable 
);

//////////// encoding of type_OS sent from LTSSM module ////////////    
localparam  TS1     = 0;
localparam  TS2     = 1;
localparam  SDS     = 2;
localparam  CTL_SKP = 3;
localparam  EIOS    = 4;
localparam  EIEOS   = 5;

//////////// encoding of num of OS to be sent ////////////
localparam infinity  = 2'b00;
localparam rep_1024  = 2'b01;
localparam rep_16    = 2'b10;
localparam rep_32    = 2'b11;

//////////// Ordered Sets Contents //////////// 
localparam  COM           = 8'd188;
localparam  PAD           = 8'hF7;
localparam  FTS           = 8'd0;
localparam  EIEOS_ZERO    = 8'h0;
localparam  EIEOS_ONE     = 8'hFF;
localparam  SDS_ID        = 8'hE1;
localparam  SDS_SYMBOL    = 8'h87;
localparam  EIOS_LOW_GEN  = 8'h7C;
localparam  SKP_LOW_GEN   = 8'h1C;
localparam  SKP_END_CTL   = 8'h78;
localparam  SKP_END       = 8'hE1;
localparam  SKP_SYMBOL    = 8'h99;
localparam  TS1_ID        = 8'h4A;
localparam  TS2_ID        = 8'h45; 
localparam  TS1_first_syb = 8'h1E;
localparam  TS2_first_syb = 8'h2D;

//////////// Supported GENs ////////////  
localparam HIGH_GEN      = 1;
localparam LOW_GEN       = 0;

//////////// Internal Control Signals //////////// 
logic [0:SYMBOL_NUM_WIDTH-1]     o_CNT;
logic                            Soft_RST; 
logic                            symb_15;
logic [0:9]                      sent_OS;
logic [0:9]                      repetion_int;
logic                            skp_flag;
logic                            skp_set;
logic                            skp_rst;

//////////// Decoding of OS number to be sent //////////// 
always_comb begin
    case (repetion)
    rep_1024 : repetion_int = 'd1023;
    rep_16: repetion_int ='d15;
    rep_32: repetion_int = 'd31;
    default: begin
           repetion_int = 'd0;
        end
    endcase   
end
 
assign symb_15 = (o_CNT == 4'd15) ;

//////////// ack generation to acknowledge the sent of OS //////////// 
always_ff @(posedge clk or negedge rst)begin
	if(!rst) begin
      ack <= 1'b0 ;
    end
    else if (ack_reset) begin
        ack <= 1'b0 ;
    end
    else if (sent_OS == repetion_int && repetion_int != infinity) begin
        ack <= 1'b1 ;
    end
end

//////////// Counter for num of OS sent //////////// 
always_ff @(posedge clk or negedge rst)begin
	if(!rst) begin
        sent_OS <= 0 ;
    end
    else if (ack_reset) begin
        sent_OS <= 0 ;
    end
    else if(symb_15  && enable_LTSSM && repetion != infinity  && !skp_enable) begin
        sent_OS <= sent_OS + 1 ;
    end
end

//////////// Counter of Symbols in OS //////////// 
always_ff @(posedge clk or negedge rst)begin
	if(!rst) begin
		o_CNT <= 'd0;
	end 
	else if (Soft_RST || LTSSM_Count_rst) begin
		o_CNT <= 0;
	end
	else if (enable_LTSSM) begin
		o_CNT <= o_CNT + 'd1 ;
	end
end

//////////// Counter of Symbols in OS //////////// 
always_ff @(posedge clk or negedge rst)begin
    if(!rst) begin
        skp_flag <= 0;
    end 
    else begin
        if(skp_rst)begin
            skp_flag <= 0;
        end
        else if (skp_set) begin
            skp_flag <= 1'b1;
        end
    end
end

//////////// Composition of OS to be transmitted //////////// 
always_comb begin 
//////////// Default Values //////////// 
    skp_rst = 1'b0;
    skp_set = 1'b0;
    Soft_RST = 0;
    os_creator_done = 0;
    o_OS = 0;
    skp_done = 'd0;
    frame_skp_enable = 'd0;
    o_K = {'d32{1'b0}};

//////////// SOS HANDLING ////////////    
    if(skp_enable && (skp_flag || gen == 1'b1))begin
        frame_skp_enable = 'd1;
        o_K = {'d32{1'b1}};
        case(o_CNT)
            'd0 :begin
                if(gen == LOW_GEN)begin
                    o_OS = {'d32{COM}};
                end
                else begin
                    o_OS = {'d32{SKP_SYMBOL}};
                end
            end
            'd1 , 'd2 : begin
                if(gen == LOW_GEN)begin
                    o_OS = {'d32{SKP_LOW_GEN}};
                end
                else begin
                    o_OS = {'d32{SKP_SYMBOL}};
                end
            end
            'd3:begin
                if(gen == LOW_GEN)begin
                    o_OS = {'d32{SKP_LOW_GEN}};
                    skp_done = 'd1;
                    Soft_RST = 'd1;
                    skp_rst = 1'b1;
                end
                else begin
                    o_OS = {'d32{SKP_SYMBOL}};
                end
            end
            'd12:begin
                o_OS = {'d32{SKP_END}};
            end
            'd13 , 'd14 :begin
                o_OS = {'d32{8'hFF}};
            end
            'd15:begin
                o_OS = {'d32{8'hFF}};
                skp_done = 'd1;
                frame_skp_enable = 'd0;
            end
            default: begin
                o_OS = {'d32{SKP_SYMBOL}};
            end
        endcase
    end
//////////// other OS HANDLING //////////// 
    else begin
        case(type_OS)
//////////// TS1 Contents ////////////  
        TS1: begin
            case(o_CNT) 
            4'd0: begin
                if(gen == LOW_GEN)begin // low gen
                    o_OS = {'d32{COM}} ;
                    o_K = {'d32{1'b1}};
                    skp_rst = 1'b1;
		        end
                else
                    o_OS = {'d32{TS1_first_syb}} ;
            end
            4'd1: begin
				for (int i=0;i<32;i++)begin
					if(link_pad[i]) begin
						o_OS[i*8 +: 8] = PAD;
						o_K[i] = 1'b1;
					end
					else begin 
						o_OS[i*8 +: 8] = link_num ;
						o_K[i] = 1'b0;
					end
				end
            end
            4'd2: begin	
				for (int i=0;i<32;i++)begin
					if(lane_pad[i]) begin
						o_OS[i*8 +: 8] = PAD ;
						o_K[i] = 1'b1;
					end
					else begin
						o_OS[i*8 +: 8] = i ;
						o_K[i] = 1'b0;
					end
				end	
            end
            4'd3: begin
                o_OS = {'d32{FTS}} ;
            end
            4'd4: begin
                if(speed_change)
                    o_OS = {'d32{8'b01111101}} ;
                else
                    o_OS = {'d32{8'b01111100}} ;
            end
            4'd5: begin
                o_OS = {'d32{8'd0}} ;
            end
            4'd6,4'd7,4'd8,4'd9: begin
                o_OS = {'d32{TS1_ID}} ;
            end
            4'd15 : begin
                os_creator_done = 1'b1;
                skp_set = 1'b1; 
                o_OS = {'d32{TS1_ID}} ;
            end
            default: begin
                o_OS = {'d32{TS1_ID}} ;
            end                                                                                             
            endcase
        end
//////////// EIOS Contents //////////// 
        EIOS:begin
            case(o_CNT)
                'd0:begin
                    o_OS = {'d32{COM}} ;
                    skp_rst = 1'b1;
                end
                'd1 , 'd2 :begin
                    o_OS = {'d32{EIOS_LOW_GEN}};
                end
                'd3:begin
                    o_OS = {'d32{EIOS_LOW_GEN}};
                    os_creator_done = 1'b1;
                    Soft_RST = 1'b1;
                    skp_set = 1'b1;
                end
            endcase
        end
//////////// EIEOS Contents //////////// 
        EIEOS:begin
            case(o_CNT)
            'd0:begin
                o_OS = {'d32{EIEOS_ZERO}};;
                skp_rst = 1'b1;
            end
            'd1 , 'd2 , 'd3 , 'd8 , 'd9 , 'd10 , 'd11:begin
                o_OS = {'d32{EIEOS_ZERO}};;
            end
            'd15:begin
                skp_set = 1'b1;
                o_OS = {'d32{EIEOS_ONE}};
                os_creator_done = 1'b1;
            end
            default:begin
                o_OS = {'d32{EIEOS_ONE}};
            end
            endcase
        end
//////////// CTL_SKP Contents //////////// 
        CTL_SKP: begin
            case(o_CNT) 
            'd0:begin
                o_OS = {'d32{SKP_SYMBOL}} ;
                skp_rst = 1'b1;
            end
            4'd12:begin
                o_OS = {'d32{SKP_END_CTL}} ;
            end
            'd15:begin
                o_OS = {'d32{SKP_SYMBOL}} ;
                skp_set = 1'b1;
                os_creator_done = 1'b1;
            end

            default: begin
                o_OS = {'d32{SKP_SYMBOL}} ;
            end                                                                                             
            endcase
        end
//////////// TS2 Contents //////////// 
        TS2: begin
            case(o_CNT)
            4'd0: begin
                if(gen== LOW_GEN)begin
                    o_OS = {'d32{COM}} ;
                    o_K = {'d32{1'b1}};
                    skp_rst = 1'b1;
                end
                else
					if(!type_os_one_lane)begin
						o_OS = {'d32{TS2_first_syb}} ;
					end
					else begin
						o_OS = {TS2_first_syb,{'d31{TS1_first_syb}}} ;
					end
            end
            4'd1: begin
                if(!type_os_one_lane)begin						
                    for (int i=0;i<32;i++)begin
                        if(link_pad[i])begin
                            o_OS[i*8 +: 8] = PAD ;
                            o_K[i] = 1'b1;
                        end
                        else begin 
                            o_K[i] = 1'b0;
                            o_OS[i*8 +: 8] = link_num ;
                        end
                    end	
                end else begin
                    o_OS = {link_num, {'d31{PAD}}} ;
                    o_K = {1'd0, {'d31{1'd1}}} ;
                end
            end
            4'd2: begin
                if(!type_os_one_lane)begin						
                    for (int i=0;i<32;i++)begin
                        if(lane_pad[i])begin
                            o_OS[i*8 +: 8] = PAD ;
                            o_K[i] = 1'b1;
                        end
                        else begin
                            o_OS[i*8 +: 8] = i ;
                            o_K[i] = 1'b0;
                        end
                    end						
                end
                else begin
                    o_OS = {8'd0,{'d31{PAD}}} ;
                    o_K = {1'd0, {'d31{1'd1}}} ;
                end
            end
            4'd3: begin
                o_OS = {'d32{FTS}} ;
            end
            4'd4: begin
                if(speed_change)
                    o_OS = {'d32{8'b01111101}} ;
                else
                    o_OS = {'d32{8'b01111100}} ;
                end
            4'd5: begin
                o_OS = {'d32{8'd0}} ;
                  end
            4'd6: begin                
                if(!type_os_one_lane)begin
                    o_OS = {'d32{TS2_ID}} ;
                end
                else begin
                    o_OS = {TS2_ID,{'d31{TS1_ID}}} ;
                end
            end
            4'd15 : begin
                os_creator_done = 1'b1; 
                o_OS = {'d32{TS1_ID}} ;
                skp_set = 1'b1;
            end
            default: begin
					if(!type_os_one_lane)begin
						o_OS = {'d32{TS2_ID}} ;
					end
					else begin
						o_OS = {TS2_ID,{'d31{TS1_ID}}} ;
					end
            end                                                                                                 
            endcase
            end
//////////// SDS Contents //////////// 
            SDS:begin
                case(o_CNT)
                'd0: begin
                    o_OS = {'d32{SDS_ID}};
                    skp_rst = 1'b1;
                end
                'd15: begin
                    o_OS = {'d32{SDS_SYMBOL}};
                    os_creator_done = 1'b1;
                    skp_set = 1'b1;
                end
                default:begin
                    o_OS = {'d32{SDS_SYMBOL}};
                end
                endcase
            end
//////////// Default //////////// 
        default: begin
            o_OS = 0;
        end
        endcase
    end
end

endmodule