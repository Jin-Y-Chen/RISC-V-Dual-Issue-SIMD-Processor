`timescale 1ns / 1ps

import rv_dis_pkg::*;

// ID/RN pipeline register — decode bundle latched on posedge before rename.
// Pass-through flip-flops only (no NOP mux). Valid rides with the bundle.
// stall holds; flush/rst clear. No GPR operand data.
module id_rn (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall,

  input  logic        i0_valid_id,
  input  logic        i0_lane_sel_id,
  input  logic        i0_reg_write_id,
  input  logic        i0_store_en_id,
  input  logic        i0_rs1_use_id,
  input  logic        i0_rs2_use_id,
  input  logic        spec0_en_id,
  input  logic        i1_valid_id,
  input  logic        i1_lane_sel_id,
  input  logic        i1_reg_write_id,
  input  logic        i1_store_en_id,
  input  logic        i1_rs1_use_id,
  input  logic        i1_rs2_use_id,
  input  logic        spec1_en_id,

  input  opcode_t     i0_opcode_id,
  input  funct3_t     i0_funct3_id,
  input  funct7_t     i0_funct7_id,
  input  gpr_addr_t   i0_rd_addr_id,
  input  gpr_addr_t   i0_rs1_addr_id,
  input  gpr_addr_t   i0_rs2_addr_id,
  input  word_t       i0_imm_id,
  input  word_t       i0_pc_id,

  input  opcode_t     i1_opcode_id,
  input  funct3_t     i1_funct3_id,
  input  funct7_t     i1_funct7_id,
  input  gpr_addr_t   i1_rd_addr_id,
  input  gpr_addr_t   i1_rs1_addr_id,
  input  gpr_addr_t   i1_rs2_addr_id,
  input  word_t       i1_imm_id,
  input  word_t       i1_pc_id,

  output logic        i0_valid_rn,
  output logic        i0_lane_sel_rn,
  output logic        i0_reg_write_rn,
  output logic        i0_store_en_rn,
  output logic        i0_rs1_use_rn,
  output logic        i0_rs2_use_rn,
  output logic        spec0_en_rn,
  output logic        i1_valid_rn,
  output logic        i1_lane_sel_rn,
  output logic        i1_reg_write_rn,
  output logic        i1_store_en_rn,
  output logic        i1_rs1_use_rn,
  output logic        i1_rs2_use_rn,
  output logic        spec1_en_rn,

  output opcode_t     i0_opcode_rn,
  output funct3_t     i0_funct3_rn,
  output funct7_t     i0_funct7_rn,
  output gpr_addr_t   i0_rd_addr_rn,
  output gpr_addr_t   i0_rs1_addr_rn,
  output gpr_addr_t   i0_rs2_addr_rn,
  output word_t       i0_imm_rn,
  output word_t       i0_pc_rn,

  output opcode_t     i1_opcode_rn,
  output funct3_t     i1_funct3_rn,
  output funct7_t     i1_funct7_rn,
  output gpr_addr_t   i1_rd_addr_rn,
  output gpr_addr_t   i1_rs1_addr_rn,
  output gpr_addr_t   i1_rs2_addr_rn,
  output word_t       i1_imm_rn,
  output word_t       i1_pc_rn
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      i0_valid_rn     <= 1'b0;
      i0_lane_sel_rn  <= 1'b0;
      i0_reg_write_rn <= 1'b0;
      i0_store_en_rn  <= 1'b0;
      i0_rs1_use_rn   <= 1'b0;
      i0_rs2_use_rn   <= 1'b0;
      spec0_en_rn     <= 1'b0;
      i0_opcode_rn    <= '0;
      i0_funct3_rn    <= '0;
      i0_funct7_rn    <= '0;
      i0_rd_addr_rn   <= '0;
      i0_rs1_addr_rn  <= '0;
      i0_rs2_addr_rn  <= '0;
      i0_imm_rn       <= '0;
      i0_pc_rn        <= '0;

      i1_valid_rn     <= 1'b0;
      i1_lane_sel_rn  <= 1'b0;
      i1_reg_write_rn <= 1'b0;
      i1_store_en_rn  <= 1'b0;
      i1_rs1_use_rn   <= 1'b0;
      i1_rs2_use_rn   <= 1'b0;
      spec1_en_rn     <= 1'b0;
      i1_opcode_rn    <= '0;
      i1_funct3_rn    <= '0;
      i1_funct7_rn    <= '0;
      i1_rd_addr_rn   <= '0;
      i1_rs1_addr_rn  <= '0;
      i1_rs2_addr_rn  <= '0;
      i1_imm_rn       <= '0;
      i1_pc_rn        <= '0;
    end else if (enable && !stall) begin
      i0_valid_rn     <= i0_valid_id;
      i0_lane_sel_rn  <= i0_lane_sel_id;
      i0_reg_write_rn <= i0_reg_write_id;
      i0_store_en_rn  <= i0_store_en_id;
      i0_rs1_use_rn   <= i0_rs1_use_id;
      i0_rs2_use_rn   <= i0_rs2_use_id;
      spec0_en_rn     <= spec0_en_id;
      i0_opcode_rn    <= i0_opcode_id;
      i0_funct3_rn    <= i0_funct3_id;
      i0_funct7_rn    <= i0_funct7_id;
      i0_rd_addr_rn   <= i0_rd_addr_id;
      i0_rs1_addr_rn  <= i0_rs1_addr_id;
      i0_rs2_addr_rn  <= i0_rs2_addr_id;
      i0_imm_rn       <= i0_imm_id;
      i0_pc_rn        <= i0_pc_id;

      i1_valid_rn     <= i1_valid_id;
      i1_lane_sel_rn  <= i1_lane_sel_id;
      i1_reg_write_rn <= i1_reg_write_id;
      i1_store_en_rn  <= i1_store_en_id;
      i1_rs1_use_rn   <= i1_rs1_use_id;
      i1_rs2_use_rn   <= i1_rs2_use_id;
      spec1_en_rn     <= spec1_en_id;
      i1_opcode_rn    <= i1_opcode_id;
      i1_funct3_rn    <= i1_funct3_id;
      i1_funct7_rn    <= i1_funct7_id;
      i1_rd_addr_rn   <= i1_rd_addr_id;
      i1_rs1_addr_rn  <= i1_rs1_addr_id;
      i1_rs2_addr_rn  <= i1_rs2_addr_id;
      i1_imm_rn       <= i1_imm_id;
      i1_pc_rn        <= i1_pc_id;
    end
  end

endmodule
