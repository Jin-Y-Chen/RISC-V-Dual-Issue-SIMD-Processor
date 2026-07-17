`timescale 1ns / 1ps

// Register Alias Table (RAT) + Retirement RAT (RRAT)
//   rrat_q     — architected map (commit)
//   map_br0_q  — speculative path 0
//   map_br1_q  — speculative path 1
//
// Rename writes active speculative column(s) per brch_map.
// Commit updates RRAT and both speculative maps (ROB owns path reclaim).
// Flush restores both speculative maps from RRAT.
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
  input  prf_addr_t   i0_alloc_tag,
  input  prf_addr_t   i1_alloc_tag,
  output prf_addr_t   i0_old_tag,
  output prf_addr_t   i1_old_tag,

  input  logic        i0_en,
  input  logic        i1_en,
  input  gpr_addr_t   i0_commit_rd_addr,
  input  gpr_addr_t   i1_commit_rd_addr,
  input  prf_addr_t   i0_commit_prd_tag,
  input  prf_addr_t   i1_commit_prd_tag,

  // branch resolve from ROB (negedge): resolve_en gates rat_path
  input  logic        resolve_en,  // 1 when a branch commits at ROB head
  input  logic        rat_path     // 0=path0/map_br0 wins, 1=path1/map_br1 wins
);

  prf_addr_t rrat_q    [NUM_GPR];
  prf_addr_t map_br0_q [NUM_GPR];
  prf_addr_t map_br1_q [NUM_GPR];

  wire tip_is_i1 = rat_tip_is_i1(brch_map);
  wire use_br0   = rat_use_br0(brch_map);
  wire use_br1   = rat_use_br1(brch_map);

  wire i0_rd_legal = i0_reg_write && !arch_maps_to_x0(i0_rd_addr);
  wire i1_rd_legal = i1_reg_write && !arch_maps_to_x0(i1_rd_addr);

  assign i0_ps1_tag = rat_i0_src_lookup(
      i0_rs1_use, i0_rs1_addr, tip_is_i1, map_br0_q, map_br1_q);
  assign i0_ps2_tag = rat_i0_src_lookup(
      i0_rs2_use, i0_rs2_addr, tip_is_i1, map_br0_q, map_br1_q);
  assign i1_ps1_tag = rat_i1_src_lookup(
      i1_rs1_use, i1_rs1_addr, i0_rd_legal, i0_rd_addr, i0_alloc_tag,
      tip_is_i1, map_br0_q, map_br1_q);
  assign i1_ps2_tag = rat_i1_src_lookup(
      i1_rs2_use, i1_rs2_addr, i0_rd_legal, i0_rd_addr, i0_alloc_tag,
      tip_is_i1, map_br0_q, map_br1_q);

  assign i0_old_tag = arch_maps_to_x0(i0_rd_addr) ? '0
                    : rat_map_read(i0_rd_addr, tip_is_i1, map_br0_q, map_br1_q);
  assign i1_old_tag = arch_maps_to_x0(i1_rd_addr) ? '0
                    : (i0_rd_legal && (i1_rd_addr == i0_rd_addr)) ? i0_alloc_tag
                    : rat_map_read(i1_rd_addr, tip_is_i1, map_br0_q, map_br1_q);

  wire cmt0_wr = i0_en && !arch_maps_to_x0(i0_commit_rd_addr);
  wire cmt1_wr = i1_en && !arch_maps_to_x0(i1_commit_rd_addr);

  integer i;
  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < NUM_GPR; i++) begin
        rrat_q[i]    <= prf_addr_t'(i);
        map_br0_q[i] <= prf_addr_t'(i);
        map_br1_q[i] <= prf_addr_t'(i);
      end
      rrat_q[0]    <= '0;
      map_br0_q[0] <= '0;
      map_br1_q[0] <= '0;
    end else if (flush) begin
      for (i = 0; i < NUM_GPR; i++) begin
        map_br0_q[i] <= rrat_q[i];
        map_br1_q[i] <= rrat_q[i];
      end
    end else begin
      // Branch resolve: copy winning column to loser when a branch commits.
      if (resolve_en) begin
        if (rat_path == 1'b0)
          for (i = 0; i < NUM_GPR; i++) map_br1_q[i] <= map_br0_q[i];
        else
          for (i = 0; i < NUM_GPR; i++) map_br0_q[i] <= map_br1_q[i];
      end

      // Reg commit (RRAT + both maps), then rename so younger map wins.
      if (cmt0_wr) begin
        rrat_q[i0_commit_rd_addr]    <= i0_commit_prd_tag;
        map_br0_q[i0_commit_rd_addr] <= i0_commit_prd_tag;
        map_br1_q[i0_commit_rd_addr] <= i0_commit_prd_tag;
      end
      if (cmt1_wr) begin
        rrat_q[i1_commit_rd_addr]    <= i1_commit_prd_tag;
        map_br0_q[i1_commit_rd_addr] <= i1_commit_prd_tag;
        map_br1_q[i1_commit_rd_addr] <= i1_commit_prd_tag;
      end

      if (use_br0) begin
        if (i0_rd_legal) map_br0_q[i0_rd_addr] <= i0_alloc_tag;
        if (i1_rd_legal) map_br0_q[i1_rd_addr] <= i1_alloc_tag;
      end
      if (use_br1) begin
        if (i0_rd_legal) map_br1_q[i0_rd_addr] <= i0_alloc_tag;
        if (i1_rd_legal) map_br1_q[i1_rd_addr] <= i1_alloc_tag;
      end
    end
  end

endmodule
