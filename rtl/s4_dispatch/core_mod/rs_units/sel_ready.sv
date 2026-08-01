`timescale 1ns / 1ps

// Selector readiness — path filter, top-2 ready RS, 4-cand pool + ages.
import rv_dis_pkg::*;
import rs_pkg::*;

module sel_ready (
  input  logic        enable,
  input  logic        flush,
  input  logic        path_en,
  input  logic        path_sel,

  input  logic        bank_valid    [RS_WAYS],
  input  rs_age_t     bank_age      [RS_WAYS],
  input  logic        bank_spec     [RS_WAYS],
  input  logic        bank_rs1_rdy  [RS_WAYS],
  input  logic        bank_rs2_rdy  [RS_WAYS],
  input  prf_addr_t   bank_ps1      [RS_WAYS],
  input  prf_addr_t   bank_ps2      [RS_WAYS],
  input  prf_addr_t   bank_prd      [RS_WAYS],

  input  logic        wb_en      [2],
  input  prf_addr_t   rob_tag_wb [2],

  input  logic        valid_dp    [2],
  input  logic        path_use_dp [2],
  input  opcode_t     opcode_dp   [2],
  input  funct3_t     funct3_dp   [2],
  input  prf_addr_t   ps1_dp      [2],
  input  prf_addr_t   ps2_dp      [2],
  input  prf_addr_t   prd_dp      [2],

  output logic        path_ok_d [2],
  output rs_mask_t    bank_valid_m,

  output logic        rs_cand_v   [2],
  output rs_way_t     rs_cand_w   [2],
  output rs_age_t     rs_cand_age [2],

  output logic [3:0]  cand_v,
  output rs_age_t     cand_age [4]
);

  logic     raw_rs1, raw_rs2;
  logic     byp_ready [2];
  logic     path_ok_b [RS_WAYS];
  rs_mask_t bank_ready;
  rs_age_t  rn_base;

  assign path_ok_d[0] = !path_en || (path_use_dp[0] == path_sel);
  assign path_ok_d[1] = !path_en || (path_use_dp[1] == path_sel);

  assign raw_rs1 = rs_disp_raw_rs1(
    valid_dp[0] && path_ok_d[0], opcode_dp[0], funct3_dp[0], prd_dp[0],
    ps1_dp[1]);
  assign raw_rs2 = rs_disp_raw_rs2(
    valid_dp[0] && path_ok_d[0], opcode_dp[0], funct3_dp[0], prd_dp[0],
    ps2_dp[1]);

  assign byp_ready[0] = path_ok_d[0] && rs_disp_ready(
    valid_dp[0], ps1_dp[0], ps2_dp[0],
    bank_valid, bank_prd, wb_en, rob_tag_wb, 1'b0, 1'b0);
  assign byp_ready[1] = path_ok_d[1] && rs_disp_ready(
    valid_dp[1], ps1_dp[1], ps2_dp[1],
    bank_valid, bank_prd, wb_en, rob_tag_wb, raw_rs1, raw_rs2);

  genvar w;
  generate
    for (w = 0; w < RS_WAYS; w++) begin : g_way
      assign path_ok_b[w]    = !path_en || (bank_spec[w] == path_sel);
      assign bank_valid_m[w] = bank_valid[w] && path_ok_b[w];
      assign bank_ready[w]   = path_ok_b[w] && rs_calc_issue_ready(
        bank_valid[w], bank_ps1[w], bank_ps2[w],
        bank_rs1_rdy[w], bank_rs2_rdy[w], wb_en, rob_tag_wb);
    end
  endgenerate

  always_comb begin
    rs_mask_t m;
    m = (enable && !flush) ? bank_ready : '0;
    for (int i = 0; i < 2; i++) begin
      rs_cand_v[i]   = 1'b0;
      rs_cand_w[i]   = '0;
      rs_cand_age[i] = '0;
    end
    for (int i = 0; i < 2; i++) begin
      if (|m) begin
        rs_cand_w[i]   = rs_pick_oldest(m, bank_age);
        rs_cand_v[i]   = 1'b1;
        rs_cand_age[i] = bank_age[rs_cand_w[i]];
        m = m & ~(rs_mask_t'(1) << rs_cand_w[i]);
      end
    end

    rn_base = rs_next_age(bank_valid_m, bank_age);
    cand_v  = {enable && !flush && byp_ready[1],
               enable && !flush && byp_ready[0],
               rs_cand_v[1],
               rs_cand_v[0]};
    cand_age[0] = rs_cand_age[0];
    cand_age[1] = rs_cand_age[1];
    cand_age[2] = rn_base;
    cand_age[3] = rn_base + rs_age_t'(1);
  end

endmodule
