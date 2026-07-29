`timescale 1ns / 1ps

// Directed smoke for issue_core_struct (RS + bypass + selector + PRF).
// Unused sources are p0. Ready dispatch can issue same cycle (no RS alloc).
import rv_dis_pkg::*;
import rs_pkg::*;

module reservation_station_tb;
  logic clk, rst_n, enable, flush_rs;
  logic path_en, path_sel;

  logic      rob_valid_dp  [2];
  logic      path_use_dp   [2];
  logic      lane_sel_dp   [2];
  opcode_t   opcode_dp     [2];
  funct3_t   funct3_dp     [2];
  funct7_t   funct7_dp     [2];
  prf_addr_t ps1_tag_dp    [2];
  prf_addr_t ps2_tag_dp    [2];
  prf_addr_t rob_tag_dp    [2];
  word_t     imm_dp        [2];
  word_t     pc_dp         [2];

  logic      wb_en         [2];
  prf_addr_t rob_tag_wb    [2];
  word_t     wb_data       [2];
  logic      stall_dp;

  logic      lane_sel      [2];
  opcode_t   opcode        [2];
  funct3_t   funct3        [2];
  funct7_t   funct7        [2];
  prf_addr_t rob_tag       [2];
  word_t     imm           [2];
  word_t     pc            [2];
  word_t     rs1_data      [2];
  word_t     rs2_data      [2];

  issue_core_struct dut (.*);

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic clear_dispatch;
    foreach (rob_valid_dp[i]) begin
      rob_valid_dp[i]  = 0;
      path_use_dp[i]   = 0;
      lane_sel_dp[i]   = 0;
      opcode_dp[i]     = '0;
      funct3_dp[i]     = '0;
      funct7_dp[i]     = '0;
      ps1_tag_dp[i]    = '0;
      ps2_tag_dp[i]    = '0;
      rob_tag_dp[i]    = '0;
      imm_dp[i]        = '0;
      pc_dp[i]         = '0;
    end
  endtask

  task automatic drive_pair(input prf_addr_t prd0, input prf_addr_t prd1);
    rob_valid_dp[0] = 1;
    opcode_dp[0]    = OPC_OP;
    rob_tag_dp[0]   = prd0;
    rob_valid_dp[1] = 1;
    opcode_dp[1]    = OPC_OP;
    rob_tag_dp[1]   = prd1;
  endtask

  task automatic commit_and_sample;
    @(negedge clk);
    #1;
  endtask

  initial begin
    rst_n = 0;
    enable = 1;
    flush_rs = 0;
    path_en = 0;
    path_sel = 0;
    foreach (wb_en[i]) begin
      wb_en[i]      = 0;
      rob_tag_wb[i] = '0;
      wb_data[i]    = '0;
    end
    clear_dispatch();

    repeat (2) @(negedge clk);
    rst_n = 1;
    @(posedge clk);

    // Same-cycle dispatch bypass: ready pair issues without waiting in RS.
    drive_pair(6'd32, 6'd33);
    ps1_tag_dp[0] = 6'd1;
    ps2_tag_dp[1] = 6'd2;
    #1;
    if ((rob_tag[0] == '0) || (rob_tag[1] == '0))
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
    #1;
    if ((rob_tag[0] != 6'd34))
      $error("producer did not bypass-issue");
    if (rob_tag[1] != '0)
      $error("dependent consumer issued before producer writeback");
    commit_and_sample();

    clear_dispatch();
    commit_and_sample();

    wb_en[0]      = 1;
    rob_tag_wb[0] = 6'd34;
    #1;
    if (rob_tag[0] != 6'd35)
      $error("writeback tag did not wake dependent consumer");
    @(negedge clk);
    #1;
    wb_en[0] = 0;

    // Queue one path0 entry and one path1 entry, then squash the losing path.
    @(posedge clk);
    drive_pair(6'd36, 6'd37);
    path_use_dp[1] = 1'b0;
    ps1_tag_dp[1]  = 6'd36;
    commit_and_sample();
    clear_dispatch();
    commit_and_sample();

    @(posedge clk);
    drive_pair(6'd38, 6'd39);
    path_use_dp[1] = 1'b1;
    ps1_tag_dp[1]  = 6'd38;
    commit_and_sample();
    clear_dispatch();
    commit_and_sample();

    begin
      int path0_count, path1_count;
      path0_count = 0;
      path1_count = 0;
      for (int w = 0; w < RS_WAYS; w++) begin
        if (dut.u_rs.bank_q[0][w].valid) begin
          if (dut.u_rs.bank_q[0][w].spec_en) path1_count++;
          else                               path0_count++;
        end
      end
      if (path0_count != 1 || path1_count != 1)
        $error("expected one queued entry on each path before selective squash");
    end

    path_en  = 1'b1;
    path_sel = 1'b1;
    @(negedge clk);
    #1;
    path_en = 1'b0;

    begin
      int path0_count, path1_count;
      path0_count = 0;
      path1_count = 0;
      for (int w = 0; w < RS_WAYS; w++) begin
        if (dut.u_rs.bank_q[0][w].valid) begin
          if (dut.u_rs.bank_q[0][w].spec_en) path1_count++;
          else                               path0_count++;
        end
      end
      if (path0_count != 0 || path1_count != 1)
        $error("selective squash did not keep only the winning path");
    end

    flush_rs = 1;
    @(negedge clk);
    #1;
    flush_rs = 0;

    // Bypass a producer so its dest is unready; dependents must enter the RS.
    @(posedge clk);
    drive_pair(6'd50, 6'd51);
    commit_and_sample();
    clear_dispatch();
    commit_and_sample();

    // Fill all 16 ways with unready pairs (8 dual stores), then overflow.
    for (int p = 0; p < 8; p++) begin
      @(posedge clk);
      drive_pair(prf_addr_t'(32 + 2 * p), prf_addr_t'(33 + 2 * p));
      ps1_tag_dp[0] = 6'd50;
      ps1_tag_dp[1] = 6'd50;
      @(negedge clk);
    end
    clear_dispatch();

    @(posedge clk);
    drive_pair(6'd48, 6'd49);
    ps1_tag_dp[0] = 6'd50;
    ps1_tag_dp[1] = 6'd50;
    #1;
    if (!stall_dp)
      $error("full station did not backpressure dispatch");

    $display("OK reservation_station_tb");
    $finish;
  end
endmodule
