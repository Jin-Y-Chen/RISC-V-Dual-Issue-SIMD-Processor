`timescale 1ns / 1ps

import rv_dis_pkg::*;

module rn_dp_tb;
  logic clk, rst_n, enable, flush, stall_dp, stall_rn;

  logic i0_valid_rn, i0_lane_sel_rn, i0_reg_write_rn, i0_spec_en_rn;
  logic i0_rs1_use_rn, i0_rs2_use_rn;
  opcode_t i0_opcode_rn;
  funct3_t i0_funct3_rn;
  funct7_t i0_funct7_rn;
  gpr_addr_t i0_rd_addr_rn;
  prf_addr_t i0_ps1_rn, i0_ps2_rn, i0_prd_rn;
  prf_addr_t i0_rob_idx_rn;
  word_t i0_imm_rn, i0_pc_rn;

  logic i1_valid_rn, i1_lane_sel_rn, i1_reg_write_rn, i1_spec_en_rn;
  logic i1_rs1_use_rn, i1_rs2_use_rn;
  opcode_t i1_opcode_rn;
  funct3_t i1_funct3_rn;
  funct7_t i1_funct7_rn;
  gpr_addr_t i1_rd_addr_rn;
  prf_addr_t i1_ps1_rn, i1_ps2_rn, i1_prd_rn;
  prf_addr_t i1_rob_idx_rn;
  word_t i1_imm_rn, i1_pc_rn;

  logic i0_valid_dp, i0_lane_sel_dp, i0_reg_write_dp, i0_spec_en_dp;
  logic i0_rs1_use_dp, i0_rs2_use_dp;
  opcode_t i0_opcode_dp;
  funct3_t i0_funct3_dp;
  funct7_t i0_funct7_dp;
  gpr_addr_t i0_rd_addr_dp;
  prf_addr_t i0_ps1_dp, i0_ps2_dp, i0_prd_dp;
  prf_addr_t i0_rob_idx_dp;
  word_t i0_imm_dp, i0_pc_dp;

  logic i1_valid_dp, i1_lane_sel_dp, i1_reg_write_dp, i1_spec_en_dp;
  logic i1_rs1_use_dp, i1_rs2_use_dp;
  opcode_t i1_opcode_dp;
  funct3_t i1_funct3_dp;
  funct7_t i1_funct7_dp;
  gpr_addr_t i1_rd_addr_dp;
  prf_addr_t i1_ps1_dp, i1_ps2_dp, i1_prd_dp;
  prf_addr_t i1_rob_idx_dp;
  word_t i1_imm_dp, i1_pc_dp;

  rn_dp dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 0; enable = 1; flush = 0; stall_dp = 0;
    i0_valid_rn = 0; i0_lane_sel_rn = 0; i0_reg_write_rn = 0; i0_spec_en_rn = 0;
    i0_rs1_use_rn = 0; i0_rs2_use_rn = 0;
    i0_opcode_rn = '0; i0_funct3_rn = '0; i0_funct7_rn = '0;
    i0_rd_addr_rn = '0; i0_ps1_rn = '0; i0_ps2_rn = '0;
    i0_prd_rn = '0; i0_rob_idx_rn = '0; i0_imm_rn = '0; i0_pc_rn = '0;
    i1_valid_rn = 0; i1_lane_sel_rn = 0; i1_reg_write_rn = 0; i1_spec_en_rn = 0;
    i1_rs1_use_rn = 0; i1_rs2_use_rn = 0;
    i1_opcode_rn = '0; i1_funct3_rn = '0; i1_funct7_rn = '0;
    i1_rd_addr_rn = '0; i1_ps1_rn = '0; i1_ps2_rn = '0;
    i1_prd_rn = '0; i1_rob_idx_rn = '0; i1_imm_rn = '0; i1_pc_rn = '0;

    repeat (2) @(posedge clk);
    rst_n = 1;

    @(negedge clk);
    i0_valid_rn = 1; i0_reg_write_rn = 1; i0_opcode_rn = OPC_OP;
    i0_ps1_rn = 6'd2; i0_ps2_rn = 6'd3; i0_prd_rn = 6'd32;
    i0_rob_idx_rn = 6'd38; i0_pc_rn = 32'h100;  // p38 = {1, flat 6}
    i1_valid_rn = 1; i1_lane_sel_rn = 1; i1_opcode_rn = OPC_LOAD;
    i1_ps1_rn = 6'd4; i1_prd_rn = 6'd33;
    i1_rob_idx_rn = 6'd39; i1_pc_rn = 32'h104;  // p39 = {1, flat 7}
    @(posedge clk);
    #1;
    if (!i0_valid_dp || !i1_valid_dp ||
        i0_prd_dp != 6'd32 || i1_prd_dp != 6'd33)
      $error("renamed bundle was not captured");

    stall_dp = 1;
    i0_prd_rn = 6'd40;
    i1_prd_rn = 6'd41;
    @(posedge clk);
    #1;
    if (!stall_rn || i0_prd_dp != 6'd32 || i1_prd_dp != 6'd33)
      $error("stalled RN/DP bundle was not held");

    flush = 1;
    @(posedge clk);
    #1;
    if (i0_valid_dp || i1_valid_dp)
      $error("flush did not invalidate RN/DP");

    $display("OK rn_dp_tb");
    $finish;
  end
endmodule
