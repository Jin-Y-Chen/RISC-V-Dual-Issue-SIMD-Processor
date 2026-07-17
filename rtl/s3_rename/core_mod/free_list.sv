`timescale 1ns / 1ps

// Free List — circular queue, capacity NUM_PRF (64).
// Reset/flush seeds temps p32..p63; arch tags p1..p31 re-enter on commit free.
import rv_dis_pkg::*;

module free_list (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  input  logic        rename0_en,
  input  logic        rename1_en,
  output prf_addr_t   i0_alloc_tag,
  output prf_addr_t   i1_alloc_tag,
  output logic        alloc0_valid,
  output logic        alloc1_valid,

  input  logic        free0_en,
  input  logic        free1_en,
  input  prf_addr_t   i0_free_tag,
  input  prf_addr_t   i1_free_tag
);

  localparam int FREE_N  = NUM_PRF;
  localparam int INIT_N  = NUM_PRF - NUM_GPR;
  localparam int FREE_AW = $clog2(FREE_N);
  typedef logic [FREE_AW:0] q_ptr_t;

  prf_addr_t q [FREE_N];
  q_ptr_t    rd_q, wr_q;

  wire q_ptr_t nfree = wr_q - rd_q;

  assign i0_alloc_tag = q[rd_q[FREE_AW-1:0]];
  assign i1_alloc_tag = rename0_en ? q[(rd_q + 1'b1)[FREE_AW-1:0]]
                                   : q[rd_q[FREE_AW-1:0]];
  assign alloc0_valid = (nfree >= q_ptr_t'(1));
  assign alloc1_valid = (nfree >= q_ptr_t'(2));

  wire fire0 = rename0_en && alloc0_valid;
  wire fire1 = rename1_en && (rename0_en ? alloc1_valid : alloc0_valid);

  wire free0_ok = free0_en && (i0_free_tag != '0) && (nfree != q_ptr_t'(FREE_N));
  wire free1_ok = free1_en && (i1_free_tag != '0) &&
                  ((nfree + q_ptr_t'(free0_ok)) != q_ptr_t'(FREE_N));

  integer i;
  always_ff @(negedge clk or negedge rst_n) begin
    q_ptr_t rd_n, wr_n;

    if (!rst_n || flush) begin
      for (i = 0; i < INIT_N; i++)
        q[i] <= prf_addr_t'(NUM_GPR + i);
      for (i = INIT_N; i < FREE_N; i++)
        q[i] <= '0;
      rd_q <= '0;
      wr_q <= q_ptr_t'(INIT_N);
    end else begin
      rd_n = rd_q;
      wr_n = wr_q;

      if (free0_ok) begin
        q[wr_n[FREE_AW-1:0]] <= i0_free_tag;
        wr_n = wr_n + 1'b1;
      end
      if (free1_ok) begin
        q[wr_n[FREE_AW-1:0]] <= i1_free_tag;
        wr_n = wr_n + 1'b1;
      end

      if (fire0) rd_n = rd_n + 1'b1;
      if (fire1) rd_n = rd_n + 1'b1;

      rd_q <= rd_n;
      wr_q <= wr_n;
    end
  end

endmodule
