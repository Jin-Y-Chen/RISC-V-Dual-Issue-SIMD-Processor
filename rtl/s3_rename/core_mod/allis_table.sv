`timescale 1ns / 1ps

// Register Alias Table (RAT) + Retirement RAT (RRAT)
//   rrat_q     — architected map (commit)
//   map_br0_q  — path1 (specX_en=1)
//   map_br1_q  — path0 (specX_en=0)
//
// Dest tags are ROB-owned PRF p32..p63 (rob_to_prf). No free-list reclaim.
// RRAT ports: rrat*_en / i*_rd_addr_cmt / i*_rob_idx_cmt (PRF tag = head ROB idx)
// Path ports: rat*_en / i*_path_sel
// Flush restores both speculative maps from RRAT.
import rv_dis_pkg::*;
import rat_pkg::*;

module allis_table (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        spec0_en,
  input  logic        spec1_en,

  // source rename
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

  // dest rename (arch rd + ROB-derived ntag)
  input  logic        i0_alloc_en,
  input  logic        i1_alloc_en,
  input  gpr_addr_t   i0_alloc_rd_addr,
  input  gpr_addr_t   i1_alloc_rd_addr,
  input  prf_addr_t   i0_alloc_ntag,
  input  prf_addr_t   i1_alloc_ntag,

  // RRAT architectural commit from ROB
  input  logic        rrat0_en,
  input  logic        rrat1_en,
  input  gpr_addr_t   i0_rd_addr_cmt,
  input  gpr_addr_t   i1_rd_addr_cmt,
  input  prf_addr_t   i0_rob_idx_cmt,
  input  prf_addr_t   i1_rob_idx_cmt,

  // Committed branch path select; lane 1 is younger and has final priority.
  // path_sel: 0→path0/map_br1, 1→path1/map_br0
  input  logic        rat0_en,
  input  logic        rat1_en,
  input  logic        i0_path_sel,
  input  logic        i1_path_sel
);

  prf_addr_t rrat_q    [NUM_GPR];
  prf_addr_t map_br0_q [NUM_GPR];
  prf_addr_t map_br1_q [NUM_GPR];

  wire i0_rd_legal = i0_alloc_en && !arch_maps_to_x0(i0_alloc_rd_addr);
  wire i1_rd_legal = i1_alloc_en && !arch_maps_to_x0(i1_alloc_rd_addr);

  assign i0_ps1_tag = rat_src_lookup(
      i0_rs1_use, i0_rs1_addr, spec0_en, map_br0_q, map_br1_q);
  assign i0_ps2_tag = rat_src_lookup(
      i0_rs2_use, i0_rs2_addr, spec0_en, map_br0_q, map_br1_q);
  assign i1_ps1_tag = rat_i1_src_lookup(
      i1_rs1_use, i1_rs1_addr, i0_rd_legal, i0_alloc_rd_addr, i0_alloc_ntag,
      spec0_en, spec1_en, map_br0_q, map_br1_q);
  assign i1_ps2_tag = rat_i1_src_lookup(
      i1_rs2_use, i1_rs2_addr, i0_rd_legal, i0_alloc_rd_addr, i0_alloc_ntag,
      spec0_en, spec1_en, map_br0_q, map_br1_q);

  wire rrat0_wr = rrat0_en && !arch_maps_to_x0(i0_rd_addr_cmt);
  wire rrat1_wr = rrat1_en && !arch_maps_to_x0(i1_rd_addr_cmt);

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
      if (rat1_en) begin
        // If both branches resolve, the younger branch selects the final path.
        if (i1_path_sel == 1'b1)
          for (i = 0; i < NUM_GPR; i++) map_br1_q[i] <= map_br0_q[i];
        else
          for (i = 0; i < NUM_GPR; i++) map_br0_q[i] <= map_br1_q[i];
      end else if (rat0_en) begin
        if (i0_path_sel == 1'b1)
          for (i = 0; i < NUM_GPR; i++) map_br1_q[i] <= map_br0_q[i];
        else
          for (i = 0; i < NUM_GPR; i++) map_br0_q[i] <= map_br1_q[i];
      end

      // Commit the exact ROB tag; do not overwrite younger speculative maps.
      if (rrat0_wr) begin
        rrat_q[i0_rd_addr_cmt] <= i0_rob_idx_cmt;
      end
      if (rrat1_wr) begin
        rrat_q[i1_rd_addr_cmt] <= i1_rob_idx_cmt;
      end

      if (i0_rd_legal)
        if (spec0_en) map_br0_q[i0_alloc_rd_addr] <= i0_alloc_ntag;
        else          map_br1_q[i0_alloc_rd_addr] <= i0_alloc_ntag;
      if (i1_rd_legal)
        if (spec1_en) map_br0_q[i1_alloc_rd_addr] <= i1_alloc_ntag;
        else          map_br1_q[i1_alloc_rd_addr] <= i1_alloc_ntag;
    end
  end

endmodule
