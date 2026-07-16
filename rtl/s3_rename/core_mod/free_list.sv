`timescale 1ns / 1ps

// Dual-path partitioned free list: q0={p32,p34,..} q1={p33,p35,..}
// Rename rd++; commit free wr++ (by parity); flush refills.
import rv_dis_pkg::*;
import rat_pkg::*;

module free_list (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  br_map_t     brch_map,

  input  logic        rename0_en,
  input  logic        rename1_en,
  output prf_addr_t   i0_alloc_br0,
  output prf_addr_t   i0_alloc_br1,
  output prf_addr_t   i1_alloc_br0,
  output prf_addr_t   i1_alloc_br1,
  output logic        alloc0_valid,
  output logic        alloc1_valid,

  input  logic        free0_en,
  input  logic        free1_en,
  input  prf_addr_t   i0_free_tag,
  input  prf_addr_t   i1_free_tag
);

  localparam int PART_N = (NUM_PRF - NUM_GPR) / 2;
  localparam int Q_AW   = $clog2(PART_N);
  typedef logic [Q_AW:0] q_ptr_t;

  prf_addr_t q0 [PART_N], q1 [PART_N];
  q_ptr_t    rd0, wr0, rd1, wr1;

  wire one_col = rat_one_col(brch_map);
  wire use0    = rat_use_br0(brch_map);
  wire use1    = rat_use_br1(brch_map);
  wire dual    = use0 && use1 && !one_col;

  wire q_ptr_t n0 = wr0 - rd0;
  wire q_ptr_t n1 = wr1 - rd1;

  assign i0_alloc_br0 = use0 ? q0[rd0[Q_AW-1:0]] : '0;
  assign i0_alloc_br1 = one_col ? q0[rd0[Q_AW-1:0]]
                      : use1    ? q1[rd1[Q_AW-1:0]] : '0;
  assign i1_alloc_br0 = one_col ? q1[rd1[Q_AW-1:0]]
                      : use0    ? q0[(rd0 + 1'b1)[Q_AW-1:0]] : '0;
  assign i1_alloc_br1 = one_col ? q1[rd1[Q_AW-1:0]]
                      : use1    ? q1[(rd1 + 1'b1)[Q_AW-1:0]] : '0;

  assign alloc0_valid = dual ? (n0 >= 1 && n1 >= 1) :
                        use0 ? (n0 >= 1) : use1 ? (n1 >= 1) : 1'b0;
  assign alloc1_valid = dual ? (n0 >= 2 && n1 >= 2) :
                        one_col ? (n0 >= 1 && n1 >= 1) :
                        use0 ? (n0 >= 2) : use1 ? (n1 >= 2) : 1'b0;

  wire fire0 = rename0_en && alloc0_valid;
  wire fire1 = rename1_en && (rename0_en ? alloc1_valid : alloc0_valid);

  integer i;
  always_ff @(negedge clk or negedge rst_n) begin
    q_ptr_t r0, w0, r1, w1;

    if (!rst_n || flush) begin
      for (i = 0; i < PART_N; i++) begin
        q0[i] <= prf_addr_t'(NUM_GPR + i * 2);
        q1[i] <= prf_addr_t'(NUM_GPR + 1 + i * 2);
      end
      {rd0, wr0} <= {q_ptr_t'(0), q_ptr_t'(PART_N)};
      {rd1, wr1} <= {q_ptr_t'(0), q_ptr_t'(PART_N)};
    end else begin
      r0 = rd0; w0 = wr0;
      r1 = rd1; w1 = wr1;

      if (free0_en && i0_free_tag >= NUM_GPR) begin
        if (!i0_free_tag[0] && (w0 - r0) != PART_N) begin
          q0[w0[Q_AW-1:0]] <= i0_free_tag; w0++;
        end else if (i0_free_tag[0] && (w1 - r1) != PART_N) begin
          q1[w1[Q_AW-1:0]] <= i0_free_tag; w1++;
        end
      end
      if (free1_en && i1_free_tag >= NUM_GPR) begin
        if (!i1_free_tag[0] && (w0 - r0) != PART_N) begin
          q0[w0[Q_AW-1:0]] <= i1_free_tag; w0++;
        end else if (i1_free_tag[0] && (w1 - r1) != PART_N) begin
          q1[w1[Q_AW-1:0]] <= i1_free_tag; w1++;
        end
      end

      if (fire0) begin
        if (dual || one_col || use0) r0++;
        if (dual || (!one_col && use1)) r1++;
      end
      if (fire1) begin
        if (dual || (!one_col && use0)) r0++;
        if (dual || one_col || use1) r1++;
      end

      rd0 <= r0; wr0 <= w0;
      rd1 <= r1; wr1 <= w1;
    end
  end

endmodule
