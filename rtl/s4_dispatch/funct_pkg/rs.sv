`timescale 1ns / 1ps

// Reservation-station package — geometry + pure helpers (no structs).
// Source readiness vs working destinations currently in the RS bank (not a
// free-running NUM_PRF scoreboard).
package rs_pkg;

import rv_dis_pkg::*;

  localparam int RS_WAYS   = 16;
  localparam int RS_WAY_AW = 4;
  localparam int RS_AGE_W  = 32;  // dispatch-order stamp (not PC)

  typedef logic [RS_WAY_AW-1:0] rs_way_t;
  typedef logic [RS_WAYS-1:0]   rs_mask_t;
  typedef logic [RS_AGE_W-1:0]  rs_age_t;

  // Opcode-class producer (ROB owns architectural reg_write / x0).
  function automatic logic rs_produces(
    input opcode_t   opcode,
    input funct3_t   funct3,
    input prf_addr_t prd
  );
    if (prd == '0)
      return 1'b0;
    unique case (opcode)
      OPC_OP, OPC_OP_IMM, OPC_JAL, OPC_JALR, OPC_LUI, OPC_AUIPC:
        return 1'b1;
      OPC_LOAD:
        return (funct3 == F3_LW);
      default:
        return 1'b0;
    endcase
  endfunction

  function automatic logic rs_wb_hit(
    input prf_addr_t tag,
    input logic      wb_en  [2],
    input prf_addr_t wb_prd [2]
  );
    return (wb_en[0] && (wb_prd[0] == tag)) ||
           (wb_en[1] && (wb_prd[1] == tag));
  endfunction

  // Tag is a working destination still sitting in the RS.
  function automatic logic rs_prd_in_bank(
    input prf_addr_t tag,
    input logic      bank_valid [RS_WAYS],
    input prf_addr_t bank_prd   [RS_WAYS]
  );
    if (tag == '0)
      return 1'b0;
    for (int i = 0; i < RS_WAYS; i++)
      if (bank_valid[i] && (bank_prd[i] == tag))
        return 1'b1;
    return 1'b0;
  endfunction

  function automatic logic rs_src_ready(
    input prf_addr_t tag,
    input logic      ready_bit,
    input logic      wb_en  [2],
    input prf_addr_t wb_prd [2]
  );
    return (tag == '0) || ready_bit || rs_wb_hit(tag, wb_en, wb_prd);
  endfunction

  function automatic logic rs_calc_issue_ready(
    input logic      valid,
    input prf_addr_t ps1,
    input prf_addr_t ps2,
    input logic      rs1_ready,
    input logic      rs2_ready,
    input logic      wb_en  [2],
    input prf_addr_t wb_prd [2]
  );
    return valid &&
           rs_src_ready(ps1, rs1_ready, wb_en, wb_prd) &&
           rs_src_ready(ps2, rs2_ready, wb_en, wb_prd);
  endfunction

  function automatic logic rs_disp_raw_rs1(
    input logic      v0,
    input opcode_t   op0,
    input funct3_t   f30,
    input prf_addr_t prd0,
    input prf_addr_t ps1_1
  );
    return v0 && rs_produces(op0, f30, prd0) && (ps1_1 == prd0);
  endfunction

  function automatic logic rs_disp_raw_rs2(
    input logic      v0,
    input opcode_t   op0,
    input funct3_t   f30,
    input prf_addr_t prd0,
    input prf_addr_t ps2_1
  );
    return v0 && rs_produces(op0, f30, prd0) && (ps2_1 == prd0);
  endfunction

  // Alloc-time source ready (WB or not still a live bank dest; RAW can force off).
  function automatic logic rs_alloc_src_rdy(
    input prf_addr_t tag,
    input logic      force_unready,
    input logic      bank_valid [RS_WAYS],
    input prf_addr_t bank_prd   [RS_WAYS],
    input logic      wb_en      [2],
    input prf_addr_t wb_prd     [2]
  );
    return (tag == '0) ||
           (!force_unready &&
            (rs_wb_hit(tag, wb_en, wb_prd) ||
             !rs_prd_in_bank(tag, bank_valid, bank_prd)));
  endfunction

  // Rename ready: sources ready unless a working RS dest still owns the tag.
  function automatic logic rs_disp_ready(
    input logic      valid,
    input prf_addr_t ps1,
    input prf_addr_t ps2,
    input logic      bank_valid [RS_WAYS],
    input prf_addr_t bank_prd   [RS_WAYS],
    input logic      wb_en      [2],
    input prf_addr_t wb_prd     [2],
    input logic      force_rs1_unready,
    input logic      force_rs2_unready
  );
    if (!valid)
      return 1'b0;
    return rs_alloc_src_rdy(ps1, force_rs1_unready, bank_valid, bank_prd,
                            wb_en, wb_prd) &&
           rs_alloc_src_rdy(ps2, force_rs2_unready, bank_valid, bank_prd,
                            wb_en, wb_prd);
  endfunction

  function automatic rs_way_t rs_pe_lo(input rs_mask_t m);
    rs_pe_lo = '0;
    for (int i = 0; i < RS_WAYS; i++)
      if (m[i])
        return rs_way_t'(i);
  endfunction

  function automatic rs_way_t rs_pe_lo2(input rs_mask_t m);
    rs_mask_t rest;
    rest      = m & ~(rs_mask_t'(1) << rs_pe_lo(m));
    rs_pe_lo2 = rs_pe_lo(rest);
  endfunction

  function automatic rs_way_t rs_pick_oldest(
    input rs_mask_t cand,
    input rs_age_t  ages [RS_WAYS]
  );
    logic    found;
    rs_age_t best_age;
    found          = 1'b0;
    best_age       = '1;
    rs_pick_oldest = '0;
    for (int i = 0; i < RS_WAYS; i++) begin
      if (cand[i] && (!found || (ages[i] < best_age))) begin
        found          = 1'b1;
        best_age       = ages[i];
        rs_pick_oldest = rs_way_t'(i);
      end
    end
  endfunction

  // Oldest among up to 4 candidates (selector pool).
  function automatic int rs_pick_oldest4(
    input logic [3:0] cand,
    input rs_age_t    ages [4]
  );
    logic    found;
    rs_age_t best;
    found            = 1'b0;
    best             = '1;
    rs_pick_oldest4  = 0;
    for (int i = 0; i < 4; i++) begin
      if (cand[i] && (!found || (ages[i] < best))) begin
        found           = 1'b1;
        best            = ages[i];
        rs_pick_oldest4 = i;
      end
    end
  endfunction

  // Next stamp after live bank ages (empty → 0).
  function automatic rs_age_t rs_next_age(
    input rs_mask_t valid,
    input rs_age_t  ages [RS_WAYS]
  );
    logic    found;
    rs_age_t best;
    found = 1'b0;
    best  = '0;
    for (int i = 0; i < RS_WAYS; i++) begin
      if (valid[i] && (!found || (ages[i] > best))) begin
        found = 1'b1;
        best  = ages[i];
      end
    end
    rs_next_age = found ? (best + rs_age_t'(1)) : rs_age_t'(0);
  endfunction

endpackage
