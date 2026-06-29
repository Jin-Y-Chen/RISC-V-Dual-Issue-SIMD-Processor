`timescale 1ns / 1ps

// 16-entry FIFO instruction queue — program-order buffer between decode and dispatch.
module instruction_queue (
  input  logic                          clk,
  input  logic                          rst_n,
  input  logic                          flush,

  // enqueue — at most two ordered slots per cycle (I0 then I1)
  input  logic                          push_en,
  input  logic                          push_i0_valid,
  input  rv_dis_pkg::rob_entry_t push_i0,
  input  logic                          push_i1_valid,
  input  rv_dis_pkg::rob_entry_t push_i1,

  // dequeue — pop 0, 1, or 2 entries from the head after issue
  input  logic [1:0]                    pop_count,

  // status
  output logic                          empty,
  output logic                          full,
  output logic [rv_dis_pkg::ROB_AW:0]    count,

  // peek — head of queue (I0 = oldest, I1 = next)
  output rv_dis_pkg::rob_entry_t head_i0,
  output rv_dis_pkg::rob_entry_t head_i1
);

  localparam int ROB_DEPTH = rv_dis_pkg::ROB_DEPTH;
  localparam int ROB_AW    = rv_dis_pkg::ROB_AW;

  rv_dis_pkg::rob_entry_t mem [0:ROB_DEPTH-1];
  logic [ROB_AW-1:0] wr_ptr;
  logic [ROB_AW-1:0] rd_ptr;
  logic [ROB_AW:0]   count_q;

  wire [1:0]     push_count   = push_i0_valid + push_i1_valid;
  wire [ROB_AW:0] free_slots   = ROB_DEPTH - count_q;
  wire           push_ok      = push_en && ({1'b0, push_count} <= free_slots);

  assign empty = (count_q == 0);
  assign full  = (count_q >= ROB_DEPTH);
  assign count = count_q;

  wire [ROB_AW-1:0] rd_ptr_p1 = rd_ptr + 1'b1;

  assign head_i0 = (count_q >= 1) ? mem[rd_ptr]    : '0;
  assign head_i1 = (count_q >= 2) ? mem[rd_ptr_p1] : '0;

  logic [ROB_AW:0]   next_count;
  logic [ROB_AW-1:0] next_wr;
  logic [ROB_AW-1:0] next_rd;
  logic [ROB_AW-1:0] wr_base;

  always_comb begin
    next_count = count_q - pop_count;
    next_rd    = rd_ptr + pop_count[ROB_AW-1:0];
    next_wr    = wr_ptr;
    wr_base    = wr_ptr;

    if (push_ok) begin
      if (push_i0_valid) begin
        wr_base = wr_base + 1'b1;
      end
      if (push_i1_valid) begin
        wr_base = wr_base + 1'b1;
      end
      next_wr    = wr_base;
      next_count = next_count + push_count;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      wr_ptr  <= '0;
      rd_ptr  <= '0;
      count_q <= '0;
    end else begin
      if (push_ok) begin
        if (push_i0_valid) begin
          mem[wr_ptr] <= push_i0;
        end
        if (push_i1_valid) begin
          mem[wr_ptr + push_i0_valid] <= push_i1;
        end
      end
      wr_ptr  <= next_wr;
      rd_ptr  <= next_rd;
      count_q <= next_count;
    end
  end

endmodule
