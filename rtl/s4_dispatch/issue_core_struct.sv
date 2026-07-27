`timescale 1ns / 1ps

// S4 issue: reservation station + PRF + dp_ex demux.
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
// RS issues tags/controls; PRF supplies operand data; dp_ex buffers data and
// routes the dual issue pair onto ev0/ev1/od0/od1 by lane_sel.
// prd is the ROB-owned dest tag (same as ROB index).
import rv_dis_pkg::*;

module issue_core_struct (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall_ex,

  input  logic        valid_dp      [2],
  input  logic        lane_sel_dp   [2],
  input  logic        spec_en_dp    [2],
  input  opcode_t     opcode_dp     [2],
  input  funct3_t     funct3_dp     [2],
  input  funct7_t     funct7_dp     [2],
  input  prf_addr_t   ps1_dp        [2],
  input  prf_addr_t   ps2_dp        [2],
  input  logic        tag1_valid_dp [2],
  input  logic        tag2_valid_dp [2],
  input  prf_addr_t   prd_dp        [2],
  input  word_t       imm_dp        [2],
  input  word_t       pc_dp         [2],

  input  logic        wb_en         [2],
  input  prf_addr_t   wb_prd        [2],
  input  word_t       wb_data       [2],

  output logic        stall_dp,

  output logic        ev0_enable_ex,
  output logic        ev0_reg_write_ex,
  output opcode_t     ev0_opcode_ex,
  output funct3_t     ev0_funct3_ex,
  output funct7_t     ev0_funct7_ex,
  output prf_addr_t   ev0_prd_ex,
  output word_t       ev0_imm_ex,
  output word_t       ev0_pc_ex,
  output word_t       ev0_rs1_data_ex,
  output word_t       ev0_rs2_data_ex,

  output logic        ev1_enable_ex,
  output logic        ev1_reg_write_ex,
  output opcode_t     ev1_opcode_ex,
  output funct3_t     ev1_funct3_ex,
  output funct7_t     ev1_funct7_ex,
  output prf_addr_t   ev1_prd_ex,
  output word_t       ev1_imm_ex,
  output word_t       ev1_pc_ex,
  output word_t       ev1_rs1_data_ex,
  output word_t       ev1_rs2_data_ex,

  output logic        od0_enable_ex,
  output logic        od0_reg_write_ex,
  output opcode_t     od0_opcode_ex,
  output funct3_t     od0_funct3_ex,
  output prf_addr_t   od0_prd_ex,
  output word_t       od0_imm_ex,
  output word_t       od0_pc_ex,
  output word_t       od0_rs1_data_ex,
  output word_t       od0_rs2_data_ex,

  output logic        od1_enable_ex,
  output logic        od1_reg_write_ex,
  output opcode_t     od1_opcode_ex,
  output funct3_t     od1_funct3_ex,
  output prf_addr_t   od1_prd_ex,
  output word_t       od1_imm_ex,
  output word_t       od1_pc_ex,
  output word_t       od1_rs1_data_ex,
  output word_t       od1_rs2_data_ex
);

  logic      rs1_use_prf [2];
  logic      rs2_use_prf [2];
  prf_addr_t ps1_prf     [2];
  prf_addr_t ps2_prf     [2];

  // Rename zeros prd when !reg_write; recover the flag for RS / dp_ex.
  logic      reg_write_dp [2];

  logic      valid_iss     [2];
  logic      lane_sel_iss  [2];
  logic      reg_write_iss [2];
  opcode_t   opcode_iss    [2];
  funct3_t   funct3_iss    [2];
  funct7_t   funct7_iss    [2];
  prf_addr_t prd_iss       [2];
  word_t     imm_iss       [2];
  word_t     pc_iss        [2];

  word_t     rs1_data [2], rs2_data [2];

  logic issue_en;
  assign issue_en = !stall_ex;

  for (genvar i = 0; i < N_DUAL; i++) begin : g_rw
    assign reg_write_dp[i] = (prd_dp[i] != '0);
  end

  reservation_station u_rs (
    .clk, .rst_n, .enable, .flush,
    .valid_dp, .lane_sel_dp, .reg_write_dp, .spec_en_dp,
    .opcode_dp, .funct3_dp, .funct7_dp,
    .ps1_dp, .ps2_dp, .tag1_valid_dp, .tag2_valid_dp, .prd_dp,
    .imm_dp, .pc_dp,
    .wb_en, .wb_prd,
    .issue_en,
    .stall_dp,
    .rs1_use_prf, .rs2_use_prf, .ps1_prf, .ps2_prf,
    .valid_iss, .lane_sel_iss, .reg_write_iss,
    .opcode_iss, .funct3_iss, .funct7_iss,
    .ps1_iss(), .ps2_iss(), .prd_iss,
    .imm_iss, .pc_iss
  );

  p_register_file u_prf (
    .clk, .rst_n,
    .rs1_use  (rs1_use_prf),
    .rs2_use  (rs2_use_prf),
    .rs1_addr (ps1_prf),
    .rs2_addr (ps2_prf),
    .wb_en, .wb_prd, .wb_data,
    .rs1_data, .rs2_data
  );

  dp_ex u_dp_ex (
    .clk, .rst_n, .enable, .flush,
    .stall(stall_ex),
    .valid_iss, .lane_sel_iss, .reg_write_iss,
    .opcode_iss, .funct3_iss, .funct7_iss,
    .prd_iss, .imm_iss, .pc_iss,
    .rs1_data, .rs2_data,
    .ev0_enable_ex, .ev0_reg_write_ex,
    .ev0_opcode_ex, .ev0_funct3_ex, .ev0_funct7_ex,
    .ev0_prd_ex, .ev0_imm_ex, .ev0_pc_ex,
    .ev0_rs1_data_ex, .ev0_rs2_data_ex,
    .ev1_enable_ex, .ev1_reg_write_ex,
    .ev1_opcode_ex, .ev1_funct3_ex, .ev1_funct7_ex,
    .ev1_prd_ex, .ev1_imm_ex, .ev1_pc_ex,
    .ev1_rs1_data_ex, .ev1_rs2_data_ex,
    .od0_enable_ex, .od0_reg_write_ex,
    .od0_opcode_ex, .od0_funct3_ex,
    .od0_prd_ex, .od0_imm_ex, .od0_pc_ex,
    .od0_rs1_data_ex, .od0_rs2_data_ex,
    .od1_enable_ex, .od1_reg_write_ex,
    .od1_opcode_ex, .od1_funct3_ex,
    .od1_prd_ex, .od1_imm_ex, .od1_pc_ex,
    .od1_rs1_data_ex, .od1_rs2_data_ex
  );

endmodule
