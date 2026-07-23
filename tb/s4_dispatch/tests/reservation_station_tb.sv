`timescale 1ns / 1ps

import rv_dis_pkg::*;

module reservation_station_tb;
  logic clk, rst_n, enable, flush;
  logic i0_valid_dp, i0_lane_sel_dp, i0_reg_write_dp;
  logic i0_rs1_use_dp, i0_rs2_use_dp;
  opcode_t i0_opcode_dp;
  funct3_t i0_funct3_dp;
  funct7_t i0_funct7_dp;
  prf_addr_t i0_ps1_dp, i0_ps2_dp, i0_prd_dp;
  prf_addr_t i0_rob_idx_dp;
  word_t i0_imm_dp, i0_pc_dp, i0_ps1_data_dp, i0_ps2_data_dp;

  logic i1_valid_dp, i1_lane_sel_dp, i1_reg_write_dp;
  logic i1_rs1_use_dp, i1_rs2_use_dp;
  opcode_t i1_opcode_dp;
  funct3_t i1_funct3_dp;
  funct7_t i1_funct7_dp;
  prf_addr_t i1_ps1_dp, i1_ps2_dp, i1_prd_dp;
  prf_addr_t i1_rob_idx_dp;
  word_t i1_imm_dp, i1_pc_dp, i1_ps1_data_dp, i1_ps2_data_dp;

  logic wb0_en, wb1_en;
  prf_addr_t wb0_prd, wb1_prd;
  word_t wb0_data, wb1_data;
  logic issue0_ready, issue1_ready, stall_dp;
  logic [2:0] occupancy;

  logic i0_valid_ex, i0_lane_sel_ex, i0_reg_write_ex;
  opcode_t i0_opcode_ex;
  funct3_t i0_funct3_ex;
  funct7_t i0_funct7_ex;
  prf_addr_t i0_ps1_ex, i0_ps2_ex, i0_prd_ex;
  prf_addr_t i0_rob_idx_ex;
  word_t i0_imm_ex, i0_pc_ex, i0_rs1_data_ex, i0_rs2_data_ex;

  logic i1_valid_ex, i1_lane_sel_ex, i1_reg_write_ex;
  opcode_t i1_opcode_ex;
  funct3_t i1_funct3_ex;
  funct7_t i1_funct7_ex;
  prf_addr_t i1_ps1_ex, i1_ps2_ex, i1_prd_ex;
  prf_addr_t i1_rob_idx_ex;
  word_t i1_imm_ex, i1_pc_ex, i1_rs1_data_ex, i1_rs2_data_ex;

  reservation_station #(.DEPTH(4)) dut (.*);

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic clear_dispatch;
    i0_valid_dp = 0; i0_lane_sel_dp = 0; i0_reg_write_dp = 0;
    i0_rs1_use_dp = 0; i0_rs2_use_dp = 0;
    i0_opcode_dp = '0; i0_funct3_dp = '0; i0_funct7_dp = '0;
    i0_ps1_dp = '0; i0_ps2_dp = '0; i0_prd_dp = '0;
    i0_rob_idx_dp = '0; i0_imm_dp = '0; i0_pc_dp = '0;
    i0_ps1_data_dp = '0; i0_ps2_data_dp = '0;

    i1_valid_dp = 0; i1_lane_sel_dp = 0; i1_reg_write_dp = 0;
    i1_rs1_use_dp = 0; i1_rs2_use_dp = 0;
    i1_opcode_dp = '0; i1_funct3_dp = '0; i1_funct7_dp = '0;
    i1_ps1_dp = '0; i1_ps2_dp = '0; i1_prd_dp = '0;
    i1_rob_idx_dp = '0; i1_imm_dp = '0; i1_pc_dp = '0;
    i1_ps1_data_dp = '0; i1_ps2_data_dp = '0;
  endtask

  task automatic drive_pair(
    input prf_addr_t prd0,
    input prf_addr_t prd1,
    input prf_addr_t  rob0,
    input prf_addr_t  rob1
  );
    i0_valid_dp = 1; i0_reg_write_dp = 1; i0_opcode_dp = OPC_OP;
    i0_prd_dp = prd0; i0_rob_idx_dp = rob0;
    i1_valid_dp = 1; i1_reg_write_dp = 1; i1_opcode_dp = OPC_OP;
    i1_prd_dp = prd1; i1_rob_idx_dp = rob1;
  endtask

  initial begin
    rst_n = 0;
    enable = 1;
    flush = 0;
    issue0_ready = 1;
    issue1_ready = 1;
    wb0_en = 0; wb1_en = 0;
    wb0_prd = '0; wb1_prd = '0;
    wb0_data = '0; wb1_data = '0;
    clear_dispatch();

    repeat (2) @(posedge clk);
    rst_n = 1;

    // Independent pair issues together in age order.
    @(negedge clk);
    drive_pair(6'd32, 6'd33, 6'd32, 6'd33);
    @(posedge clk);
    #1;
    if (!i0_valid_ex || !i1_valid_ex)
      $error("independent pair did not dual issue");
    if (i0_rob_idx_ex != 6'd32 || i1_rob_idx_ex != 6'd33)
      $error("oldest-ready issue order is incorrect");

    @(negedge clk);
    clear_dispatch();
    @(posedge clk);
    #1;

    // I1 waits for I0's physical destination and wakes from WB.
    @(negedge clk);
    drive_pair(6'd34, 6'd35, 6'd34, 6'd35);
    i1_rs1_use_dp = 1;
    i1_ps1_dp = 6'd34;
    @(posedge clk);
    #1;
    if (!i0_valid_ex || (i0_rob_idx_ex != 6'd34))
      $error("producer did not issue");
    if (i1_valid_ex)
      $error("dependent consumer issued before producer writeback");

    @(negedge clk);
    clear_dispatch();
    @(posedge clk);
    #1;
    if (i0_valid_ex || i1_valid_ex)
      $error("consumer became ready without writeback");

    @(negedge clk);
    wb0_en = 1;
    wb0_prd = 6'd34;
    wb0_data = 32'h1234_5678;
    #1;
    if (!i0_valid_ex || (i0_rob_idx_ex != 6'd35))
      $error("writeback did not wake dependent consumer");
    if (i0_rs1_data_ex != 32'h1234_5678)
      $error("writeback data was not forwarded to consumer");
    @(posedge clk);
    #1;
    wb0_en = 0;

    // Fill the station and verify atomic dispatch backpressure.
    flush = 1;
    @(posedge clk);
    #1;
    flush = 0;
    issue0_ready = 0;
    issue1_ready = 0;

    @(negedge clk);
    drive_pair(6'd40, 6'd41, 4'd4, 4'd5);
    @(posedge clk);
    @(negedge clk);
    drive_pair(6'd42, 6'd43, 4'd6, 4'd7);
    @(posedge clk);
    #1;
    if (occupancy != 3'd4)
      $error("station occupancy expected 4, got %0d", occupancy);

    @(negedge clk);
    drive_pair(6'd44, 6'd45, 4'd8, 4'd9);
    #1;
    if (!stall_dp)
      $error("full station did not backpressure dispatch");

    $display("OK reservation_station_tb");
    $finish;
  end
endmodule
