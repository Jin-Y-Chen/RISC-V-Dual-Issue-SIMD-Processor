`timescale 1ns / 1ps

// RN/DP pipeline register. Holds a complete dual-issue renamed bundle while
// dispatch is back-pressured by the reservation station.
import rv_dis_pkg::*;

module rn_dp (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall_dp,
  output logic        stall_rn,

  input  logic        i0_valid_rn,
  input  logic        i0_lane_sel_rn,
  input  logic        i0_reg_write_rn,
  input  logic        i0_rs1_use_rn,
  input  logic        i0_rs2_use_rn,
  input  opcode_t     i0_opcode_rn,
  input  funct3_t     i0_funct3_rn,
  input  funct7_t     i0_funct7_rn,
  input  gpr_addr_t   i0_rd_addr_rn,
  input  prf_addr_t   i0_ps1_rn,
  input  prf_addr_t   i0_ps2_rn,
  input  prf_addr_t   i0_prd_rn,
  input  prf_addr_t    i0_rob_idx_rn,
  input  word_t       i0_imm_rn,
  input  word_t       i0_pc_rn,

  input  logic        i1_valid_rn,
  input  logic        i1_lane_sel_rn,
  input  logic        i1_reg_write_rn,
  input  logic        i1_rs1_use_rn,
  input  logic        i1_rs2_use_rn,
  input  opcode_t     i1_opcode_rn,
  input  funct3_t     i1_funct3_rn,
  input  funct7_t     i1_funct7_rn,
  input  gpr_addr_t   i1_rd_addr_rn,
  input  prf_addr_t   i1_ps1_rn,
  input  prf_addr_t   i1_ps2_rn,
  input  prf_addr_t   i1_prd_rn,
  input  prf_addr_t    i1_rob_idx_rn,
  input  word_t       i1_imm_rn,
  input  word_t       i1_pc_rn,

  output logic        i0_valid_dp,
  output logic        i0_lane_sel_dp,
  output logic        i0_reg_write_dp,
  output logic        i0_rs1_use_dp,
  output logic        i0_rs2_use_dp,
  output opcode_t     i0_opcode_dp,
  output funct3_t     i0_funct3_dp,
  output funct7_t     i0_funct7_dp,
  output gpr_addr_t   i0_rd_addr_dp,
  output prf_addr_t   i0_ps1_dp,
  output prf_addr_t   i0_ps2_dp,
  output prf_addr_t   i0_prd_dp,
  output prf_addr_t    i0_rob_idx_dp,
  output word_t       i0_imm_dp,
  output word_t       i0_pc_dp,

  output logic        i1_valid_dp,
  output logic        i1_lane_sel_dp,
  output logic        i1_reg_write_dp,
  output logic        i1_rs1_use_dp,
  output logic        i1_rs2_use_dp,
  output opcode_t     i1_opcode_dp,
  output funct3_t     i1_funct3_dp,
  output funct7_t     i1_funct7_dp,
  output gpr_addr_t   i1_rd_addr_dp,
  output prf_addr_t   i1_ps1_dp,
  output prf_addr_t   i1_ps2_dp,
  output prf_addr_t   i1_prd_dp,
  output prf_addr_t    i1_rob_idx_dp,
  output word_t       i1_imm_dp,
  output word_t       i1_pc_dp
);

  assign stall_rn = stall_dp;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      i0_valid_dp     <= 1'b0;
      i0_lane_sel_dp  <= 1'b0;
      i0_reg_write_dp <= 1'b0;
      i0_rs1_use_dp   <= 1'b0;
      i0_rs2_use_dp   <= 1'b0;
      i0_opcode_dp    <= '0;
      i0_funct3_dp    <= '0;
      i0_funct7_dp    <= '0;
      i0_rd_addr_dp   <= '0;
      i0_ps1_dp       <= '0;
      i0_ps2_dp       <= '0;
      i0_prd_dp       <= '0;
      i0_rob_idx_dp   <= '0;
      i0_imm_dp       <= '0;
      i0_pc_dp        <= '0;

      i1_valid_dp     <= 1'b0;
      i1_lane_sel_dp  <= 1'b0;
      i1_reg_write_dp <= 1'b0;
      i1_rs1_use_dp   <= 1'b0;
      i1_rs2_use_dp   <= 1'b0;
      i1_opcode_dp    <= '0;
      i1_funct3_dp    <= '0;
      i1_funct7_dp    <= '0;
      i1_rd_addr_dp   <= '0;
      i1_ps1_dp       <= '0;
      i1_ps2_dp       <= '0;
      i1_prd_dp       <= '0;
      i1_rob_idx_dp   <= '0;
      i1_imm_dp       <= '0;
      i1_pc_dp        <= '0;
    end else if (enable && !stall_dp) begin
      i0_valid_dp     <= i0_valid_rn;
      i0_lane_sel_dp  <= i0_lane_sel_rn;
      i0_reg_write_dp <= i0_reg_write_rn;
      i0_rs1_use_dp   <= i0_rs1_use_rn;
      i0_rs2_use_dp   <= i0_rs2_use_rn;
      i0_opcode_dp    <= i0_opcode_rn;
      i0_funct3_dp    <= i0_funct3_rn;
      i0_funct7_dp    <= i0_funct7_rn;
      i0_rd_addr_dp   <= i0_rd_addr_rn;
      i0_ps1_dp       <= i0_ps1_rn;
      i0_ps2_dp       <= i0_ps2_rn;
      i0_prd_dp       <= i0_prd_rn;
      i0_rob_idx_dp   <= i0_rob_idx_rn;
      i0_imm_dp       <= i0_imm_rn;
      i0_pc_dp        <= i0_pc_rn;

      i1_valid_dp     <= i1_valid_rn;
      i1_lane_sel_dp  <= i1_lane_sel_rn;
      i1_reg_write_dp <= i1_reg_write_rn;
      i1_rs1_use_dp   <= i1_rs1_use_rn;
      i1_rs2_use_dp   <= i1_rs2_use_rn;
      i1_opcode_dp    <= i1_opcode_rn;
      i1_funct3_dp    <= i1_funct3_rn;
      i1_funct7_dp    <= i1_funct7_rn;
      i1_rd_addr_dp   <= i1_rd_addr_rn;
      i1_ps1_dp       <= i1_ps1_rn;
      i1_ps2_dp       <= i1_ps2_rn;
      i1_prd_dp       <= i1_prd_rn;
      i1_rob_idx_dp   <= i1_rob_idx_rn;
      i1_imm_dp       <= i1_imm_rn;
      i1_pc_dp        <= i1_pc_rn;
    end
  end

endmodule
