`timescale 1ns / 1ps

// ROB top — one shared bank; independent head (retire) and tail (alloc).
//
//   rob_alloc  — combo wr_* / tail_n / indices (no bank port)
//   rob_retire — combo from registered head scalars (no WB bypass)
//
// Timing: Execute → WB (negedge complete) → Retire (next cycle).
// Negedge order: WB → commit clear → alloc → pointer latch.
import rv_dis_pkg::*;
import rob_pkg::*;

module reorder_buffer (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  input  logic        alloc0_en,
  input  logic        alloc1_en,
  input  logic        i0_reg_write,
  input  logic        i1_reg_write,
  input  logic        i0_is_brnch,
  input  logic        i1_is_brnch,
  input  logic        i0_is_store,
  input  logic        i1_is_store,
  input  logic        i0_spec_en,
  input  logic        i1_spec_en,
  input  gpr_addr_t   i0_rd_addr,
  input  gpr_addr_t   i1_rd_addr,
  output prf_addr_t   i0_rob_idx,
  output prf_addr_t   i1_rob_idx,
  output logic        stall,

  input  logic        wback0_en,
  input  logic        wback1_en,
  input  prf_addr_t   i0_rob_idx_wb,
  input  prf_addr_t   i1_rob_idx_wb,
  input  logic        i0_brch_taken_wb,
  input  logic        i1_brch_taken_wb,

  input  logic        retire0_en,
  input  logic        retire1_en,
  output logic        i0_can_retire,
  output logic        i1_can_retire,

  output logic        rrat0_en,
  output logic        rrat1_en,
  output gpr_addr_t   i0_rd_addr_cmt,
  output gpr_addr_t   i1_rd_addr_cmt,
  output prf_addr_t   i0_rob_idx_cmt,
  output prf_addr_t   i1_rob_idx_cmt,

  output logic        rat0_en,
  output logic        rat1_en,
  output logic        i0_path_sel,
  output logic        i1_path_sel,

  output logic        stb0_en,
  output logic        stb1_en
);

  rob_payload_t rob_q [ROB_SETS][ROB_WAYS];
  logic [ROB_SETS-1:0][ROB_WAYS-1:0] valid_q;
  rob_ptr_t head_q, tail_q;
  logic     active_spec_q;

  rob_ptr_t occ;
  assign occ   = tail_q - head_q;
  assign stall = (occ > rob_ptr_t'(ROB_DEPTH - 2));

  rob_ptr_t head_n, tail_n;
  logic     active_spec_n;

  logic         wr0_en, wr1_en;
  rob_set_t     wr0_row, wr1_row;
  rob_way_t     wr0_col, wr1_col;
  rob_payload_t wr0_data, wr1_data;

  logic         cmt0, cmt1;
  rob_set_t     clr0_row, clr1_row;
  rob_way_t     clr0_col, clr1_col;

  rob_flat_t    h0, h1;
  logic         v0, v1;
  rob_payload_t p0, p1;

  rob_alloc u_alloc (
    .tail_q,
    .alloc0_en,
    .alloc1_en,
    .i0_reg_write,
    .i1_reg_write,
    .i0_is_brnch,
    .i1_is_brnch,
    .i0_is_store,
    .i1_is_store,
    .i0_spec_en,
    .i1_spec_en,
    .i0_rd_addr,
    .i1_rd_addr,
    .i0_rob_idx,
    .i1_rob_idx,
    .tail_n,
    .wr0_en,
    .wr1_en,
    .wr0_row,
    .wr1_row,
    .wr0_col,
    .wr1_col,
    .wr0_data,
    .wr1_data
  );

  // Head probe from registered bank only (no same-cycle WB bypass)
  assign h0 = head_q[ROB_INDEX_W-1:0];
  assign h1 = rob_flat_t'(h0 + 1'b1);
  assign v0 = valid_q[rob_row(h0)][rob_col(h0)];
  assign v1 = valid_q[rob_row(h1)][rob_col(h1)];
  assign p0 = v0 ? rob_q[rob_row(h0)][rob_col(h0)] : '0;
  assign p1 = v1 ? rob_q[rob_row(h1)][rob_col(h1)] : '0;

  rob_retire u_retire (
    .head_q,
    .active_spec_q,
    .v0,
    .v1,
    .p0,
    .p1,
    .retire0_en,
    .retire1_en,
    .i0_can_retire,
    .i1_can_retire,
    .rrat0_en,
    .rrat1_en,
    .i0_rd_addr_cmt,
    .i1_rd_addr_cmt,
    .i0_rob_idx_cmt,
    .i1_rob_idx_cmt,
    .rat0_en,
    .rat1_en,
    .i0_path_sel,
    .i1_path_sel,
    .stb0_en,
    .stb1_en,
    .head_n,
    .active_spec_n,
    .cmt0,
    .cmt1,
    .clr0_row,
    .clr1_row,
    .clr0_col,
    .clr1_col
  );

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      head_q        <= '0;
      tail_q        <= '0;
      valid_q       <= '0;
      active_spec_q <= 1'b0;
    end else begin
      begin
        automatic rob_set_t wb0_r = rob_set(i0_rob_idx_wb);
        automatic rob_way_t wb0_c = rob_way(i0_rob_idx_wb);
        automatic rob_set_t wb1_r = rob_set(i1_rob_idx_wb);
        automatic rob_way_t wb1_c = rob_way(i1_rob_idx_wb);

        if (wback0_en && valid_q[wb0_r][wb0_c])
          rob_q[wb0_r][wb0_c] <= rob_wback(rob_q[wb0_r][wb0_c], i0_brch_taken_wb);
        if (wback1_en && valid_q[wb1_r][wb1_c])
          rob_q[wb1_r][wb1_c] <= rob_wback(rob_q[wb1_r][wb1_c], i1_brch_taken_wb);
      end

      if (cmt0)
        valid_q[clr0_row][clr0_col] <= 1'b0;
      if (cmt1)
        valid_q[clr1_row][clr1_col] <= 1'b0;

      if (wr0_en) begin
        rob_q[wr0_row][wr0_col]   <= wr0_data;
        valid_q[wr0_row][wr0_col] <= 1'b1;
      end
      if (wr1_en) begin
        rob_q[wr1_row][wr1_col]   <= wr1_data;
        valid_q[wr1_row][wr1_col] <= 1'b1;
      end

      head_q        <= head_n;
      tail_q        <= tail_n;
      active_spec_q <= active_spec_n;
    end
  end

endmodule
