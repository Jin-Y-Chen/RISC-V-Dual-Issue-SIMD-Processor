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

  typedef logic [RS_WAY_AW-1:0] rs_way_t;
  typedef logic [RS_WAYS-1:0]   rs_mask_t;

  typedef struct packed {
    logic        valid;
    logic [31:0] age;
    logic        lane_sel;
    logic        reg_write;
    logic        spec_en;      // 0=path0, 1=path1
    logic        tag1_valid;   // RAT: rs1 needs a PRF operand
    logic        tag2_valid;
    logic        rs1_ready;
    logic        rs2_ready;
    opcode_t     opcode;
    funct3_t     funct3;
    funct7_t     funct7;
    prf_addr_t   ps1;
    prf_addr_t   ps2;
    prf_addr_t   prd;          // ROB-owned dest tag (== ROB index)
    word_t       imm;
    word_t       pc;
  } rs_entry_t;

  // Dual-dispatch insn (shared by alloc / issue; packed in RS top).
  typedef struct packed {
    logic      valid;
    logic      lane_sel;
    logic      reg_write;
    logic      spec_en;
    logic      tag1_valid;
    logic      tag2_valid;
    opcode_t   opcode;
    funct3_t   funct3;
    funct7_t   funct7;
    prf_addr_t ps1;
    prf_addr_t ps2;
    prf_addr_t prd;
    word_t     imm;
    word_t     pc;
  } rs_disp_insn_t;

  typedef struct packed {
    rs_disp_insn_t i0;
    rs_disp_insn_t i1;
  } rs_disp_pair_t;

  typedef struct packed {
    logic      en;
    prf_addr_t prd;
  } rs_wb_tag_t;

  typedef struct packed {
    rs_wb_tag_t wb0;
    rs_wb_tag_t wb1;
  } rs_wb_pair_t;

  // Issued insn → dp_ex / PRF read (unpacked at RS top).
  typedef struct packed {
    logic      valid;
    logic      lane_sel;
    logic      reg_write;
    opcode_t   opcode;
    funct3_t   funct3;
    funct7_t   funct7;
    prf_addr_t ps1;
    prf_addr_t ps2;
    prf_addr_t prd;
    word_t     imm;
    word_t     pc;
  } rs_iss_insn_t;

  typedef struct packed {
    rs_iss_insn_t i0;
    rs_iss_insn_t i1;
  } rs_iss_pair_t;

  typedef struct packed {
    logic      rs1_use;
    logic      rs2_use;
    prf_addr_t ps1;
    prf_addr_t ps2;
  } rs_prf_rd_t;

  typedef struct packed {
    rs_prf_rd_t i0;
    rs_prf_rd_t i1;
  } rs_prf_rd_pair_t;

  typedef struct packed {
    rs_way_t sel0;       // bank way if src0==BANK
    rs_way_t sel1;
    logic    sel0_v;
    logic    sel1_v;
    logic    fire0;
    logic    fire1;
    logic    src0_disp;  // 1 → issue slot from disp (bypass)
    logic    src1_disp;
    logic    src0_d1;    // which disp lane when src*_disp (0=i0, 1=i1)
    logic    src1_d1;
    logic    bypass0;    // disp.i0 issued this cycle — do not allocate
    logic    bypass1;    // disp.i1 issued this cycle — do not allocate
  } rs_pick_t;

  function automatic logic rs_wb_hit(
    input prf_addr_t   tag,
    input rs_wb_pair_t wb
  );
    return (wb.wb0.en && (wb.wb0.prd == tag)) ||
           (wb.wb1.en && (wb.wb1.prd == tag));
  endfunction

  function automatic logic rs_src_ready(
    input logic        tag_valid,
    input prf_addr_t   tag,
    input logic        ready_bit,
    input rs_wb_pair_t wb
  );
    return !tag_valid || ready_bit || rs_wb_hit(tag, wb);
  endfunction

  function automatic logic rs_calc_issue_ready(
    input rs_entry_t   entry,
    input rs_wb_pair_t wb
  );
    return entry.valid &&
           rs_src_ready(entry.tag1_valid, entry.ps1, entry.rs1_ready, wb) &&
           rs_src_ready(entry.tag2_valid, entry.ps2, entry.rs2_ready, wb);
  endfunction

  // Dispatch-path wakeup: PRF ready bits + same-cycle WB broadcast.
  function automatic logic rs_disp_ready(
    input rs_disp_insn_t      d,
    input logic [NUM_PRF-1:0] prf_ready,
    input rs_wb_pair_t        wb,
    input logic               force_rs1_unready,
    input logic               force_rs2_unready
  );
    logic r1, r2;
    if (!d.valid)
      return 1'b0;
    r1 = !d.tag1_valid ||
         (!force_rs1_unready &&
          (prf_ready[d.ps1] || rs_wb_hit(d.ps1, wb)));
    r2 = !d.tag2_valid ||
         (!force_rs2_unready &&
          (prf_ready[d.ps2] || rs_wb_hit(d.ps2, wb)));
    return r1 && r2;
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
    input rs_disp_insn_t      d,
    input logic [31:0]        age,
    input logic [NUM_PRF-1:0] prf_ready,
    input rs_wb_pair_t        wb,
    input logic               force_rs1_unready,
    input logic               force_rs2_unready
  );
    rs_make_entry = '0;
    if (!d.valid)
      return rs_make_entry;
    rs_make_entry.valid     = 1'b1;
    rs_make_entry.age       = age;
    rs_make_entry.lane_sel  = d.lane_sel;
    rs_make_entry.reg_write = d.reg_write;
    rs_make_entry.spec_en   = d.spec_en;
    rs_make_entry.tag1_valid = d.tag1_valid;
    rs_make_entry.tag2_valid = d.tag2_valid;
    rs_make_entry.rs1_ready = !d.tag1_valid ||
      (!force_rs1_unready &&
       (prf_ready[d.ps1] || rs_wb_hit(d.ps1, wb)));
    rs_make_entry.rs2_ready = !d.tag2_valid ||
      (!force_rs2_unready &&
       (prf_ready[d.ps2] || rs_wb_hit(d.ps2, wb)));
    rs_make_entry.opcode  = d.opcode;
    rs_make_entry.funct3  = d.funct3;
    rs_make_entry.funct7  = d.funct7;
    rs_make_entry.ps1     = d.ps1;
    rs_make_entry.ps2     = d.ps2;
    rs_make_entry.prd     = d.prd;
    rs_make_entry.imm     = d.imm;
    rs_make_entry.pc      = d.pc;
  endfunction

endpackage
