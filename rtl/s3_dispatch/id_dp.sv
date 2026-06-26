`timescale 1ns / 1ps

// ID/DP dispatch — combinational pass-through into dp_ex (no scoreboard / hazard stall).
module id_dp
  import rv_dis_pkg::*;
(
  input  logic        i0_valid_id,
  input  logic        i0_lane_sel_id,
  input  logic        i0_reg_write_id,
  input  logic        i1_valid_id,
  input  logic        i1_lane_sel_id,
  input  logic        i1_reg_write_id,

  input  opcode_t     i0_opcode_id,
  input  funct3_t     i0_funct3_id,
  input  funct7_t     i0_funct7_id,
  input  gpr_addr_t   i0_rd_addr_id,
  input  gpr_addr_t   i0_rs1_addr_id,
  input  gpr_addr_t   i0_rs2_addr_id,
  input  imm_t        i0_imm_id,
  input  reg_t        i0_rs1_data_id,
  input  reg_t        i0_rs2_data_id,
  input  pc_t         i0_pc_id,
  input  opcode_t     i1_opcode_id,
  input  funct3_t     i1_funct3_id,
  input  funct7_t     i1_funct7_id,
  input  gpr_addr_t   i1_rd_addr_id,
  input  gpr_addr_t   i1_rs1_addr_id,
  input  gpr_addr_t   i1_rs2_addr_id,
  input  imm_t        i1_imm_id,
  input  reg_t        i1_rs1_data_id,
  input  reg_t        i1_rs2_data_id,
  input  pc_t         i1_pc_id,

  output logic        stall_id,
  output logic        issue_i0,
  output logic        issue_i1,

  output logic        i0_valid_dp,
  output logic        i0_lane_sel_dp,
  output logic        i0_reg_write_dp,
  output logic        i1_valid_dp,
  output logic        i1_lane_sel_dp,
  output logic        i1_reg_write_dp,
  output opcode_t     i0_opcode_dp,
  output funct3_t     i0_funct3_dp,
  output funct7_t     i0_funct7_dp,
  output gpr_addr_t   i0_rd_addr_dp,
  output gpr_addr_t   i0_rs1_addr_dp,
  output gpr_addr_t   i0_rs2_addr_dp,
  output imm_t        i0_imm_dp,
  output reg_t        i0_rs1_data_dp,
  output reg_t        i0_rs2_data_dp,
  output pc_t         i0_pc_dp,
  output opcode_t     i1_opcode_dp,
  output funct3_t     i1_funct3_dp,
  output funct7_t     i1_funct7_dp,
  output gpr_addr_t   i1_rd_addr_dp,
  output gpr_addr_t   i1_rs1_addr_dp,
  output gpr_addr_t   i1_rs2_addr_dp,
  output imm_t        i1_imm_dp,
  output reg_t        i1_rs1_data_dp,
  output reg_t        i1_rs2_data_dp,
  output pc_t         i1_pc_dp
);

  assign stall_id        = 1'b0;
  assign issue_i0        = i0_valid_id;
  assign issue_i1        = i1_valid_id;

  assign i0_valid_dp     = i0_valid_id;
  assign i1_valid_dp     = i1_valid_id;
  assign i0_lane_sel_dp  = i0_lane_sel_id;
  assign i1_lane_sel_dp  = i1_lane_sel_id;
  assign i0_reg_write_dp = i0_reg_write_id;
  assign i1_reg_write_dp = i1_reg_write_id;
  assign i0_opcode_dp    = i0_opcode_id;
  assign i0_funct3_dp    = i0_funct3_id;
  assign i0_funct7_dp    = i0_funct7_id;
  assign i0_rd_addr_dp   = i0_rd_addr_id;
  assign i0_rs1_addr_dp  = i0_rs1_addr_id;
  assign i0_rs2_addr_dp  = i0_rs2_addr_id;
  assign i0_imm_dp       = i0_imm_id;
  assign i0_rs1_data_dp  = i0_rs1_data_id;
  assign i0_rs2_data_dp  = i0_rs2_data_id;
  assign i0_pc_dp        = i0_pc_id;
  assign i1_opcode_dp    = i1_opcode_id;
  assign i1_funct3_dp    = i1_funct3_id;
  assign i1_funct7_dp    = i1_funct7_id;
  assign i1_rd_addr_dp   = i1_rd_addr_id;
  assign i1_rs1_addr_dp  = i1_rs1_addr_id;
  assign i1_rs2_addr_dp  = i1_rs2_addr_id;
  assign i1_imm_dp       = i1_imm_id;
  assign i1_rs1_data_dp  = i1_rs1_data_id;
  assign i1_rs2_data_dp  = i1_rs2_data_id;
  assign i1_pc_dp        = i1_pc_id;

endmodule
