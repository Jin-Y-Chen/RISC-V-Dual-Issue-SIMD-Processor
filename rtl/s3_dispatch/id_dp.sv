`timescale 1ns / 1ps

import rv_dis_pkg::*;

// ID/DP pipeline register — decode bundle latched on posedge before dispatch core.
// stall_id from dispatch holds this register; flush clears it.
// Also carries per-lane rs_use, speculation enables, and BHT state for later stages.
module id_dp (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls (stage)
  input  logic        flush,
  input  logic        stall,

  // internal controls (I0)
  input  logic        i0_valid_id,
  input  logic        i0_lane_sel_id,
  input  logic        i0_reg_write_id,
  input  logic        i0_rs1_use_id,
  input  logic        i0_rs2_use_id,
  input  logic        spec0_en_id,
  input  br_state_t   i0_state_id,

  // internal controls (I1)
  input  logic        i1_valid_id,
  input  logic        i1_lane_sel_id,
  input  logic        i1_reg_write_id,
  input  logic        i1_rs1_use_id,
  input  logic        i1_rs2_use_id,
  input  logic        spec1_en_id,
  input  br_state_t   i1_state_id,

  // input data (I0)
  input  opcode_t     i0_opcode_id,
  input  funct3_t     i0_funct3_id,
  input  funct7_t     i0_funct7_id,
  input  gpr_addr_t   i0_rd_addr_id,
  input  gpr_addr_t   i0_rs1_addr_id,
  input  gpr_addr_t   i0_rs2_addr_id,
  input  word_t       i0_imm_id,
  input  word_t       i0_rs1_data_id,
  input  word_t       i0_rs2_data_id,
  input  word_t       i0_pc_id,

  // input data (I1)
  input  opcode_t     i1_opcode_id,
  input  funct3_t     i1_funct3_id,
  input  funct7_t     i1_funct7_id,
  input  gpr_addr_t   i1_rd_addr_id,
  input  gpr_addr_t   i1_rs1_addr_id,
  input  gpr_addr_t   i1_rs2_addr_id,
  input  word_t       i1_imm_id,
  input  word_t       i1_rs1_data_id,
  input  word_t       i1_rs2_data_id,
  input  word_t       i1_pc_id,

  // output controls (I0)
  output logic        i0_valid_dp,
  output logic        i0_lane_sel_dp,
  output logic        i0_reg_write_dp,
  output logic        i0_rs1_use_dp,
  output logic        i0_rs2_use_dp,
  output logic        spec0_en_dp,
  output br_state_t   i0_state_dp,

  // output controls (I1)
  output logic        i1_valid_dp,
  output logic        i1_lane_sel_dp,
  output logic        i1_reg_write_dp,
  output logic        i1_rs1_use_dp,
  output logic        i1_rs2_use_dp,
  output logic        spec1_en_dp,
  output br_state_t   i1_state_dp,

  // output data (I0)
  output opcode_t     i0_opcode_dp,
  output funct3_t     i0_funct3_dp,
  output funct7_t     i0_funct7_dp,
  output gpr_addr_t   i0_rd_addr_dp,
  output gpr_addr_t   i0_rs1_addr_dp,
  output gpr_addr_t   i0_rs2_addr_dp,
  output word_t       i0_imm_dp,
  output word_t       i0_rs1_data_dp,
  output word_t       i0_rs2_data_dp,
  output word_t       i0_pc_dp,

  // output data (I1)
  output opcode_t     i1_opcode_dp,
  output funct3_t     i1_funct3_dp,
  output funct7_t     i1_funct7_dp,
  output gpr_addr_t   i1_rd_addr_dp,
  output gpr_addr_t   i1_rs1_addr_dp,
  output gpr_addr_t   i1_rs2_addr_dp,
  output word_t       i1_imm_dp,
  output word_t       i1_rs1_data_dp,
  output word_t       i1_rs2_data_dp,
  output word_t       i1_pc_dp
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i0_valid_dp     <= 1'b0;
      i0_lane_sel_dp  <= 1'b0;
      i0_reg_write_dp <= 1'b0;
      i0_rs1_use_dp   <= 1'b0;
      i0_rs2_use_dp   <= 1'b0;
      spec0_en_dp     <= 1'b0;
      i0_state_dp     <= '0;
      i0_opcode_dp    <= '0;
      i0_funct3_dp    <= '0;
      i0_funct7_dp    <= '0;
      i0_rd_addr_dp   <= '0;
      i0_rs1_addr_dp  <= '0;
      i0_rs2_addr_dp  <= '0;
      i0_imm_dp       <= '0;
      i0_rs1_data_dp  <= '0;
      i0_rs2_data_dp  <= '0;
      i0_pc_dp        <= '0;

      i1_valid_dp     <= 1'b0;
      i1_lane_sel_dp  <= 1'b0;
      i1_reg_write_dp <= 1'b0;
      i1_rs1_use_dp   <= 1'b0;
      i1_rs2_use_dp   <= 1'b0;
      spec1_en_dp     <= 1'b0;
      i1_state_dp     <= '0;
      i1_opcode_dp    <= '0;
      i1_funct3_dp    <= '0;
      i1_funct7_dp    <= '0;
      i1_rd_addr_dp   <= '0;
      i1_rs1_addr_dp  <= '0;
      i1_rs2_addr_dp  <= '0;
      i1_imm_dp       <= '0;
      i1_rs1_data_dp  <= '0;
      i1_rs2_data_dp  <= '0;
      i1_pc_dp        <= '0;
    end else if (flush) begin
      i0_valid_dp     <= 1'b0;
      i0_lane_sel_dp  <= 1'b0;
      i0_reg_write_dp <= 1'b0;
      i0_rs1_use_dp   <= 1'b0;
      i0_rs2_use_dp   <= 1'b0;
      spec0_en_dp     <= 1'b0;
      i0_state_dp     <= '0;
      i0_opcode_dp    <= '0;
      i0_funct3_dp    <= '0;
      i0_funct7_dp    <= '0;
      i0_rd_addr_dp   <= '0;
      i0_rs1_addr_dp  <= '0;
      i0_rs2_addr_dp  <= '0;
      i0_imm_dp       <= '0;
      i0_rs1_data_dp  <= '0;
      i0_rs2_data_dp  <= '0;
      i0_pc_dp        <= '0;

      i1_valid_dp     <= 1'b0;
      i1_lane_sel_dp  <= 1'b0;
      i1_reg_write_dp <= 1'b0;
      i1_rs1_use_dp   <= 1'b0;
      i1_rs2_use_dp   <= 1'b0;
      spec1_en_dp     <= 1'b0;
      i1_state_dp     <= '0;
      i1_opcode_dp    <= '0;
      i1_funct3_dp    <= '0;
      i1_funct7_dp    <= '0;
      i1_rd_addr_dp   <= '0;
      i1_rs1_addr_dp  <= '0;
      i1_rs2_addr_dp  <= '0;
      i1_imm_dp       <= '0;
      i1_rs1_data_dp  <= '0;
      i1_rs2_data_dp  <= '0;
      i1_pc_dp        <= '0;
    end else if (enable && !stall) begin
      i0_valid_dp     <= i0_valid_id;
      i0_lane_sel_dp  <= i0_lane_sel_id;
      i0_reg_write_dp <= i0_reg_write_id;
      i0_rs1_use_dp   <= i0_rs1_use_id;
      i0_rs2_use_dp   <= i0_rs2_use_id;
      spec0_en_dp     <= spec0_en_id;
      i0_state_dp     <= i0_state_id;
      i0_opcode_dp    <= i0_opcode_id;
      i0_funct3_dp    <= i0_funct3_id;
      i0_funct7_dp    <= i0_funct7_id;
      i0_rd_addr_dp   <= i0_rd_addr_id;
      i0_rs1_addr_dp  <= i0_rs1_addr_id;
      i0_rs2_addr_dp  <= i0_rs2_addr_id;
      i0_imm_dp       <= i0_imm_id;
      i0_rs1_data_dp  <= i0_rs1_data_id;
      i0_rs2_data_dp  <= i0_rs2_data_id;
      i0_pc_dp        <= i0_pc_id;

      i1_valid_dp     <= i1_valid_id;
      i1_lane_sel_dp  <= i1_lane_sel_id;
      i1_reg_write_dp <= i1_reg_write_id;
      i1_rs1_use_dp   <= i1_rs1_use_id;
      i1_rs2_use_dp   <= i1_rs2_use_id;
      spec1_en_dp     <= spec1_en_id;
      i1_state_dp     <= i1_state_id;
      i1_opcode_dp    <= i1_opcode_id;
      i1_funct3_dp    <= i1_funct3_id;
      i1_funct7_dp    <= i1_funct7_id;
      i1_rd_addr_dp   <= i1_rd_addr_id;
      i1_rs1_addr_dp  <= i1_rs1_addr_id;
      i1_rs2_addr_dp  <= i1_rs2_addr_id;
      i1_imm_dp       <= i1_imm_id;
      i1_rs1_data_dp  <= i1_rs1_data_id;
      i1_rs2_data_dp  <= i1_rs2_data_id;
      i1_pc_dp        <= i1_pc_id;
    end
  end

endmodule
