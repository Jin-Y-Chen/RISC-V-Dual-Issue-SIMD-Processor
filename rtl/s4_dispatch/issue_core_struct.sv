`timescale 1ns / 1ps

// S4 issue / dispatch glue — three peers:
//   p_register_file | reservation_station | selector_unit
// Pick: src_en (1=RS / 0=rename), store_en, rs_tag → RS ↓clk update.
import rv_dis_pkg::*;
import rs_pkg::*;

module issue_core_struct (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush_rs,
  input  logic        path_en,
  input  logic        path_sel,

  input  logic        rob_valid_dp  [2],
  input  logic        path_use_dp   [2],
  input  logic        lane_sel_dp   [2],
  input  opcode_t     opcode_dp     [2],
  input  funct3_t     funct3_dp     [2],
  input  funct7_t     funct7_dp     [2],
  input  prf_addr_t   ps1_tag_dp    [2],
  input  prf_addr_t   ps2_tag_dp    [2],
  input  prf_addr_t   rob_tag_dp    [2],
  input  word_t       imm_dp        [2],
  input  word_t       pc_dp         [2],

  input  logic        wb_en         [2],
  input  prf_addr_t   rob_tag_wb    [2],
  input  word_t       wb_data       [2],

  output logic        stall_dp,
  output logic        valid         [2],
  output logic        lane_sel      [2],
  output logic        reg_write     [2],
  output opcode_t     opcode        [2],
  output funct3_t     funct3        [2],
  output funct7_t     funct7        [2],
  output prf_addr_t   rob_tag       [2],
  output word_t       imm           [2],
  output word_t       pc            [2],
  output word_t       rs1_data      [2],
  output word_t       rs2_data      [2]
);

  logic        bank_valid    [RS_WAYS];
  rs_way_t     bank_rs_tag   [RS_WAYS];
  rs_age_t     bank_age      [RS_WAYS];
  logic        bank_lane_sel [RS_WAYS];
  logic        bank_spec     [RS_WAYS];
  logic        bank_rs1_rdy  [RS_WAYS];
  logic        bank_rs2_rdy  [RS_WAYS];
  opcode_t     bank_opcode   [RS_WAYS];
  funct3_t     bank_funct3   [RS_WAYS];
  funct7_t     bank_funct7   [RS_WAYS];
  prf_addr_t   bank_ps1      [RS_WAYS];
  prf_addr_t   bank_ps2      [RS_WAYS];
  prf_addr_t   bank_prd      [RS_WAYS];
  word_t       bank_imm      [RS_WAYS];
  word_t       bank_pc       [RS_WAYS];

  logic        src_en   [2];
  logic        store_en [2];
  rs_way_t     rs_tag   [2];

  logic        iss_valid    [2];
  logic        iss_lane_sel [2];
  opcode_t     iss_opcode   [2];
  funct3_t     iss_funct3   [2];
  funct7_t     iss_funct7   [2];
  prf_addr_t   iss_prd      [2];
  word_t       iss_imm      [2];
  word_t       iss_pc       [2];
  prf_addr_t   ps1_prf      [2];
  prf_addr_t   ps2_prf      [2];

  for (genvar i = 0; i < 2; i++) begin : g_iss
    assign valid[i]     = iss_valid[i];
    assign lane_sel[i]  = iss_lane_sel[i];
    assign reg_write[i] = rs_produces(iss_opcode[i], iss_funct3[i], iss_prd[i]);
    assign opcode[i]    = iss_opcode[i];
    assign funct3[i]    = iss_funct3[i];
    assign funct7[i]    = iss_funct7[i];
    assign rob_tag[i]   = iss_prd[i];
    assign imm[i]       = iss_imm[i];
    assign pc[i]        = iss_pc[i];
  end

  reservation_station u_rs (
    .clk, .rst_n, .enable,
    .flush(flush_rs),
    .path_en, .path_sel,
    .stall_dp,
    .valid_dp(rob_valid_dp),
    .lane_sel_dp,
    .path_use_dp,
    .opcode_dp, .funct3_dp, .funct7_dp,
    .ps1_tag_dp, .ps2_tag_dp, .rob_tag_dp,
    .imm_dp, .pc_dp,
    .wb_en, .rob_tag_wb,
    .src_en, .store_en, .rs_tag,
    .bank_valid, .bank_rs_tag, .bank_age, .bank_lane_sel, .bank_spec,
    .bank_rs1_rdy, .bank_rs2_rdy,
    .bank_opcode, .bank_funct3, .bank_funct7,
    .bank_ps1, .bank_ps2, .bank_prd, .bank_imm, .bank_pc
  );

  selector_unit u_select (
    .enable,
    .flush(flush_rs),
    .path_en, .path_sel,
    .bank_valid, .bank_rs_tag, .bank_age, .bank_lane_sel, .bank_spec,
    .bank_rs1_rdy, .bank_rs2_rdy,
    .bank_opcode, .bank_funct3, .bank_funct7,
    .bank_ps1, .bank_ps2, .bank_prd, .bank_imm, .bank_pc,
    .wb_en, .rob_tag_wb,
    .valid_dp    (rob_valid_dp),
    .path_use_dp,
    .lane_sel_dp,
    .opcode_dp, .funct3_dp, .funct7_dp,
    .ps1_dp      (ps1_tag_dp),
    .ps2_dp      (ps2_tag_dp),
    .prd_dp      (rob_tag_dp),
    .imm_dp, .pc_dp,
    .src_en, .rs_tag, .store_en,
    .stall_dp,
    .iss_valid, .iss_lane_sel,
    .iss_opcode, .iss_funct3, .iss_funct7,
    .iss_prd, .iss_imm, .iss_pc,
    .ps1_prf, .ps2_prf
  );

  p_register_file u_prf (
    .clk, .rst_n,
    .rs1_addr(ps1_prf),
    .rs2_addr(ps2_prf),
    .wb_en, .rob_tag_wb, .wb_data,
    .rs1_data, .rs2_data
  );

endmodule
