`timescale 1ns / 1ps

// ROB top — one shared bank; independent head (retire) and tail (alloc).
//
//   rob_alloc  — combo wr_* / tail_n / indices (no bank port)
//   rob_retire — combo from registered head scalars (no WB bypass)
//
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
// Timing: Execute → WB (negedge complete) → Retire (next cycle).
// Negedge order: WB → commit clear → alloc → pointer latch.
import rv_dis_pkg::*;
import rob_pkg::*;

module reorder_buffer (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  input  logic        alloc_en      [2],
  input  logic        reg_write     [2],
  input  logic        is_brnch      [2],
  input  logic        is_store      [2],
  input  logic        spec_en       [2],
  input  logic        state_valid   [2],
  input  br_state_t   brch_state    [2],
  input  gpr_addr_t   rd_addr       [2],
  output prf_addr_t   rob_idx       [2],
  output logic        idx_valid     [2],
  output logic        stall,

  input  logic        wback_en      [2],
  input  prf_addr_t   rob_idx_wb    [2],
  input  logic        brch_taken_wb [2],

  input  logic        retire_en     [2],

  output logic        rrat_en       [2],
  output gpr_addr_t   rd_addr_cmt   [2],
  output prf_addr_t   rob_idx_cmt   [2],

  output logic        rat_en        [2],
  output logic        path_sel      [2],

  output logic        stb_en        [2]
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

  logic         wr_en   [2];
  rob_set_t     wr_row  [2];
  rob_way_t     wr_col  [2];
  rob_payload_t wr_data [2];

  logic         cmt     [2];
  rob_set_t     clr_row [2];
  rob_way_t     clr_col [2];

  rob_flat_t    h       [2];
  logic         v       [2];
  rob_payload_t p       [2];

  rob_alloc u_alloc (
    .tail_q,
    .alloc_en,
    .reg_write,
    .is_brnch,
    .is_store,
    .spec_en,
    .state_valid,
    .brch_state,
    .rd_addr,
    .rob_idx,
    .idx_valid,
    .tail_n,
    .wr_en,
    .wr_row,
    .wr_col,
    .wr_data
  );

  // Head probe from registered bank only (no same-cycle WB bypass)
  assign h[0] = head_q[ROB_INDEX_W-1:0];
  assign h[1] = rob_flat_t'(h[0] + 1'b1);
  assign v[0] = valid_q[rob_row(h[0])][rob_col(h[0])];
  assign v[1] = valid_q[rob_row(h[1])][rob_col(h[1])];
  assign p[0] = v[0] ? rob_q[rob_row(h[0])][rob_col(h[0])] : '0;
  assign p[1] = v[1] ? rob_q[rob_row(h[1])][rob_col(h[1])] : '0;

  rob_retire u_retire (
    .head_q,
    .active_spec_q,
    .valid        (v),
    .payload      (p),
    .retire_en,
    .rrat_en,
    .rd_addr_cmt,
    .rob_idx_cmt,
    .rat_en,
    .path_sel,
    .stb_en,
    .head_n,
    .active_spec_n,
    .cmt,
    .clr_row,
    .clr_col
  );

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      head_q        <= '0;
      tail_q        <= '0;
      valid_q       <= '0;
      active_spec_q <= 1'b0;
    end else begin
      for (int i = 0; i < 2; i++) begin
        automatic rob_set_t wb_r = rob_set(rob_idx_wb[i]);
        automatic rob_way_t wb_c = rob_way(rob_idx_wb[i]);
        if (wback_en[i] && valid_q[wb_r][wb_c])
          rob_q[wb_r][wb_c] <= rob_wback(rob_q[wb_r][wb_c], brch_taken_wb[i]);
      end

      for (int i = 0; i < 2; i++) begin
        if (cmt[i])
          valid_q[clr_row[i]][clr_col[i]] <= 1'b0;
      end

      for (int i = 0; i < 2; i++) begin
        if (wr_en[i]) begin
          rob_q[wr_row[i]][wr_col[i]]   <= wr_data[i];
          valid_q[wr_row[i]][wr_col[i]] <= 1'b1;
        end
      end

      head_q        <= head_n;
      tail_q        <= tail_n;
      active_spec_q <= active_spec_n;
    end
  end

endmodule
