`timescale 1ns / 1ps

import rv_dis_pkg::*;

module rn_dp_tb;
  logic clk, rst_n, enable, flush, stall_dp, stall_rn;

  logic      valid_rn     [2];
  logic      lane_sel_rn  [2];
  logic      spec_en_rn   [2];
  opcode_t   opcode_rn     [2];
  funct3_t   funct3_rn     [2];
  funct7_t   funct7_rn     [2];
  prf_addr_t ps1_rn        [2];
  prf_addr_t ps2_rn        [2];
  logic      tag1_valid_rn [2];
  logic      tag2_valid_rn [2];
  prf_addr_t prd_rn        [2];
  word_t     imm_rn        [2];
  word_t     pc_rn         [2];

  logic      valid_dp      [2];
  logic      lane_sel_dp   [2];
  logic      spec_en_dp    [2];
  opcode_t   opcode_dp     [2];
  funct3_t   funct3_dp     [2];
  funct7_t   funct7_dp     [2];
  prf_addr_t ps1_dp        [2];
  prf_addr_t ps2_dp        [2];
  logic      tag1_valid_dp [2];
  logic      tag2_valid_dp [2];
  prf_addr_t prd_dp        [2];
  word_t     imm_dp        [2];
  word_t     pc_dp         [2];

  rn_dp dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 0; enable = 1; flush = 0; stall_dp = 0;
    foreach (valid_rn[i]) begin
      valid_rn[i]     = 0;
      lane_sel_rn[i]  = 0;
      spec_en_rn[i]   = 0;
      opcode_rn[i]    = '0;
      funct3_rn[i]    = '0;
      funct7_rn[i]    = '0;
      ps1_rn[i]       = '0;
      ps2_rn[i]       = '0;
      tag1_valid_rn[i] = 0;
      tag2_valid_rn[i] = 0;
      prd_rn[i]       = '0;
      imm_rn[i]       = '0;
      pc_rn[i]        = '0;
    end

    repeat (2) @(posedge clk);
    rst_n = 1;

    @(negedge clk);
    valid_rn[0]      = 1;
    opcode_rn[0]     = OPC_OP;
    ps1_rn[0]        = 6'd2;
    ps2_rn[0]        = 6'd3;
    tag1_valid_rn[0] = 1;
    tag2_valid_rn[0] = 1;
    prd_rn[0]        = 6'd32;
    pc_rn[0]         = 32'h100;
    valid_rn[1]      = 1;
    lane_sel_rn[1]   = 1;
    opcode_rn[1]     = OPC_LOAD;
    ps1_rn[1]        = 6'd4;
    tag1_valid_rn[1] = 1;
    prd_rn[1]        = 6'd33;
    pc_rn[1]         = 32'h104;
    @(posedge clk);
    #1;
    if (!valid_dp[0] || !valid_dp[1] ||
        prd_dp[0] != 6'd32 || prd_dp[1] != 6'd33 ||
        !tag1_valid_dp[0] || !tag2_valid_dp[0] || !tag1_valid_dp[1])
      $error("renamed bundle was not captured");

    stall_dp = 1;
    prd_rn[0] = 6'd40;
    prd_rn[1] = 6'd41;
    @(posedge clk);
    #1;
    if (!stall_rn || prd_dp[0] != 6'd32 || prd_dp[1] != 6'd33)
      $error("stalled RN/DP bundle was not held");

    flush = 1;
    @(posedge clk);
    #1;
    if (valid_dp[0] || valid_dp[1])
      $error("flush did not invalidate RN/DP");

    $display("OK rn_dp_tb");
    $finish;
  end
endmodule
