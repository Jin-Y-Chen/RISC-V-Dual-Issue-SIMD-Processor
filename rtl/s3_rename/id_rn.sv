`timescale 1ns / 1ps

import rv_dis_pkg::*;

// ID/RN pipeline register — decode bundle latched on posedge before rename core.
// stall_id from rename holds this register; flush clears it.
// Latches control/data addresses only (no GPR operand data — RF is later).
// Also carries branch_map and BHT state for later stages.
module id_rn (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls (stage)
  input  logic        flush,
  input  logic        stall,

  // internal controls (I0) — from decode / IF-ID
  input  logic        i0_valid_id,
  input  logic        i0_lane_sel_id,
  input  logic        i0_reg_write_id,
  input  logic        i0_rs1_use_id,
  input  logic        i0_rs2_use_id,
  input  br_state_t   i0_state_id,

  // internal controls (I1)
  input  logic        i1_valid_id,
  input  logic        i1_lane_sel_id,
  input  logic        i1_reg_write_id,
  input  logic        i1_rs1_use_id,
  input  logic        i1_rs2_use_id,
  input  br_state_t   i1_state_id,

  input  br_map_t     br_map_id,

  // input data (I0) — arch addresses / immediate / PC
  input  opcode_t     i0_opcode_id,
  input  funct3_t     i0_funct3_id,
  input  funct7_t     i0_funct7_id,
  input  gpr_addr_t   i0_rd_id,
  input  gpr_addr_t   i0_rs1_id,
  input  gpr_addr_t   i0_rs2_id,
  input  word_t       i0_imm_id,
  input  word_t       i0_pc_id,

  // input data (I1)
  input  opcode_t     i1_opcode_id,
  input  funct3_t     i1_funct3_id,
  input  funct7_t     i1_funct7_id,
  input  gpr_addr_t   i1_rd_id,
  input  gpr_addr_t   i1_rs1_id,
  input  gpr_addr_t   i1_rs2_id,
  input  word_t       i1_imm_id,
  input  word_t       i1_pc_id,

  // output controls (I0) → rename_core_struct
  output logic        i0_valid_rn,
  output logic        i0_lane_sel_rn,
  output logic        i0_reg_write_rn,
  output logic        i0_rs1_use_rn,
  output logic        i0_rs2_use_rn,
  output br_state_t   i0_state_rn,

  // output controls (I1)
  output logic        i1_valid_rn,
  output logic        i1_lane_sel_rn,
  output logic        i1_reg_write_rn,
  output logic        i1_rs1_use_rn,
  output logic        i1_rs2_use_rn,
  output br_state_t   i1_state_rn,

  output br_map_t     br_map_rn,

  // output data (I0)
  output opcode_t     i0_opcode_rn,
  output funct3_t     i0_funct3_rn,
  output funct7_t     i0_funct7_rn,
  output gpr_addr_t   i0_rd_rn,
  output gpr_addr_t   i0_rs1_rn,
  output gpr_addr_t   i0_rs2_rn,
  output word_t       i0_imm_rn,
  output word_t       i0_pc_rn,

  // output data (I1)
  output opcode_t     i1_opcode_rn,
  output funct3_t     i1_funct3_rn,
  output funct7_t     i1_funct7_rn,
  output gpr_addr_t   i1_rd_rn,
  output gpr_addr_t   i1_rs1_rn,
  output gpr_addr_t   i1_rs2_rn,
  output word_t       i1_imm_rn,
  output word_t       i1_pc_rn
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i0_valid_rn     <= 1'b0;
      i0_lane_sel_rn  <= 1'b0;
      i0_reg_write_rn <= 1'b0;
      i0_rs1_use_rn   <= 1'b0;
      i0_rs2_use_rn   <= 1'b0;
      i0_state_rn     <= '0;
      i0_opcode_rn    <= '0;
      i0_funct3_rn    <= '0;
      i0_funct7_rn    <= '0;
      i0_rd_rn        <= '0;
      i0_rs1_rn       <= '0;
      i0_rs2_rn       <= '0;
      i0_imm_rn       <= '0;
      i0_pc_rn        <= '0;

      i1_valid_rn     <= 1'b0;
      i1_lane_sel_rn  <= 1'b0;
      i1_reg_write_rn <= 1'b0;
      i1_rs1_use_rn   <= 1'b0;
      i1_rs2_use_rn   <= 1'b0;
      i1_state_rn     <= '0;
      i1_opcode_rn    <= '0;
      i1_funct3_rn    <= '0;
      i1_funct7_rn    <= '0;
      i1_rd_rn        <= '0;
      i1_rs1_rn       <= '0;
      i1_rs2_rn       <= '0;
      i1_imm_rn       <= '0;
      i1_pc_rn        <= '0;
      br_map_rn       <= BR_MAP_NONE;
    end else if (flush) begin
      i0_valid_rn     <= 1'b0;
      i0_lane_sel_rn  <= 1'b0;
      i0_reg_write_rn <= 1'b0;
      i0_rs1_use_rn   <= 1'b0;
      i0_rs2_use_rn   <= 1'b0;
      i0_state_rn     <= '0;
      i0_opcode_rn    <= '0;
      i0_funct3_rn    <= '0;
      i0_funct7_rn    <= '0;
      i0_rd_rn        <= '0;
      i0_rs1_rn       <= '0;
      i0_rs2_rn       <= '0;
      i0_imm_rn       <= '0;
      i0_pc_rn        <= '0;

      i1_valid_rn     <= 1'b0;
      i1_lane_sel_rn  <= 1'b0;
      i1_reg_write_rn <= 1'b0;
      i1_rs1_use_rn   <= 1'b0;
      i1_rs2_use_rn   <= 1'b0;
      i1_state_rn     <= '0;
      i1_opcode_rn    <= '0;
      i1_funct3_rn    <= '0;
      i1_funct7_rn    <= '0;
      i1_rd_rn        <= '0;
      i1_rs1_rn       <= '0;
      i1_rs2_rn       <= '0;
      i1_imm_rn       <= '0;
      i1_pc_rn        <= '0;
      br_map_rn       <= BR_MAP_NONE;
    end else if (enable && !stall) begin
      i0_valid_rn     <= i0_valid_id;
      i0_lane_sel_rn  <= i0_lane_sel_id;
      i0_reg_write_rn <= i0_reg_write_id;
      i0_rs1_use_rn   <= i0_rs1_use_id;
      i0_rs2_use_rn   <= i0_rs2_use_id;
      i0_state_rn     <= i0_state_id;
      i0_opcode_rn    <= i0_opcode_id;
      i0_funct3_rn    <= i0_funct3_id;
      i0_funct7_rn    <= i0_funct7_id;
      i0_rd_rn        <= i0_rd_id;
      i0_rs1_rn       <= i0_rs1_id;
      i0_rs2_rn       <= i0_rs2_id;
      i0_imm_rn       <= i0_imm_id;
      i0_pc_rn        <= i0_pc_id;

      i1_valid_rn     <= i1_valid_id;
      i1_lane_sel_rn  <= i1_lane_sel_id;
      i1_reg_write_rn <= i1_reg_write_id;
      i1_rs1_use_rn   <= i1_rs1_use_id;
      i1_rs2_use_rn   <= i1_rs2_use_id;
      i1_state_rn     <= i1_state_id;
      i1_opcode_rn    <= i1_opcode_id;
      i1_funct3_rn    <= i1_funct3_id;
      i1_funct7_rn    <= i1_funct7_id;
      i1_rd_rn        <= i1_rd_id;
      i1_rs1_rn       <= i1_rs1_id;
      i1_rs2_rn       <= i1_rs2_id;
      i1_imm_rn       <= i1_imm_id;
      i1_pc_rn        <= i1_pc_id;
      br_map_rn       <= br_map_id;
    end
  end

endmodule
