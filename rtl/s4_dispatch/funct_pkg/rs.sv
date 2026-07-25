`timescale 1ns / 1ps

// Reservation-station helpers — 1-set × WAYS bank (fully associative).
// Select / free use ready/free masks + priority encode (no scan loops).
// Unused sources are p0 (always ready). spec_en: 0=path0, 1=path1.
package rs_pkg;

import rv_dis_pkg::*;

  // Geometry: one set of 16 ways (cache-style bank[SETS][WAYS]).
  localparam int RS_WAYS   = 16;
  localparam int RS_WAY_AW = 4;
  localparam int RS_SETS   = 1;
  localparam int RS_SET_AW = 0;
  localparam int RS_DEPTH  = RS_SETS * RS_WAYS;  // 16

  typedef logic [RS_WAY_AW-1:0] rs_way_t;
  typedef logic [RS_WAYS-1:0]   rs_mask_t;

  typedef struct packed {
    logic        valid;
    logic [31:0] age;
    logic        lane_sel;
    logic        reg_write;
    logic        spec_en;      // 0=path0, 1=path1
    logic        rs1_ready;
    logic        rs2_ready;
    logic        issue_ready;  // entry eligible to issue
    opcode_t     opcode;
    funct3_t     funct3;
    funct7_t     funct7;
    prf_addr_t   ps1;
    prf_addr_t   ps2;
    prf_addr_t   prd;          // ROB-owned dest tag (== ROB index)
    word_t       imm;
    word_t       pc;
  } rs_entry_t;

  function automatic logic rs_wb_hit(
    input prf_addr_t tag,
    input logic      wb0_en,
    input prf_addr_t wb0_prd,
    input logic      wb1_en,
    input prf_addr_t wb1_prd
  );
    return (wb0_en && (wb0_prd == tag)) ||
           (wb1_en && (wb1_prd == tag));
  endfunction

  function automatic logic rs_src_ready(
    input prf_addr_t tag,
    input logic      ready_bit,
    input logic      wb0_en,
    input prf_addr_t wb0_prd,
    input logic      wb1_en,
    input prf_addr_t wb1_prd
  );
    return (tag == '0) || ready_bit ||
           rs_wb_hit(tag, wb0_en, wb0_prd, wb1_en, wb1_prd);
  endfunction

  function automatic logic rs_calc_issue_ready(
    input rs_entry_t entry,
    input logic      wb0_en,
    input prf_addr_t wb0_prd,
    input logic      wb1_en,
    input prf_addr_t wb1_prd,
    input logic      wbrack
  );
    return entry.valid &&
           (!wbrack || !entry.spec_en) &&
           rs_src_ready(entry.ps1, entry.rs1_ready,
                        wb0_en, wb0_prd, wb1_en, wb1_prd) &&
           rs_src_ready(entry.ps2, entry.rs2_ready,
                        wb0_en, wb0_prd, wb1_en, wb1_prd);
  endfunction

  // Lowest-set-bit priority encode (way index).
  function automatic rs_way_t rs_pe_lo(input rs_mask_t m);
    rs_pe_lo = '0;
    for (int i = 0; i < RS_WAYS; i++)
      if (m[i])
        return rs_way_t'(i);
  endfunction

  // Second-lowest set bit (for dual free / dual issue).
  function automatic rs_way_t rs_pe_lo2(input rs_mask_t m);
    rs_mask_t rest;
    rest     = m & ~(rs_mask_t'(1) << rs_pe_lo(m));
    rs_pe_lo2 = rs_pe_lo(rest);
  endfunction

  function automatic rs_mask_t rs_way_oh(input rs_way_t w);
    return rs_mask_t'(1) << w;
  endfunction

  // Oldest-ready among mask (min age). Returns way; caller checks |cand|.
  function automatic rs_way_t rs_pick_oldest(
    input rs_mask_t       cand,
    input logic [31:0]    ages [RS_WAYS]
  );
    logic        found;
    logic [31:0] best_age;
    found        = 1'b0;
    best_age     = '1;
    rs_pick_oldest = '0;
    for (int i = 0; i < RS_WAYS; i++) begin
      if (cand[i] && (!found || (ages[i] < best_age))) begin
        found          = 1'b1;
        best_age       = ages[i];
        rs_pick_oldest = rs_way_t'(i);
      end
    end
  endfunction

  function automatic rs_entry_t rs_make_entry(
    input logic               valid,
    input logic               lane_sel,
    input logic               reg_write,
    input logic               spec_en,
    input opcode_t            opcode,
    input funct3_t            funct3,
    input funct7_t            funct7,
    input prf_addr_t          ps1,
    input prf_addr_t          ps2,
    input prf_addr_t          prd,
    input word_t              imm,
    input word_t              pc,
    input logic [31:0]        age,
    input logic [NUM_PRF-1:0] prf_ready,
    input logic               wb0_en,
    input prf_addr_t          wb0_prd,
    input logic               wb1_en,
    input prf_addr_t          wb1_prd,
    input logic               force_rs1_unready,
    input logic               force_rs2_unready,
    input logic               wbrack
  );
    rs_make_entry = '0;
    if (!valid)
      return;
    rs_make_entry.valid     = 1'b1;
    rs_make_entry.age       = age;
    rs_make_entry.lane_sel  = lane_sel;
    rs_make_entry.reg_write = reg_write;
    rs_make_entry.spec_en   = spec_en;
    rs_make_entry.rs1_ready = (ps1 == '0) ||
      (!force_rs1_unready &&
       (prf_ready[ps1] || rs_wb_hit(ps1, wb0_en, wb0_prd, wb1_en, wb1_prd)));
    rs_make_entry.rs2_ready = (ps2 == '0) ||
      (!force_rs2_unready &&
       (prf_ready[ps2] || rs_wb_hit(ps2, wb0_en, wb0_prd, wb1_en, wb1_prd)));
    rs_make_entry.opcode  = opcode;
    rs_make_entry.funct3  = funct3;
    rs_make_entry.funct7  = funct7;
    rs_make_entry.ps1     = ps1;
    rs_make_entry.ps2     = ps2;
    rs_make_entry.prd     = prd;
    rs_make_entry.imm     = imm;
    rs_make_entry.pc      = pc;
    rs_make_entry.issue_ready = rs_calc_issue_ready(
      rs_make_entry, wb0_en, wb0_prd, wb1_en, wb1_prd, wbrack);
  endfunction

endpackage
