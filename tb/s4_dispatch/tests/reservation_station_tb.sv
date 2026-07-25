`timescale 1ns / 1ps

// Directed smoke: RS issues tags/controls; bank updates on negedge (like ROB WB).
// Unused sources are p0.
import rv_dis_pkg::*;

module reservation_station_tb;
  logic clk, rst_n, enable, flush;
  logic i0_valid_dp, i0_lane_sel_dp, i0_reg_write_dp, i0_spec_en_dp;
  opcode_t i0_opcode_dp;
  funct3_t i0_funct3_dp;
  funct7_t i0_funct7_dp;
  prf_addr_t i0_ps1_dp, i0_ps2_dp, i0_prd_dp;
  word_t i0_imm_dp, i0_pc_dp;

  logic i1_valid_dp, i1_lane_sel_dp, i1_reg_write_dp, i1_spec_en_dp;
  opcode_t i1_opcode_dp;
  funct3_t i1_funct3_dp;
  funct7_t i1_funct7_dp;
  prf_addr_t i1_ps1_dp, i1_ps2_dp, i1_prd_dp;
  word_t i1_imm_dp, i1_pc_dp;

  logic wb0_en, wb1_en;
  prf_addr_t wb0_prd, wb1_prd;
  logic issue_en, stall_dp;

  logic i0_rs1_use_prf, i0_rs2_use_prf, i1_rs1_use_prf, i1_rs2_use_prf;
  prf_addr_t i0_ps1_prf, i0_ps2_prf, i1_ps1_prf, i1_ps2_prf;

  logic i0_valid_iss, i0_lane_sel_iss, i0_reg_write_iss;
  opcode_t i0_opcode_iss;
  funct3_t i0_funct3_iss;
  funct7_t i0_funct7_iss;
  prf_addr_t i0_ps1_iss, i0_ps2_iss, i0_prd_iss;
  word_t i0_imm_iss, i0_pc_iss;

  logic i1_valid_iss, i1_lane_sel_iss, i1_reg_write_iss;
  opcode_t i1_opcode_iss;
  funct3_t i1_funct3_iss;
  funct7_t i1_funct7_iss;
  prf_addr_t i1_ps1_iss, i1_ps2_iss, i1_prd_iss;
  word_t i1_imm_iss, i1_pc_iss;

  reservation_station dut (.*);

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic clear_dispatch;
    i0_valid_dp = 0; i0_lane_sel_dp = 0; i0_reg_write_dp = 0; i0_spec_en_dp = 0;
    i0_opcode_dp = '0; i0_funct3_dp = '0; i0_funct7_dp = '0;
    i0_ps1_dp = '0; i0_ps2_dp = '0; i0_prd_dp = '0;
    i0_imm_dp = '0; i0_pc_dp = '0;

    i1_valid_dp = 0; i1_lane_sel_dp = 0; i1_reg_write_dp = 0; i1_spec_en_dp = 0;
    i1_opcode_dp = '0; i1_funct3_dp = '0; i1_funct7_dp = '0;
    i1_ps1_dp = '0; i1_ps2_dp = '0; i1_prd_dp = '0;
    i1_imm_dp = '0; i1_pc_dp = '0;
  endtask

  task automatic drive_pair(input prf_addr_t prd0, input prf_addr_t prd1);
    i0_valid_dp = 1; i0_reg_write_dp = 1; i0_opcode_dp = OPC_OP;
    i0_prd_dp = prd0; i0_spec_en_dp = 0;
    i1_valid_dp = 1; i1_reg_write_dp = 1; i1_opcode_dp = OPC_OP;
    i1_prd_dp = prd1; i1_spec_en_dp = 0;
  endtask

  task automatic commit_and_sample;
    @(negedge clk);
    #1;
  endtask

  initial begin
    rst_n = 0;
    enable = 1;
    flush = 0;
    issue_en = 1;
    wb0_en = 0; wb1_en = 0;
    wb0_prd = '0; wb1_prd = '0;
    clear_dispatch();

    repeat (2) @(negedge clk);
    rst_n = 1;
    @(posedge clk);

    drive_pair(6'd32, 6'd33);
    i0_ps1_dp = 6'd1;
    i1_ps2_dp = 6'd2;
    commit_and_sample();
    if (!i0_valid_iss || !i1_valid_iss)
      $error("independent pair did not dual issue");
    if (i0_prd_iss != 6'd32 || i1_prd_iss != 6'd33)
      $error("oldest-ready issue order is incorrect");

    clear_dispatch();
    commit_and_sample();

    @(posedge clk);
    drive_pair(6'd34, 6'd35);
    i1_ps1_dp = 6'd34;
    commit_and_sample();
    if (!i0_valid_iss || (i0_prd_iss != 6'd34))
      $error("producer did not issue");
    if (i1_valid_iss)
      $error("dependent consumer issued before producer writeback");

    clear_dispatch();
    commit_and_sample();

    wb0_en = 1;
    wb0_prd = 6'd34;
    #1;
    if (!i0_valid_iss || (i0_prd_iss != 6'd35))
      $error("writeback tag did not wake dependent consumer");
    @(negedge clk);
    #1;
    wb0_en = 0;

    flush = 1;
    @(negedge clk);
    #1;
    flush = 0;
    issue_en = 0;

    // Fill all 16 ways (8 dual inserts), then overflow.
    for (int p = 0; p < 8; p++) begin
      @(posedge clk);
      drive_pair(prf_addr_t'(32 + 2 * p), prf_addr_t'(33 + 2 * p));
      @(negedge clk);
    end
    clear_dispatch();

    @(posedge clk);
    drive_pair(6'd48, 6'd49);
    #1;
    if (!stall_dp)
      $error("full station did not backpressure dispatch");

    $display("OK reservation_station_tb");
    $finish;
  end
endmodule
