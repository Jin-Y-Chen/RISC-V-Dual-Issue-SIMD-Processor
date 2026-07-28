`timescale 1ns / 1ps

// Directed smoke: wakeup-select-issue with dispatch bypass.
// Unused sources are p0. Ready dispatch can issue same cycle (no RS alloc).
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
import rv_dis_pkg::*;

module reservation_station_tb;
  logic clk, rst_n, enable, flush;

  logic      rob_valid_dp  [2];
  logic      lane_sel_dp   [2];
  logic      spec_en_dp    [2];
  opcode_t   opcode_dp     [2];
  funct3_t   funct3_dp     [2];
  funct7_t   funct7_dp     [2];
  prf_addr_t ps1_tag_dp    [2];
  prf_addr_t ps2_tag_dp    [2];
  logic      tag1_valid_dp [2];
  logic      tag2_valid_dp [2];
  prf_addr_t rob_tag_dp    [2];
  word_t     imm_dp        [2];
  word_t     pc_dp         [2];

  logic      wb_en         [2];
  prf_addr_t rob_tag_wb    [2];
  logic      issue_en, stall_dp;

  prf_addr_t ps1_prf       [2];
  prf_addr_t ps2_prf       [2];

  logic      rob_valid     [2];
  logic      lane_sel      [2];
  opcode_t   opcode        [2];
  funct3_t   funct3        [2];
  funct7_t   funct7        [2];
  prf_addr_t rob_tag       [2];
  word_t     imm           [2];
  word_t     pc            [2];

  reservation_station dut (.*);

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic clear_dispatch;
    foreach (rob_valid_dp[i]) begin
      rob_valid_dp[i]  = 0;
      lane_sel_dp[i]   = 0;
      spec_en_dp[i]    = 0;
      opcode_dp[i]     = '0;
      funct3_dp[i]     = '0;
      funct7_dp[i]     = '0;
      ps1_tag_dp[i]    = '0;
      ps2_tag_dp[i]    = '0;
      tag1_valid_dp[i] = 0;
      tag2_valid_dp[i] = 0;
      rob_tag_dp[i]    = '0;
      imm_dp[i]        = '0;
      pc_dp[i]         = '0;
    end
  endtask

  task automatic drive_pair(input prf_addr_t prd0, input prf_addr_t prd1);
    rob_valid_dp[0] = 1;
    opcode_dp[0]    = OPC_OP;
    rob_tag_dp[0]   = prd0;  // non-zero ⇒ reg_write
    spec_en_dp[0]   = 0;
    rob_valid_dp[1] = 1;
    opcode_dp[1]    = OPC_OP;
    rob_tag_dp[1]   = prd1;
    spec_en_dp[1]   = 0;
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
    foreach (wb_en[i]) begin
      wb_en[i]      = 0;
      rob_tag_wb[i] = '0;
    end
    clear_dispatch();

    repeat (2) @(negedge clk);
    rst_n = 1;
    @(posedge clk);

    // Same-cycle dispatch bypass: ready pair issues without waiting in RS.
    drive_pair(6'd32, 6'd33);
    ps1_tag_dp[0] = 6'd1;
    tag1_valid_dp[0] = 1;
    ps2_tag_dp[1] = 6'd2;
    tag2_valid_dp[1] = 1;
    #1;
    if (!rob_valid[0] || !rob_valid[1])
      $error("ready dispatch did not dual-issue (bypass)");
    if (rob_tag[0] != 6'd32 || rob_tag[1] != 6'd33)
      $error("bypass issue order is incorrect");
    commit_and_sample();

    clear_dispatch();
    commit_and_sample();

    // Producer bypasses; dependent consumer waits in RS until WB.
    @(posedge clk);
    drive_pair(6'd34, 6'd35);
    ps1_tag_dp[1] = 6'd34;
    tag1_valid_dp[1] = 1;
    #1;
    if (!rob_valid[0] || (rob_tag[0] != 6'd34))
      $error("producer did not bypass-issue");
    if (rob_valid[1])
      $error("dependent consumer issued before producer writeback");
    commit_and_sample();

    clear_dispatch();
    commit_and_sample();

    wb_en[0]      = 1;
    rob_tag_wb[0] = 6'd34;
    #1;
    if (!rob_valid[0] || (rob_tag[0] != 6'd35))
      $error("writeback tag did not wake dependent consumer");
    @(negedge clk);
    #1;
    wb_en[0] = 0;

    flush = 1;
    @(negedge clk);
    #1;
    flush = 0;
    issue_en = 0;

    // Fill all 16 ways (8 dual inserts, no issue), then overflow.
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
