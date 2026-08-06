`timescale 1ns / 1ps

// Reservation-station package — geometry + pure helpers (no structs).
// Covers bank wakeup, readiness, alloc RAW, and selector age/pick helpers.
package rs_pkg;

import rv_dis_pkg::*;

  localparam int RS_WAYS   = 16;
  localparam int RS_WAY_AW = 4;
  localparam int RS_AGE_W  = 32;  // dispatch-order stamp (not PC)

  // 4-candidate pool indices: RS0, RS1, rename0, rename1
  localparam int C_RS0 = 0;
  localparam int C_RS1 = 1;
  localparam int C_BY0 = 2;
  localparam int C_BY1 = 3;

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

  // Same-cycle wakeup OR onto a registered ready bit.
  function automatic logic rs_wake_bit(
    input logic      valid,
    input logic      rdy_q,
    input prf_addr_t ps,
    input logic      wb_en  [2],
    input prf_addr_t wb_prd [2]
  );
    return rdy_q || (valid && rs_wb_hit(ps, wb_en, wb_prd));
  endfunction

  function automatic logic rs_path_ok(
    input logic path_en,
    input logic path_use,
    input logic path_sel
  );
    return !path_en || (path_use == path_sel);
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
    found           = 1'b0;
    best            = '1;
    rs_pick_oldest4 = 0;
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

  // Free ways after same-cycle WB kills on the path-masked bank.
  function automatic int rs_free_ways(
    input rs_mask_t  bank_valid_m,
    input prf_addr_t bank_prd [RS_WAYS],
    input logic      wb_en    [2],
    input prf_addr_t wb_prd   [2]
  );
    int u, n_wb;
    u = 0; n_wb = 0;
    for (int i = 0; i < RS_WAYS; i++) begin
      u += bank_valid_m[i];
      if (bank_valid_m[i] && rs_wb_hit(bank_prd[i], wb_en, wb_prd))
        n_wb++;
    end
    return RS_WAYS - u + n_wb;
  endfunction

  // Kill way on WB complete, wrong-path squash, or issued clear (src_en && !store_en).
  function automatic logic rs_way_kill(
    input int        way,
    input logic      enable,
    input logic      path_en,
    input logic      path_sel,
    input logic      bank_valid,
    input logic      bank_spec,
    input prf_addr_t bank_prd,
    input logic      wb_en    [2],
    input prf_addr_t wb_prd   [2],
    input logic      src_en   [2],
    input logic      store_en [2],
    input rs_way_t   rs_tag   [2]
  );
    logic clr;
    clr = 1'b0;
    if (enable)
      for (int ch = 0; ch < 2; ch++)
        if (src_en[ch] && !store_en[ch] && (rs_tag[ch] == rs_way_t'(way)))
          clr = 1'b1;
    return (bank_valid && rs_wb_hit(bank_prd, wb_en, wb_prd)) ||
           (path_en && bank_valid && (bank_spec != path_sel)) ||
           clr;
  endfunction

endpackage
