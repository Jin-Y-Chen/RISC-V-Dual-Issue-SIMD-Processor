`timescale 1ns / 1ps

// RS issue — 16-way mask + oldest-priority dual select (no scan loops).
import rv_dis_pkg::*;
import rs_pkg::*;

module rs_issue (
  input  logic        enable,
  input  logic        flush,

  input  rs_entry_t   bank_q [RS_SETS][RS_WAYS],
  input  logic        wb0_en,
  input  prf_addr_t   wb0_prd,
  input  logic        wb1_en,
  input  prf_addr_t   wb1_prd,

  input  logic        i0_valid_dp,
  input  logic        i1_valid_dp,
  input  logic        issue_en,

  output rs_way_t     sel0,
  output rs_way_t     sel1,
  output logic        sel0_v,
  output logic        sel1_v,
  output logic        issue0_fire,
  output logic        issue1_fire,
  output logic        stall_dp,

  output logic        i0_rs1_use_prf,
  output logic        i0_rs2_use_prf,
  output prf_addr_t   i0_ps1_prf,
  output prf_addr_t   i0_ps2_prf,
  output logic        i1_rs1_use_prf,
  output logic        i1_rs2_use_prf,
  output prf_addr_t   i1_ps1_prf,
  output prf_addr_t   i1_ps2_prf,

  output logic        i0_valid_iss,
  output logic        i0_lane_sel_iss,
  output logic        i0_reg_write_iss,
  output opcode_t     i0_opcode_iss,
  output funct3_t     i0_funct3_iss,
  output funct7_t     i0_funct7_iss,
  output prf_addr_t   i0_ps1_iss,
  output prf_addr_t   i0_ps2_iss,
  output prf_addr_t   i0_prd_iss,
  output word_t       i0_imm_iss,
  output word_t       i0_pc_iss,

  output logic        i1_valid_iss,
  output logic        i1_lane_sel_iss,
  output logic        i1_reg_write_iss,
  output opcode_t     i1_opcode_iss,
  output funct3_t     i1_funct3_iss,
  output funct7_t     i1_funct7_iss,
  output prf_addr_t   i1_ps1_iss,
  output prf_addr_t   i1_ps2_iss,
  output prf_addr_t   i1_prd_iss,
  output word_t       i1_imm_iss,
  output word_t       i1_pc_iss
);

  rs_mask_t        ready_m;
  logic [31:0]     ages [RS_WAYS];
  rs_mask_t        valid_m;
  rs_entry_t       e0, e1;

  // Per-way ready / age / valid — parallel way slice (SETS=1).
  genvar w;
  generate
    for (w = 0; w < RS_WAYS; w++) begin : g_way
      assign ready_m[w] = rs_calc_issue_ready(
        bank_q[0][w], wb0_en, wb0_prd, wb1_en, wb1_prd);
      assign ages[w]    = bank_q[0][w].age;
      assign valid_m[w] = bank_q[0][w].valid;
    end
  endgenerate

  // Dual oldest-ready pick from ready mask.
  always_comb begin
    sel0   = '0;
    sel1   = '0;
    sel0_v = 1'b0;
    sel1_v = 1'b0;
    if (enable && !flush && (|ready_m)) begin
      sel0   = rs_pick_oldest(ready_m, ages);
      sel0_v = 1'b1;
      if (|(ready_m & ~rs_way_oh(sel0))) begin
        sel1   = rs_pick_oldest(ready_m & ~rs_way_oh(sel0), ages);
        sel1_v = 1'b1;
      end
    end
  end

  assign e0 = bank_q[0][sel0];
  assign e1 = bank_q[0][sel1];

  always_comb begin
    i0_valid_iss     = sel0_v;
    i0_lane_sel_iss  = e0.lane_sel;
    i0_reg_write_iss = e0.reg_write;
    i0_opcode_iss    = e0.opcode;
    i0_funct3_iss    = e0.funct3;
    i0_funct7_iss    = e0.funct7;
    i0_ps1_iss       = e0.ps1;
    i0_ps2_iss       = e0.ps2;
    i0_prd_iss       = e0.prd;
    i0_imm_iss       = e0.imm;
    i0_pc_iss        = e0.pc;
    i0_ps1_prf       = e0.ps1;
    i0_ps2_prf       = e0.ps2;
    i0_rs1_use_prf   = sel0_v && (e0.ps1 != '0);
    i0_rs2_use_prf   = sel0_v && (e0.ps2 != '0);

    i1_valid_iss     = sel1_v;
    i1_lane_sel_iss  = e1.lane_sel;
    i1_reg_write_iss = e1.reg_write;
    i1_opcode_iss    = e1.opcode;
    i1_funct3_iss    = e1.funct3;
    i1_funct7_iss    = e1.funct7;
    i1_ps1_iss       = e1.ps1;
    i1_ps2_iss       = e1.ps2;
    i1_prd_iss       = e1.prd;
    i1_imm_iss       = e1.imm;
    i1_pc_iss        = e1.pc;
    i1_ps1_prf       = e1.ps1;
    i1_ps2_prf       = e1.ps2;
    i1_rs1_use_prf   = sel1_v && (e1.ps1 != '0);
    i1_rs2_use_prf   = sel1_v && (e1.ps2 != '0);
  end

  assign issue0_fire = sel0_v && issue_en;
  assign issue1_fire = sel1_v && issue_en;

  always_comb begin
    int used, available, incoming;
    used = 0;
    for (int i = 0; i < RS_WAYS; i++)
      used += valid_m[i];
    incoming  = i0_valid_dp + i1_valid_dp;
    available = RS_WAYS - used + issue0_fire + issue1_fire;
    stall_dp  = !flush && (incoming > available);
  end

endmodule
