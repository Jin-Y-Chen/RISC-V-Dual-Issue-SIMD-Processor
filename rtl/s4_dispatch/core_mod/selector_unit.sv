`timescale 1ns / 1ps

// Selector unit — glue: sel_ready → sel_pick → sel_issue.
// RS ↓clk control (src_en, store_en) per channel:
//   1,0 + rs_tag → clear issued RS way
//   1,1 + rs_tag → age bump for unpicked RS cand
//   0,1          → write rename lane
//   0,0          → nop
import rv_dis_pkg::*;
import rs_pkg::*;

module selector_unit (
  input  logic        enable,
  input  logic        flush,
  input  logic        path_en,
  input  logic        path_sel,

  input  logic        bank_valid    [RS_WAYS],
  input  rs_way_t     bank_rs_tag   [RS_WAYS],
  input  rs_age_t     bank_age      [RS_WAYS],
  input  logic        bank_lane_sel [RS_WAYS],
  input  logic        bank_spec     [RS_WAYS],
  input  logic        bank_rs1_rdy  [RS_WAYS],
  input  logic        bank_rs2_rdy  [RS_WAYS],
  input  opcode_t     bank_opcode   [RS_WAYS],
  input  funct3_t     bank_funct3   [RS_WAYS],
  input  funct7_t     bank_funct7   [RS_WAYS],
  input  prf_addr_t   bank_ps1      [RS_WAYS],
  input  prf_addr_t   bank_ps2      [RS_WAYS],
  input  prf_addr_t   bank_prd      [RS_WAYS],
  input  word_t       bank_imm      [RS_WAYS],
  input  word_t       bank_pc       [RS_WAYS],

  input  logic        wb_en      [2],
  input  prf_addr_t   rob_tag_wb [2],

  input  logic        valid_dp    [2],
  input  logic        path_use_dp [2],
  input  logic        lane_sel_dp [2],
  input  opcode_t     opcode_dp   [2],
  input  funct3_t     funct3_dp   [2],
  input  funct7_t     funct7_dp   [2],
  input  prf_addr_t   ps1_dp      [2],
  input  prf_addr_t   ps2_dp      [2],
  input  prf_addr_t   prd_dp      [2],
  input  word_t       imm_dp      [2],
  input  word_t       pc_dp       [2],

  output logic        src_en   [2],
  output rs_way_t     rs_tag   [2],
  output logic        store_en [2],
  output logic        stall_dp,

  output logic        iss_valid    [2],
  output logic        iss_lane_sel [2],
  output opcode_t     iss_opcode   [2],
  output funct3_t     iss_funct3   [2],
  output funct7_t     iss_funct7   [2],
  output prf_addr_t   iss_prd      [2],
  output word_t       iss_imm      [2],
  output word_t       iss_pc       [2],
  output prf_addr_t   ps1_prf      [2],
  output prf_addr_t   ps2_prf      [2]
);

  logic     path_ok_d [2];
  rs_mask_t bank_valid_m;

  logic     rs_cand_v   [2];
  rs_way_t  rs_cand_w   [2];
  rs_age_t  rs_cand_age [2];

  logic [3:0] cand_v;
  rs_age_t    cand_age [4];

  logic     iss_fire [2];
  logic     iss_src  [2];
  rs_way_t  iss_tag  [2];

  sel_ready u_ready (
    .enable, .flush, .path_en, .path_sel,
    .bank_valid, .bank_age, .bank_spec,
    .bank_rs1_rdy, .bank_rs2_rdy,
    .bank_ps1, .bank_ps2, .bank_prd,
    .wb_en, .rob_tag_wb,
    .valid_dp, .path_use_dp,
    .opcode_dp, .funct3_dp,
    .ps1_dp, .ps2_dp, .prd_dp,
    .path_ok_d, .bank_valid_m,
    .rs_cand_v, .rs_cand_w, .rs_cand_age,
    .cand_v, .cand_age
  );

  sel_pick u_pick (
    .enable, .flush,
    .path_ok_d,
    .bank_valid_m, .bank_prd, .bank_rs_tag,
    .wb_en, .rob_tag_wb,
    .valid_dp,
    .rs_cand_v, .rs_cand_w, .rs_cand_age,
    .cand_v, .cand_age,
    .src_en, .rs_tag, .store_en, .stall_dp,
    .iss_fire, .iss_src, .iss_tag
  );

  sel_issue u_issue (
    .bank_lane_sel,
    .bank_opcode, .bank_funct3, .bank_funct7,
    .bank_ps1, .bank_ps2, .bank_prd, .bank_imm, .bank_pc,
    .lane_sel_dp,
    .opcode_dp, .funct3_dp, .funct7_dp,
    .ps1_dp, .ps2_dp, .prd_dp, .imm_dp, .pc_dp,
    .fire(iss_fire), .src(iss_src), .rs_tag(iss_tag),
    .iss_valid, .iss_lane_sel,
    .iss_opcode, .iss_funct3, .iss_funct7,
    .iss_prd, .iss_imm, .iss_pc,
    .ps1_prf, .ps2_prf
  );

endmodule
