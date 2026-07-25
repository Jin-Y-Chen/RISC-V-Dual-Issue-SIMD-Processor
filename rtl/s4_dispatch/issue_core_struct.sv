`timescale 1ns / 1ps

// S4 issue: reservation station + PRF + dp_ex demux.
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

  input  logic        i0_valid_dp,
  input  logic        i0_lane_sel_dp,
  input  logic        i0_reg_write_dp,
  input  logic        i0_spec_en_dp,
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

  input  logic        wb0_en,
  input  prf_addr_t   wb0_prd,
  input  word_t       wb0_data,
  input  logic        wb1_en,
  input  prf_addr_t   wb1_prd,
  input  word_t       wb1_data,
  input  logic        wbrack,

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

  logic      i0_rs1_use_prf, i0_rs2_use_prf;
  logic      i1_rs1_use_prf, i1_rs2_use_prf;
  prf_addr_t i0_ps1_prf, i0_ps2_prf, i1_ps1_prf, i1_ps2_prf;

  logic      i0_valid_iss, i1_valid_iss;
  logic      i0_lane_sel_iss, i1_lane_sel_iss;
  logic      i0_reg_write_iss, i1_reg_write_iss;
  opcode_t   i0_opcode_iss, i1_opcode_iss;
  funct3_t   i0_funct3_iss, i1_funct3_iss;
  funct7_t   i0_funct7_iss, i1_funct7_iss;
  prf_addr_t i0_ps1_iss, i0_ps2_iss, i0_prd_iss;
  prf_addr_t i1_ps1_iss, i1_ps2_iss, i1_prd_iss;
  word_t     i0_imm_iss, i0_pc_iss, i1_imm_iss, i1_pc_iss;

  logic      rs1_use [2], rs2_use [2];
  prf_addr_t rs1_addr [2], rs2_addr [2];
  logic      wb_en [2];
  prf_addr_t wb_prd [2];
  word_t     wb_data [2];
  word_t     rs1_data [2], rs2_data [2];

  logic issue_en;
  assign issue_en = !stall_ex;

  always_comb begin
    rs1_use[0]  = i0_rs1_use_prf;  rs2_use[0]  = i0_rs2_use_prf;
    rs1_addr[0] = i0_ps1_prf;      rs2_addr[0] = i0_ps2_prf;
    rs1_use[1]  = i1_rs1_use_prf;  rs2_use[1]  = i1_rs2_use_prf;
    rs1_addr[1] = i1_ps1_prf;      rs2_addr[1] = i1_ps2_prf;
    wb_en[0] = wb0_en; wb_prd[0] = wb0_prd; wb_data[0] = wb0_data;
    wb_en[1] = wb1_en; wb_prd[1] = wb1_prd; wb_data[1] = wb1_data;
  end

  reservation_station u_rs (
    .clk, .rst_n, .enable, .flush,
    .i0_valid_dp, .i0_lane_sel_dp, .i0_reg_write_dp, .i0_spec_en_dp,
    .i0_opcode_dp, .i0_funct3_dp, .i0_funct7_dp,
    .i0_ps1_dp, .i0_ps2_dp, .i0_prd_dp,
    .i0_imm_dp, .i0_pc_dp,
    .i1_valid_dp, .i1_lane_sel_dp, .i1_reg_write_dp, .i1_spec_en_dp,
    .i1_opcode_dp, .i1_funct3_dp, .i1_funct7_dp,
    .i1_ps1_dp, .i1_ps2_dp, .i1_prd_dp,
    .i1_imm_dp, .i1_pc_dp,
    .wb0_en, .wb0_prd, .wb1_en, .wb1_prd, .wbrack,
    .issue_en,
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

  p_register_file u_prf (
    .clk, .rst_n,
    .rs1_use, .rs2_use, .rs1_addr, .rs2_addr,
    .wb_en, .wb_prd, .wb_data,
    .rs1_data, .rs2_data
  );

  dp_ex u_dp_ex (
    .clk, .rst_n, .enable, .flush,
    .stall(stall_ex),
    .i0_valid_iss, .i0_lane_sel_iss, .i0_reg_write_iss,
    .i0_opcode_iss, .i0_funct3_iss, .i0_funct7_iss,
    .i0_prd_iss, .i0_imm_iss, .i0_pc_iss,
    .i0_rs1_data(rs1_data[0]), .i0_rs2_data(rs2_data[0]),
    .i1_valid_iss, .i1_lane_sel_iss, .i1_reg_write_iss,
    .i1_opcode_iss, .i1_funct3_iss, .i1_funct7_iss,
    .i1_prd_iss, .i1_imm_iss, .i1_pc_iss,
    .i1_rs1_data(rs1_data[1]), .i1_rs2_data(rs2_data[1]),
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
