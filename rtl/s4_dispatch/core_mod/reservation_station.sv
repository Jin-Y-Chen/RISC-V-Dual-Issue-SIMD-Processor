`timescale 1ns / 1ps

// RS top — 1-set × 16-way bank; dual dispatch / dual issue / dual WB wakeup.
// Negedge bank update (aligned with ROB WB / PRF). No operand storage.
import rv_dis_pkg::*;
import rs_pkg::*;

module reservation_station (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,

  // Dual dispatch (tags + controls)
  input  logic        i0_valid_dp,
  input  logic        i0_lane_sel_dp,
  input  logic        i0_reg_write_dp,
  input  logic        i0_spec_en_dp,   // 0=path0, 1=path1
  input  opcode_t     i0_opcode_dp,
  input  funct3_t     i0_funct3_dp,
  input  funct7_t     i0_funct7_dp,
  input  prf_addr_t   i0_ps1_dp,
  input  prf_addr_t   i0_ps2_dp,
  input  prf_addr_t   i0_prd_dp,
  input  word_t       i0_imm_dp,
  input  word_t       i0_pc_dp,

  input  logic        i1_valid_dp,
  input  logic        i1_lane_sel_dp,
  input  logic        i1_reg_write_dp,
  input  logic        i1_spec_en_dp,
  input  opcode_t     i1_opcode_dp,
  input  funct3_t     i1_funct3_dp,
  input  funct7_t     i1_funct7_dp,
  input  prf_addr_t   i1_ps1_dp,
  input  prf_addr_t   i1_ps2_dp,
  input  prf_addr_t   i1_prd_dp,
  input  word_t       i1_imm_dp,
  input  word_t       i1_pc_dp,

  // Dual writeback tags
  input  logic        wb0_en,
  input  prf_addr_t   wb0_prd,
  input  logic        wb1_en,
  input  prf_addr_t   wb1_prd,

  input  logic        issue_en,        // downstream accept (EX / dp_ex)
  output logic        stall_dp,

  // Dual issue → PRF read ports
  output logic        i0_rs1_use_prf,
  output logic        i0_rs2_use_prf,
  output prf_addr_t   i0_ps1_prf,
  output prf_addr_t   i0_ps2_prf,
  output logic        i1_rs1_use_prf,
  output logic        i1_rs2_use_prf,
  output prf_addr_t   i1_ps1_prf,
  output prf_addr_t   i1_ps2_prf,

  // Dual issue → dp_ex
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

  rs_entry_t          bank_q [RS_SETS][RS_WAYS], bank_n [RS_SETS][RS_WAYS];
  logic [NUM_PRF-1:0] prf_ready_q, prf_ready_n;
  logic [31:0]        age_q, age_n;

  rs_way_t sel0, sel1;
  logic    sel0_v, sel1_v;
  logic    issue0_fire, issue1_fire;

  rs_issue u_issue (
    .enable, .flush,
    .bank_q,
    .wb0_en, .wb0_prd, .wb1_en, .wb1_prd,
    .i0_valid_dp, .i1_valid_dp,
    .issue_en,
    .sel0, .sel1, .sel0_v, .sel1_v, .issue0_fire, .issue1_fire,
    .stall_dp,
    .i0_rs1_use_prf, .i0_rs2_use_prf, .i0_ps1_prf, .i0_ps2_prf,
    .i1_rs1_use_prf, .i1_rs2_use_prf, .i1_ps1_prf, .i1_ps2_prf,
    .i0_valid_iss, .i0_lane_sel_iss, .i0_reg_write_iss,
    .i0_opcode_iss, .i0_funct3_iss, .i0_funct7_iss,
    .i0_ps1_iss, .i0_ps2_iss, .i0_prd_iss,
    .i0_imm_iss, .i0_pc_iss,
    .i1_valid_iss, .i1_lane_sel_iss, .i1_reg_write_iss,
    .i1_opcode_iss, .i1_funct3_iss, .i1_funct7_iss,
    .i1_ps1_iss, .i1_ps2_iss, .i1_prd_iss,
    .i1_imm_iss, .i1_pc_iss
  );

  rs_alloc u_alloc (
    .enable, .flush, .stall_dp,
    .bank_q, .prf_ready_q, .age_q,
    .wb0_en, .wb0_prd, .wb1_en, .wb1_prd,
    .sel0, .sel1, .issue0_fire, .issue1_fire,
    .i0_valid_dp, .i0_lane_sel_dp, .i0_reg_write_dp, .i0_spec_en_dp,
    .i0_opcode_dp, .i0_funct3_dp, .i0_funct7_dp,
    .i0_ps1_dp, .i0_ps2_dp, .i0_prd_dp,
    .i0_imm_dp, .i0_pc_dp,
    .i1_valid_dp, .i1_lane_sel_dp, .i1_reg_write_dp, .i1_spec_en_dp,
    .i1_opcode_dp, .i1_funct3_dp, .i1_funct7_dp,
    .i1_ps1_dp, .i1_ps2_dp, .i1_prd_dp,
    .i1_imm_dp, .i1_pc_dp,
    .bank_n, .prf_ready_n, .age_n
  );

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      bank_q      <= '{default: '0};
      prf_ready_q <= '1;
      age_q       <= '0;
    end else begin
      bank_q      <= bank_n;
      prf_ready_q <= prf_ready_n;
      age_q       <= age_n;
    end
  end

endmodule
