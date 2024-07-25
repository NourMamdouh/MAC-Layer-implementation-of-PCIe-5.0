/*-----------------------------------------------------------------------------
This module concerns with:
1- Convert the time value given in ms or ns into clock cycles 
2- Start the timer as directed by the LTSSM using start and start_speed_neg signals
3- Assert the timeout signal once the time value insicated is passed
 -----------------------------------------------------------------------------*/ 
module Timer #(
    TIME_VALUE_WIDTH = 3
)(
    input   logic                        clk,
    input   logic                        rst,
    input   logic                        start,
    input   logic                        start_speed_neg,
    input   logic [0:TIME_VALUE_WIDTH-1] timeout_value1,
    input   logic                        timeout_value2,
    output  logic                        timeout1,
    output  logic                        timeout3,
    output  logic                        timeout2
);

localparam count_reg_width   = 16;
localparam count_reg_width_3 = 10;

//////// translation of ms into clk cycles //////// 
localparam one_ms_vs_cycles  = 1024;
localparam one_ns_speed_vs_cycles = 1;

//////// time value encoding ////////
localparam t12 = 'b00 , t24 = 'b01 , t2 = 'b10 , t48 = 'b11;

// Define registers
logic [0:count_reg_width-1]   count_reg;
logic [0:count_reg_width_3-1] count_reg_speed;
logic [0:2]                   timeout_value1_reg;
logic                         timeout_value2_reg;

// Internal wires
logic [0:count_reg_width-1] timeout_cycles1; 
logic [0:count_reg_width-1] timeout_cycles2;
logic [0:count_reg_width_3-1] timeout3_cycles;
logic timeout2_enable;
logic timeout2_comb;
logic timeout2_reg;

always @(*)begin
    case(timeout_value1_reg)
    t12: begin
        // Calculate number of clock cycles for the timeout value
         timeout_cycles1 = 12 * one_ms_vs_cycles ;
    end
    t24: begin
        // Calculate number of clock cycles for the timeout value
         timeout_cycles1 = 24 * one_ms_vs_cycles;
    end
    t2: begin
        // Calculate number of clock cycles for the timeout value
         timeout_cycles1 = 2 * one_ms_vs_cycles;
    end
    t48: begin
        // Calculate number of clock cycles for the timeout value
         timeout_cycles1 = 48 * one_ms_vs_cycles;
    end
    default: begin
        // Calculate number of clock cycles for the timeout value
         timeout_cycles1 = 2 * one_ms_vs_cycles;
    end
    endcase
end

assign timeout_cycles2 = 1 * one_ms_vs_cycles;
assign timeout3_cycles = 800 * one_ns_speed_vs_cycles;

// Counter logic
always_ff @(posedge clk , negedge rst) begin
    if(!rst)begin
        count_reg <= 0;
        timeout_value1_reg <= 0;
        timeout_value2_reg <= 0;
        timeout2_reg <= 0; 
    end else begin
        if (start) begin
                count_reg <= 0;
                timeout_value1_reg <= timeout_value1;
                timeout_value2_reg <= timeout_value2;
                timeout2_reg <= 0;
        end else begin 
            if(count_reg != (timeout_cycles1-1))begin
                count_reg <= count_reg + 1;
            end
            if(timeout2_enable)begin
            timeout2_reg <= timeout2_comb;
            end
        end
    end
end

always_ff @(posedge clk , negedge rst)begin
    if(!rst)begin
        count_reg_speed <= 0;
    end
    else begin
        if(start_speed_neg)begin
            count_reg_speed <= 0;
        end
        else begin
            if(count_reg_speed != (timeout3_cycles-1))begin
                count_reg_speed <= count_reg_speed + 1;
            end
        end
    end
end

// Timeout logic
always_comb begin
    timeout2_comb = 0; 
    timeout2_enable = 0;
    if (count_reg == (timeout_cycles1 -1))
        timeout1 = 1;
    else
        timeout1 = 0;
    if(timeout_value2_reg && count_reg == timeout_cycles2 )begin
        timeout2_comb = 1; 
        timeout2_enable = 1; 
        timeout2 = 1;  
    end
    else begin
        timeout2_comb = 0;
        timeout2 = timeout2_reg;
    end
    if(count_reg_speed == (timeout3_cycles -1))begin
        timeout3 = 1;
    end
    else begin
        timeout3 = 0;
    end
end

endmodule
