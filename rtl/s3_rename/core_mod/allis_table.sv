`timescale 1ns / 1ps

// Register Alias Table (RAT) + Retirement RAT (RRAT) + snapshot stack
//   rrat_q     — architected map (commit only)
//   map_br0_q  — speculative path 0 (RAT_path0)
//   map_br1_q  — speculative path 1 (RAT_path1)
//   snap_*_q   — full-column snapshots for nested branch recovery
//
// Checkpoint push : snapshot both columns before younger renames
// Path0 wins      : copy map_br0 → map_br1; pop snap
// Path1 wins      : copy map_br1 → map_br0; pop snap
// Mispredict      : restore both columns from snap[top]
// Flush           : maps ← RRAT; clear snap stack
import rv_dis_pkg::*;
import rat_pkg::*;

module allis_table (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  br_map_t     brch_map,

  input  logic        i0_rs1_use,
  input  logic        i0_rs2_use,
  input  logic        i1_rs1_use,
  input  logic        i1_rs2_use,
  input  gpr_addr_t   i0_rs1_addr,
  input  gpr_addr_t   i0_rs2_addr,
  input  gpr_addr_t   i1_rs1_addr,
  input  gpr_addr_t   i1_rs2_addr,
  output prf_addr_t   i0_ps1_tag,
  output prf_addr_t   i0_ps2_tag,
  output prf_addr_t   i1_ps1_tag,
  output prf_addr_t   i1_ps2_tag,

  input  logic        i0_reg_write,
  input  logic        i1_reg_write,
  input  gpr_addr_t   i0_rd_addr,
  input  gpr_addr_t   i1_rd_addr,
  input  prf_addr_t   i0_alloc_br0,
  input  prf_addr_t   i0_alloc_br1,
  input  prf_addr_t   i1_alloc_br0,
  input  prf_addr_t   i1_alloc_br1,
  output prf_addr_t   i0_old_tag,
  output prf_addr_t   i1_old_tag,

  input  logic        commit0_en,
  input  logic        commit1_en,
  input  gpr_addr_t   commit0_rd_addr,
  input  gpr_addr_t   commit1_rd_addr,
  input  prf_addr_t   commit0_prd,
  input  prf_addr_t   commit1_prd,

  input  logic        ckpt_push_en,
  output logic [2:0]  rat_ckpt_ptr_out,
  input  logic        resolve_en,
  input  logic        resolve_mispred,
  input  logic        resolve_win_path
);

  localparam int CKPT_N  = 8;
  localparam int CKPT_AW = $clog2(CKPT_N);

  prf_addr_t rrat_q    [NUM_GPR];
  prf_addr_t map_br0_q [NUM_GPR];
  prf_addr_t map_br1_q [NUM_GPR];

  prf_addr_t snap_br0_q [CKPT_N][NUM_GPR];
  prf_addr_t snap_br1_q [CKPT_N][NUM_GPR];
  logic [CKPT_AW:0] snap_wr_q;

  wire tip_is_i1 = rat_tip_is_i1(brch_map);
  wire use_br0   = rat_use_br0(brch_map);
  wire use_br1   = rat_use_br1(brch_map);

  wire i0_rd_legal = i0_reg_write && !arch_maps_to_x0(i0_rd_addr);
  wire i1_rd_legal = i1_reg_write && !arch_maps_to_x0(i1_rd_addr);

  wire prf_addr_t i0_alloc_tip = tip_is_i1 ? i0_alloc_br1 : i0_alloc_br0;
  wire prf_addr_t i1_alloc_tip = tip_is_i1 ? i1_alloc_br1 : i1_alloc_br0;

  assign i0_ps1_tag = rat_i0_src_lookup(
      i0_rs1_use, i0_rs1_addr, tip_is_i1, map_br0_q, map_br1_q);
  assign i0_ps2_tag = rat_i0_src_lookup(
      i0_rs2_use, i0_rs2_addr, tip_is_i1, map_br0_q, map_br1_q);
  assign i1_ps1_tag = rat_i1_src_lookup(
      i1_rs1_use, i1_rs1_addr, i0_rd_legal, i0_rd_addr, i0_alloc_tip,
      tip_is_i1, map_br0_q, map_br1_q);
  assign i1_ps2_tag = rat_i1_src_lookup(
      i1_rs2_use, i1_rs2_addr, i0_rd_legal, i0_rd_addr, i0_alloc_tip,
      tip_is_i1, map_br0_q, map_br1_q);

  assign i0_old_tag = arch_maps_to_x0(i0_rd_addr) ? '0
                    : rat_map_read(i0_rd_addr, tip_is_i1, map_br0_q, map_br1_q);
  assign i1_old_tag = arch_maps_to_x0(i1_rd_addr) ? '0
                    : (i0_rd_legal && (i1_rd_addr == i0_rd_addr)) ? i0_alloc_tip
                    : rat_map_read(i1_rd_addr, tip_is_i1, map_br0_q, map_br1_q);

  assign rat_ckpt_ptr_out = snap_wr_q[2:0];

  integer i, s;
  always_ff @(negedge clk or negedge rst_n) begin
    logic [CKPT_AW:0] snap_n;

    if (!rst_n) begin
      for (i = 0; i < NUM_GPR; i++) begin
        rrat_q[i]    <= prf_addr_t'(i);
        map_br0_q[i] <= prf_addr_t'(i);
        map_br1_q[i] <= prf_addr_t'(i);
      end
      rrat_q[0]    <= '0;
      map_br0_q[0] <= '0;
      map_br1_q[0] <= '0;
      snap_wr_q    <= '0;
      for (s = 0; s < CKPT_N; s++)
        for (i = 0; i < NUM_GPR; i++) begin
          snap_br0_q[s][i] <= prf_addr_t'(i);
          snap_br1_q[s][i] <= prf_addr_t'(i);
        end
    end else begin
      snap_n = snap_wr_q;

      if (flush) begin
        for (i = 0; i < NUM_GPR; i++) begin
          map_br0_q[i] <= rrat_q[i];
          map_br1_q[i] <= rrat_q[i];
        end
        snap_n = '0;
      end else begin
        rrat_q[0] <= '0;
        if (commit0_en && !arch_maps_to_x0(commit0_rd_addr))
          rrat_q[commit0_rd_addr] <= commit0_prd;
        if (commit1_en && !arch_maps_to_x0(commit1_rd_addr))
          rrat_q[commit1_rd_addr] <= commit1_prd;

        if (resolve_en && (snap_n != '0)) begin
          if (resolve_mispred) begin
            for (i = 0; i < NUM_GPR; i++) begin
              map_br0_q[i] <= snap_br0_q[snap_n[CKPT_AW-1:0] - CKPT_AW'(1)][i];
              map_br1_q[i] <= snap_br1_q[snap_n[CKPT_AW-1:0] - CKPT_AW'(1)][i];
            end
          end else if (resolve_win_path) begin
            for (i = 0; i < NUM_GPR; i++)
              map_br0_q[i] <= map_br1_q[i];
          end else begin
            for (i = 0; i < NUM_GPR; i++)
              map_br1_q[i] <= map_br0_q[i];
          end
          snap_n = snap_n - 1'b1;
        end

        if (ckpt_push_en && (snap_n < 4'(CKPT_N))) begin
          for (i = 0; i < NUM_GPR; i++) begin
            snap_br0_q[snap_n[CKPT_AW-1:0]][i] <= map_br0_q[i];
            snap_br1_q[snap_n[CKPT_AW-1:0]][i] <= map_br1_q[i];
          end
          snap_n = snap_n + 1'b1;
        end

        if (!(resolve_en && resolve_mispred)) begin
          map_br0_q[0] <= '0;
          map_br1_q[0] <= '0;
          if (use_br0) begin
            if (i0_rd_legal)
              map_br0_q[i0_rd_addr] <= i0_alloc_br0;
            if (i1_rd_legal)
              map_br0_q[i1_rd_addr] <= i1_alloc_br0;
          end
          if (use_br1) begin
            if (i0_rd_legal)
              map_br1_q[i0_rd_addr] <= i0_alloc_br1;
            if (i1_rd_legal)
              map_br1_q[i1_rd_addr] <= i1_alloc_br1;
          end
        end
      end

      snap_wr_q <= snap_n;
    end
  end

endmodule
