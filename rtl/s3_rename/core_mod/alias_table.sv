`timescale 1ns / 1ps

// Register Alias Table (RAT) + Retirement RAT (RRAT)
//   rrat_q     — architected map (commit)
//   map_br0_q  — path1 (spec_en=1)
//   map_br1_q  — path0 (spec_en=0)
//
// Dest tags are ROB-owned PRF p32..p63 (rob_to_prf). No free-list reclaim.
// RRAT ports: rrat_en / rd_addr_cmt / rob_tag_cmt (PRF tag = head ROB idx)
// Path ports: rat_en / path_sel
// Flush restores both speculative maps from RRAT.
import rv_dis_pkg::*;
import rat_pkg::*;

module allis_table (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        spec_en       [2],

  // source rename
  input  logic        rs1_use       [2],
  input  logic        rs2_use       [2],
  input  gpr_addr_t   rs1_addr      [2],
  input  gpr_addr_t   rs2_addr      [2],
  output logic        path_use      [2],
  output prf_addr_t   ps1_tag       [2],
  output prf_addr_t   ps2_tag       [2],

  // dest rename (arch rd + ROB-derived ntag)
  input  logic        alloc_en      [2],
  input  gpr_addr_t   alloc_rd_addr [2],
  input  prf_addr_t   alloc_rob_tag [2],

  // RRAT architectural commit from ROB
  input  logic        rrat_en       [2],
  input  gpr_addr_t   rd_addr_cmt   [2],
  input  prf_addr_t   rob_tag_cmt   [2],

  // Committed branch path select; lane 1 is younger and has final priority.
  // path_sel: 0→path0/map_br1, 1→path1/map_br0
  input  logic        rat_en        [2],
  input  logic        path_sel      [2]
);

  prf_addr_t rrat_q    [NUM_GPR];
  prf_addr_t map_br0_q [NUM_GPR];
  prf_addr_t map_br1_q [NUM_GPR];

  wire alloc_legal [2];
  wire rrat_legal  [2];

  assign path_use[0] = spec_en[0];
  assign path_use[1] = spec_en[1];

  assign alloc_legal[0] = alloc_en[0] && !arch_maps_to_x0(alloc_rd_addr[0]);
  assign alloc_legal[1] = alloc_en[1] && !arch_maps_to_x0(alloc_rd_addr[1]);

  assign ps1_tag[0] = rat_src_lookup(
      rs1_use[0], rs1_addr[0], spec_en[0], map_br0_q, map_br1_q);
  assign ps2_tag[0] = rat_src_lookup(
      rs2_use[0], rs2_addr[0], spec_en[0], map_br0_q, map_br1_q);
  assign ps1_tag[1] = rat_i1_src_lookup(
      rs1_use[1], rs1_addr[1],
      alloc_en[0], alloc_rd_addr[0], alloc_rob_tag[0],
      spec_en[0], spec_en[1], map_br0_q, map_br1_q);
  assign ps2_tag[1] = rat_i1_src_lookup(
      rs2_use[1], rs2_addr[1],
      alloc_en[0], alloc_rd_addr[0], alloc_rob_tag[0],
      spec_en[0], spec_en[1], map_br0_q, map_br1_q);

  assign rrat_legal[0] = rrat_en[0] && !arch_maps_to_x0(rd_addr_cmt[0]);
  assign rrat_legal[1] = rrat_en[1] && !arch_maps_to_x0(rd_addr_cmt[1]);

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
      if (rat_en[1]) begin
        // If both branches resolve, the younger branch selects the final path.
        if (path_sel[1] == 1'b1)
          for (i = 0; i < NUM_GPR; i++) map_br1_q[i] <= map_br0_q[i];
        else
          for (i = 0; i < NUM_GPR; i++) map_br0_q[i] <= map_br1_q[i];
      end else if (rat_en[0]) begin
        if (path_sel[0] == 1'b1)
          for (i = 0; i < NUM_GPR; i++) map_br1_q[i] <= map_br0_q[i];
        else
          for (i = 0; i < NUM_GPR; i++) map_br0_q[i] <= map_br1_q[i];
      end

      // Commit the exact ROB tag; do not overwrite younger speculative maps.
      if (rrat_legal[0])
        rrat_q[rd_addr_cmt[0]] <= rob_tag_cmt[0];
      if (rrat_legal[1])
        rrat_q[rd_addr_cmt[1]] <= rob_tag_cmt[1];

      if (alloc_legal[0])
        if (spec_en[0]) map_br0_q[alloc_rd_addr[0]] <= alloc_rob_tag[0];
        else            map_br1_q[alloc_rd_addr[0]] <= alloc_rob_tag[0];
      if (alloc_legal[1])
        if (spec_en[1]) map_br0_q[alloc_rd_addr[1]] <= alloc_rob_tag[1];
        else            map_br1_q[alloc_rd_addr[1]] <= alloc_rob_tag[1];
    end
  end

endmodule
