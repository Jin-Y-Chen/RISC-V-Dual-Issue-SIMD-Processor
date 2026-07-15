`timescale 1ns / 1ps

 // Free List — allocator for Physical Register File (PRF) indices only.
 // Initial pool: p32..p63 (p0..p31 reserved as identity map for x0..x31).
 // alloc_req* size the ready check; alloc*_en pops on the clock.
 // Per cycle: commit frees first (checkpoint), then speculative alloc pops.
 // Flush restores the post-commit checkpoint (undoes speculative allocates).
import rv_dis_pkg::*;

module free_list (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls
  input  logic        flush,

  // allocate — request for ready, enable for pop
  input  logic        alloc_req0,
  input  logic        alloc_req1,
  input  logic        alloc0_en,
  input  logic        alloc1_en,
  output prf_addr_t   alloc0_preg,
  output prf_addr_t   alloc1_preg,
  output logic        alloc_ready,

  // free — ROB commit releases previous mappings
  input  logic        free0_en,
  input  logic        free1_en,
  input  prf_addr_t   free0_preg,
  input  prf_addr_t   free1_preg
);

  localparam int FREE_N  = NUM_PRF - NUM_GPR;  // 32
  localparam int FREE_AW = $clog2(FREE_N);

  typedef logic [FREE_AW:0] free_cnt_t;

  prf_addr_t queue      [FREE_N];
  prf_addr_t queue_ckpt [FREE_N];
  free_cnt_t head_q, tail_q, count_q;
  free_cnt_t head_ckpt, tail_ckpt, count_ckpt;

  wire free_cnt_t n_need = free_cnt_t'(alloc_req0) + free_cnt_t'(alloc_req1);
  assign alloc_ready = (count_q >= n_need);

  // Peek next free indices (parent gates with rename_fire).
  assign alloc0_preg = queue[head_q[FREE_AW-1:0]];
  assign alloc1_preg = queue[FREE_AW'(head_q[FREE_AW-1:0] + FREE_AW'(alloc_req0))];

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    free_cnt_t head_n, tail_n, count_n;
    free_cnt_t head_a, tail_a, count_a;

    if (!rst_n) begin
      for (i = 0; i < FREE_N; i++) begin
        queue[i]      <= prf_addr_t'(NUM_GPR + i);
        queue_ckpt[i] <= prf_addr_t'(NUM_GPR + i);
      end
      head_q     <= '0;
      tail_q     <= '0;
      count_q    <= free_cnt_t'(FREE_N);
      head_ckpt  <= '0;
      tail_ckpt  <= '0;
      count_ckpt <= free_cnt_t'(FREE_N);
    end else if (flush) begin
      for (i = 0; i < FREE_N; i++)
        queue[i] <= queue_ckpt[i];
      head_q  <= head_ckpt;
      tail_q  <= tail_ckpt;
      count_q <= count_ckpt;
    end else if (enable) begin
      head_n  = head_q;
      tail_n  = tail_q;
      count_n = count_q;

      // 1) Commit frees first — architected reclaim.
      if (free0_en) begin
        queue[tail_n[FREE_AW-1:0]] <= free0_preg;
        tail_n  = tail_n + 1'b1;
        count_n = count_n + 1'b1;
      end
      if (free1_en) begin
        queue[tail_n[FREE_AW-1:0]] <= free1_preg;
        tail_n  = tail_n + 1'b1;
        count_n = count_n + 1'b1;
      end

      // Checkpoint after frees (before speculative allocate).
      head_a  = head_n;
      tail_a  = tail_n;
      count_a = count_n;
      if (free0_en || free1_en) begin
        for (i = 0; i < FREE_N; i++)
          queue_ckpt[i] <= queue[i];
        if (free0_en)
          queue_ckpt[tail_q[FREE_AW-1:0]] <= free0_preg;
        if (free1_en)
          queue_ckpt[FREE_AW'(tail_q[FREE_AW-1:0] + FREE_AW'(free0_en))] <= free1_preg;
        head_ckpt  <= head_a;
        tail_ckpt  <= tail_a;
        count_ckpt <= count_a;
      end

      // 2) Speculative allocate pops.
      if (alloc0_en && (count_n != '0)) begin
        head_n  = head_n + 1'b1;
        count_n = count_n - 1'b1;
      end
      if (alloc1_en && (count_n != '0)) begin
        head_n  = head_n + 1'b1;
        count_n = count_n - 1'b1;
      end

      head_q  <= head_n;
      tail_q  <= tail_n;
      count_q <= count_n;
    end
  end

endmodule
