`timescale 1ns / 1ps

// Register Alias Table (RAT) + Retirement RAT (RRAT):
//   rrat_q    — retirement / architected map (ROB commit only)
//   map_br0_q — speculative RAT column for brch_map[0]
//   map_br1_q — speculative RAT column for brch_map[1]
// brch_map modes:
//   00 — 1-col tip (map_br1; map_br0 kept in sync)
//   01 — 2-col: tip=br0 (spec), br1 fallthrough
//   10 — 2-col: tip=br1 (spec), br0 fallthrough
//   11 — 2-col: both speculative (tip=br1 for ordered dual rename)
// Rename reads/writes speculative RATs only. Commit updates RRAT only.
// Flush restores speculative RATs from RRAT.
// Falling edge: commit → RRAT first, then rename writes tip RATs.
// Free-list allocate is driven by reg_write from the parent (not from this module).
import rv_dis_pkg::*;
import rat_pkg::*;

module allis_table (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  br_map_t     brch_map,

  // source rename reads (speculative RAT only) — combinational
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

  // Destination rename — per-path Free List tags (br0 / br1)
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

  // commit — ROB updates RRAT only (rd, prd)
  input  logic        commit0_en,
  input  logic        commit1_en,
  input  gpr_addr_t   commit0_rd_addr,
  input  gpr_addr_t   commit1_rd_addr,
  input  prf_addr_t   commit0_prd,
  input  prf_addr_t   commit1_prd
);

  prf_addr_t rrat_q    [NUM_GPR];
  prf_addr_t map_br0_q [NUM_GPR];
  prf_addr_t map_br1_q [NUM_GPR];

  wire tip_is_i1 = rat_tip_is_i1(brch_map);
  wire use_br0   = rat_use_br0(brch_map);
  wire use_br1   = rat_use_br1(brch_map);

  // Destination map write / I1 same-rd bypass (BRANCH/STORE have reg_write=0).
  wire i0_rd_legal = i0_reg_write && !arch_maps_to_x0(i0_rd_addr);
  wire i1_rd_legal = i1_reg_write && !arch_maps_to_x0(i1_rd_addr);

  // Rename reads speculative RATs only.
  // Tip tag for I1 same-rd bypass / old-tag path (matches rename tip column).
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
      // Restore speculative RATs from RRAT.
      for (i = 0; i < NUM_GPR; i++) begin
        map_br0_q[i] <= rrat_q[i];
        map_br1_q[i] <= rrat_q[i];
      end
    end else begin
      // 1) Commit → RRAT only
      rrat_q[0] <= '0;
      if (commit0_en && !arch_maps_to_x0(commit0_rd_addr))
        rrat_q[commit0_rd_addr] <= commit0_prd;
      if (commit1_en && !arch_maps_to_x0(commit1_rd_addr))
        rrat_q[commit1_rd_addr] <= commit1_prd;

      // 2) Rename → speculative tip RATs only
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

endmodule
