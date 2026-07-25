`timescale 1ns / 1ps

// RS alloc / wakeup — per-way update; free via ~valid mask + PE.
// wbrack: kill path1 (spec_en=1); only path0 remains issuable.
import rv_dis_pkg::*;
import rs_pkg::*;

module rs_alloc (
  input  logic               enable,
  input  logic               flush,
  input  logic               stall_dp,
  input  logic               wbrack,

  input  rs_entry_t          bank_q [RS_SETS][RS_WAYS],
  input  logic [NUM_PRF-1:0] prf_ready_q,
  input  logic [31:0]        age_q,

  input  logic               wb0_en,
  input  prf_addr_t          wb0_prd,
  input  logic               wb1_en,
  input  prf_addr_t          wb1_prd,

  input  rs_way_t            sel0,
  input  rs_way_t            sel1,
  input  logic               issue0_fire,
  input  logic               issue1_fire,

  input  logic               i0_valid_dp,
  input  logic               i0_lane_sel_dp,
  input  logic               i0_reg_write_dp,
  input  logic               i0_spec_en_dp,
  input  opcode_t            i0_opcode_dp,
  input  funct3_t            i0_funct3_dp,
  input  funct7_t            i0_funct7_dp,
  input  prf_addr_t          i0_ps1_dp,
  input  prf_addr_t          i0_ps2_dp,
  input  prf_addr_t          i0_prd_dp,
  input  word_t              i0_imm_dp,
  input  word_t              i0_pc_dp,

  input  logic               i1_valid_dp,
  input  logic               i1_lane_sel_dp,
  input  logic               i1_reg_write_dp,
  input  logic               i1_spec_en_dp,
  input  opcode_t            i1_opcode_dp,
  input  funct3_t            i1_funct3_dp,
  input  funct7_t            i1_funct7_dp,
  input  prf_addr_t          i1_ps1_dp,
  input  prf_addr_t          i1_ps2_dp,
  input  prf_addr_t          i1_prd_dp,
  input  word_t              i1_imm_dp,
  input  word_t              i1_pc_dp,

  output rs_entry_t          bank_n [RS_SETS][RS_WAYS],
  output logic [NUM_PRF-1:0] prf_ready_n,
  output logic [31:0]        age_n
);

  logic i0_ins, i1_ins;
  assign i0_ins = i0_valid_dp && (!wbrack || !i0_spec_en_dp);
  assign i1_ins = i1_valid_dp && (!wbrack || !i1_spec_en_dp);

  rs_entry_t way_n [RS_WAYS];
  rs_mask_t  valid_after;
  rs_mask_t  free_m;
  rs_way_t   free0, free1, slot;
  logic      dep_rs1, dep_rs2;

  // Per-way wakeup / path kill (parallel).
  genvar w;
  generate
    for (w = 0; w < RS_WAYS; w++) begin : g_wake
      always_comb begin
        way_n[w] = bank_q[0][w];
        if (wbrack && way_n[w].valid && way_n[w].spec_en)
          way_n[w] = '0;
        else if (way_n[w].valid) begin
          if (!way_n[w].rs1_ready &&
              rs_wb_hit(way_n[w].ps1, wb0_en, wb0_prd, wb1_en, wb1_prd))
            way_n[w].rs1_ready = 1'b1;
          if (!way_n[w].rs2_ready &&
              rs_wb_hit(way_n[w].ps2, wb0_en, wb0_prd, wb1_en, wb1_prd))
            way_n[w].rs2_ready = 1'b1;
        end
      end
    end
  endgenerate

  always_comb begin
    bank_n      = '{default: '0};
    prf_ready_n = prf_ready_q;
    age_n       = age_q;

    for (int i = 0; i < RS_WAYS; i++)
      bank_n[0][i] = way_n[i];

    if (wb0_en) prf_ready_n[wb0_prd] = 1'b1;
    if (wb1_en) prf_ready_n[wb1_prd] = 1'b1;

    if (issue0_fire) bank_n[0][sel0] = '0;
    if (issue1_fire) bank_n[0][sel1] = '0;

    for (int i = 0; i < RS_WAYS; i++)
      valid_after[i] = bank_n[0][i].valid;
    free_m = ~valid_after;
    free0  = rs_pe_lo(free_m);
    free1  = rs_pe_lo2(free_m);

    if (enable && !flush && !stall_dp) begin
      if (i0_ins) begin
        bank_n[0][free0] = rs_make_entry(
          1'b1, i0_lane_sel_dp, i0_reg_write_dp, i0_spec_en_dp,
          i0_opcode_dp, i0_funct3_dp, i0_funct7_dp,
          i0_ps1_dp, i0_ps2_dp, i0_prd_dp,
          i0_imm_dp, i0_pc_dp,
          age_n, prf_ready_n,
          wb0_en, wb0_prd, wb1_en, wb1_prd,
          1'b0, 1'b0, wbrack);
        age_n = age_n + 1'b1;
      end

      if (i1_ins) begin
        slot    = i0_ins ? free1 : free0;
        dep_rs1 = i0_ins && i0_reg_write_dp &&
                  (i0_prd_dp != '0) && (i1_ps1_dp == i0_prd_dp);
        dep_rs2 = i0_ins && i0_reg_write_dp &&
                  (i0_prd_dp != '0) && (i1_ps2_dp == i0_prd_dp);
        bank_n[0][slot] = rs_make_entry(
          1'b1, i1_lane_sel_dp, i1_reg_write_dp, i1_spec_en_dp,
          i1_opcode_dp, i1_funct3_dp, i1_funct7_dp,
          i1_ps1_dp, i1_ps2_dp, i1_prd_dp,
          i1_imm_dp, i1_pc_dp,
          age_n, prf_ready_n,
          wb0_en, wb0_prd, wb1_en, wb1_prd,
          dep_rs1, dep_rs2, wbrack);
        age_n = age_n + 1'b1;
      end

      if (i0_ins && i0_reg_write_dp && (i0_prd_dp != '0))
        prf_ready_n[i0_prd_dp] = 1'b0;
      if (i1_ins && i1_reg_write_dp && (i1_prd_dp != '0))
        prf_ready_n[i1_prd_dp] = 1'b0;
    end

    prf_ready_n[0] = 1'b1;
  end

endmodule
