`timescale 1ns / 1ps

// Register Alias Table (RAT):
//   map_arch_q — architected (ROB commit, rising edge)
//   map_br0_q  — speculative / fallthrough column for br_map[0]
//   map_br1_q  — speculative / fallthrough column for br_map[1]
// br_map modes:
//   00 — 1-col rename tip (map_br1; map_br0 kept in sync)
//   01 — 2-col: tip=br0 (spec), br1 fallthrough
//   10 — 2-col: tip=br1 (spec), br0 fallthrough
//   11 — 2-col: both speculative (tip=br1 for ordered dual rename)
import rv_dis_pkg::*;
import rat_pkg::*;

module allis_table (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  br_map_t     br_map,

  // source rename reads (arch → phys) — combinational
  input  logic        i0_rs1_use,
  input  logic        i0_rs2_use,
  input  logic        i1_rs1_use,
  input  logic        i1_rs2_use,
  input  arch_addr_t  i0_rs1_addr,
  input  arch_addr_t  i0_rs2_addr,
  input  arch_addr_t  i1_rs1_addr,
  input  arch_addr_t  i1_rs2_addr,
  output prf_addr_t   i0_ps1_tag,
  output prf_addr_t   i0_ps2_tag,
  output prf_addr_t   i1_ps1_tag,
  output prf_addr_t   i1_ps2_tag,

  // destination rename (Free List → RAT → ROB) — combinational
  input  logic        i0_rd_wen,
  input  logic        i1_rd_wen,
  input  arch_addr_t  i0_rd_addr,
  input  arch_addr_t  i1_rd_addr,
  input  prf_addr_t   i0_prd_new_tag,
  input  prf_addr_t   i1_prd_new_tag,
  output prf_addr_t   i0_prd_old_tag,
  output prf_addr_t   i1_prd_old_tag,

  // commit — ROB sends (rd, prd)
  input  logic        commit0_en,
  input  logic        commit1_en,
  input  arch_addr_t  commit0_rd_addr,
  input  arch_addr_t  commit1_rd_addr,
  input  prf_addr_t   commit0_prd,
  input  prf_addr_t   commit1_prd
);

  prf_addr_t map_arch_q [NUM_GPR];
  prf_addr_t map_br0_q  [NUM_GPR];
  prf_addr_t map_br1_q  [NUM_GPR];

  wire tip_is_i1 = rat_tip_is_i1(br_map);
  wire use_br0   = rat_use_br0(br_map);
  wire use_br1   = rat_use_br1(br_map);

  wire i0_rd_legal = i0_rd_wen && !arch_maps_to_x0(i0_rd_addr);
  wire i1_rd_legal = i1_rd_wen && !arch_maps_to_x0(i1_rd_addr);

  assign i0_ps1_tag = rat_i0_src_lookup(
      i0_rs1_use, i0_rs1_addr, tip_is_i1, map_br0_q, map_br1_q);
  assign i0_ps2_tag = rat_i0_src_lookup(
      i0_rs2_use, i0_rs2_addr, tip_is_i1, map_br0_q, map_br1_q);
  assign i1_ps1_tag = rat_i1_src_lookup(
      i1_rs1_use, i1_rs1_addr, i0_rd_legal, i0_rd_addr, i0_prd_new_tag,
      tip_is_i1, map_br0_q, map_br1_q);
  assign i1_ps2_tag = rat_i1_src_lookup(
      i1_rs2_use, i1_rs2_addr, i0_rd_legal, i0_rd_addr, i0_prd_new_tag,
      tip_is_i1, map_br0_q, map_br1_q);

  assign i0_prd_old_tag = arch_maps_to_x0(i0_rd_addr) ? '0
                        : rat_map_read(i0_rd_addr, tip_is_i1, map_br0_q, map_br1_q);
  assign i1_prd_old_tag = arch_maps_to_x0(i1_rd_addr) ? '0
                        : (i0_rd_legal && (i1_rd_addr == i0_rd_addr)) ? i0_prd_new_tag
                        : rat_map_read(i1_rd_addr, tip_is_i1, map_br0_q, map_br1_q);

  integer si;
  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (si = 0; si < NUM_GPR; si++) begin
        map_br0_q[si] <= prf_addr_t'(si);
        map_br1_q[si] <= prf_addr_t'(si);
      end
      map_br0_q[0] <= '0;
      map_br1_q[0] <= '0;
    end else if (flush) begin
      for (si = 0; si < NUM_GPR; si++) begin
        map_br0_q[si] <= map_arch_q[si];
        map_br1_q[si] <= map_arch_q[si];
      end
    end else begin
      map_br0_q[0] <= '0;
      map_br1_q[0] <= '0;
      if (use_br0) begin
        if (i0_rd_legal)
          map_br0_q[rat_slot(i0_rd_addr)] <= i0_prd_new_tag;
        if (i1_rd_legal)
          map_br0_q[rat_slot(i1_rd_addr)] <= i1_prd_new_tag;
      end
      if (use_br1) begin
        if (i0_rd_legal)
          map_br1_q[rat_slot(i0_rd_addr)] <= i0_prd_new_tag;
        if (i1_rd_legal)
          map_br1_q[rat_slot(i1_rd_addr)] <= i1_prd_new_tag;
      end
    end
  end

  integer ai;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (ai = 0; ai < NUM_GPR; ai++)
        map_arch_q[ai] <= prf_addr_t'(ai);
      map_arch_q[0] <= '0;
    end else begin
      map_arch_q[0] <= '0;
      if (commit0_en && !arch_maps_to_x0(commit0_rd_addr))
        map_arch_q[rat_slot(commit0_rd_addr)] <= commit0_prd;
      if (commit1_en && !arch_maps_to_x0(commit1_rd_addr))
        map_arch_q[rat_slot(commit1_rd_addr)] <= commit1_prd;
    end
  end

endmodule
