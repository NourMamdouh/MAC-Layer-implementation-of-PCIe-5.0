module elstc_buff_TOP #(
  BUFFER_WIDTH = 'd13,
  DEPTH        = 'd8, 
  PTR_WIDTH    = 'd4, 
  ADDR_WIDTH   = 'd3,
  THRESHOLD    = 'd2,
  SYMBOL_WIDTH = 'd8,
  COUNT_WIDTH  = 'd4
)(
  input  logic                        rx_clk, rx_rst,
  input  logic                        local_clk, local_rst,
  input  logic [BUFFER_WIDTH -1:0]    rx_data,
  input  logic                        elstc_buff_en,
  input  logic                        higher_gen_en,
  input  logic                        LTSSM_rst,
  output logic [SYMBOL_WIDTH -1:0]    output_symbol,
  output logic                        block_type,
  output logic [COUNT_WIDTH -1:0]     buff_count,
  output logic                        valid,
  output logic                        full 
);
  
logic                     SKP_remv_rqst, write_en , empty;
logic [ADDR_WIDTH -1:0]   waddr, raddr;
logic [PTR_WIDTH -1 :0]   gray_rptr, gray_wptr, w_gray_rptr, r_gray_wptr, wptr, delayed_wptr;

write_processor #(
  .BUFFER_WIDTH(BUFFER_WIDTH)
)u0_write_processor(
  .rx_clk(rx_clk),
  .rx_rst(rx_rst),
  .rx_data(rx_data),
  .elstc_buff_en(elstc_buff_en),
  .SKP_remv_rqst(SKP_remv_rqst),
  .write_en(write_en)
);
   
wptr_generation #(
  .THRESHOLD(THRESHOLD),
  .PTR_WIDTH(PTR_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH)
)u0_wptr_generation (
  .rx_clk(rx_clk),
  .rx_rst(rx_rst),
  .write_en(write_en),
  .w_gray_rptr(w_gray_rptr),
  .delayed_wptr (delayed_wptr),
  .waddr(waddr),
  .SKP_remv_rqst(SKP_remv_rqst),
  .gray_wptr(gray_wptr),
  .full(full),
  .wptr(wptr),
  .LTSSM_rst (LTSSM_rst)
);
 
storage_unit #(
  .BUFFER_WIDTH(BUFFER_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH),
  .DEPTH(DEPTH),
  .SYMBOL_WIDTH(SYMBOL_WIDTH),
  .COUNT_WIDTH(COUNT_WIDTH)
)u0_storage_unit (
  .rx_clk(rx_clk),
  .rx_rst(rx_rst),
  .local_clk(local_clk),
  .valid(valid),
  .rx_data(rx_data),
  .waddr(waddr),
  .raddr(raddr),
  .LTSSM_rst (LTSSM_rst),
  .elstc_buff_en(elstc_buff_en),
  .write_en(write_en),
  .output_symbol(output_symbol),
  .block_type(block_type),
  .count(buff_count),
  .empty(empty)
);

read_proc_and_ptr_genr #(
  .ADDR_WIDTH(ADDR_WIDTH), 
  .PTR_WIDTH(PTR_WIDTH) 
)u0_read_proc_and_ptr_genr(
  .local_clk(local_clk),
  .local_rst(local_rst),
  .r_gray_wptr(r_gray_wptr),
  .higher_gen_en(higher_gen_en),
  .empty(empty),
  .gray_rptr(gray_rptr),
  .raddr(raddr),
  .LTSSM_rst(LTSSM_rst)
);

 
dff_sync2 #(
  .PTR_WIDTH(PTR_WIDTH)
)u0_synchronizer(
  .clk(rx_clk),
  .rst(rx_rst),
  .async(gray_rptr),
  .sync(w_gray_rptr)
);
 
dff_sync2 #(
  .PTR_WIDTH(PTR_WIDTH)
)u1_synchronizer(
  .clk(local_clk),
  .rst(local_rst),
  .async(gray_wptr),
  .sync(r_gray_wptr)
);
 
//this instance is used to delay the wptr to use it for comaprison, it is used for synchronization as the wptr is from the same domain of the rx_clk
dff_sync2 #(
  .PTR_WIDTH(PTR_WIDTH)
)u2_synchronizer (
  .clk(rx_clk),
  .rst(rx_rst),
  .async(wptr),
  .sync(delayed_wptr)
);
 
   
endmodule 
  
   
   
  
