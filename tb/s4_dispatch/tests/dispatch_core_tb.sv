`timescale 1ns / 1ps

// Integrated TB: reservation_station + physical_register via dispatch_core.
// No rename stubs: issued rename is RS nop; RS issue clears the way.
import rv_dis_pkg::*;
import rs_pkg::*;

`include "../../common/utils/tb_console.svh"

module dispatch_core_tb;

  localparam int CLK_PERIOD = 10;

  logic        clk, rst_n, enable, flush_rs;
  logic        path_en, path_sel;

  logic        rob_valid_dp [2];
  logic        path_use_dp  [2];
  logic        lane_sel_dp  [2];
  opcode_t     opcode_dp    [2];
  funct3_t     funct3_dp    [2];
  funct7_t     funct7_dp    [2];
  prf_addr_t   ps1_tag_dp   [2];
  prf_addr_t   ps2_tag_dp   [2];
  prf_addr_t   rob_tag_dp   [2];
  word_t       imm_dp       [2];
  word_t       pc_dp        [2];

  logic        wb_en      [2];
  prf_addr_t   rob_tag_wb [2];
  word_t       wb_data    [2];

  logic        stall_dp;
  logic        valid      [2];
  logic        lane_sel   [2];
  logic        reg_write  [2];
  opcode_t     opcode     [2];
  funct3_t     funct3     [2];
  funct7_t     funct7     [2];
  prf_addr_t   rob_tag    [2];
  word_t       imm        [2];
  word_t       pc         [2];
  word_t       rs1_data   [2];
  word_t       rs2_data   [2];

  int pass_cnt, fail_cnt;

  dispatch_core dut (.*);

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  function automatic int count_bank;
    int n;
    n = 0;
    for (int w = 0; w < RS_WAYS; w++)
      if (dut.u_rs.bank_valid[w]) n++;
    return n;
  endfunction

  function automatic int find_prd(input prf_addr_t prd);
    find_prd = -1;
    for (int w = 0; w < RS_WAYS; w++)
      if (dut.u_rs.bank_valid[w] && (dut.u_rs.bank_prd[w] == prd))
        return w;
  endfunction

  task automatic clear_disp;
    for (int i = 0; i < 2; i++) begin
      rob_valid_dp[i] = 0;
      path_use_dp[i]  = 0;
      lane_sel_dp[i]  = 0;
      opcode_dp[i]    = '0;
      funct3_dp[i]    = '0;
      funct7_dp[i]    = '0;
      ps1_tag_dp[i]   = '0;
      ps2_tag_dp[i]   = '0;
      rob_tag_dp[i]   = '0;
      imm_dp[i]       = '0;
      pc_dp[i]        = '0;
      wb_en[i]        = 0;
      rob_tag_wb[i]   = '0;
      wb_data[i]      = '0;
    end
    path_en  = 0;
    path_sel = 0;
    flush_rs = 0;
    enable   = 1;
  endtask

  task automatic set_disp(
      input int lane,
      input logic v, input prf_addr_t prd,
      input prf_addr_t ps1, input prf_addr_t ps2,
      input logic spec
  );
    rob_valid_dp[lane] = v;
    path_use_dp[lane]  = spec;
    lane_sel_dp[lane]  = 0;
    opcode_dp[lane]    = OPC_OP;
    funct3_dp[lane]    = '0;
    funct7_dp[lane]    = '0;
    ps1_tag_dp[lane]   = ps1;
    ps2_tag_dp[lane]   = ps2;
    rob_tag_dp[lane]   = prd;
    imm_dp[lane]       = '0;
    pc_dp[lane]        = word_t'(32'h1000 + lane);
  endtask

  task automatic expect_ok(
      input string name, input string detail, input bit pass
  );
    tb_report_open(pass, name, detail);
    tb_log_section("issue / rs");
    tb_field_bit("stall_dp", stall_dp, stall_dp);
    tb_field_bit("valid0",   valid[0], valid[0]);
    tb_field_bit("valid1",   valid[1], valid[1]);
    tb_field_u32("tag0",     rob_tag[0], rob_tag[0]);
    tb_field_u32("tag1",     rob_tag[1], rob_tag[1]);
    tb_field_in_u32("bank_n", count_bank());
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    rst_n = 0;
    clear_disp();
    tb_banner("dispatch_core_tb - RS + PRF integrated");

    repeat (2) @(posedge clk);
    rst_n = 1;
    @(negedge clk);
    #1;
    expect_ok("reset", "empty RS, no issue",
              (count_bank() == 0) && !valid[0] && !valid[1] && !stall_dp);

    // Dual ready rename → issue; no stubs left in RS.
    @(posedge clk);
    set_disp(0, 1, 6'd32, 6'd0, 6'd0, 0);
    set_disp(1, 1, 6'd33, 6'd0, 6'd0, 0);
    #0;
    @(negedge clk);
    #1;
    expect_ok("dual_bypass_issue", "both rename lanes issue",
              valid[0] && valid[1]
              && (rob_tag[0] == 6'd32) && (rob_tag[1] == 6'd33)
              && !stall_dp);

    clear_disp();
    @(posedge clk);
    #1;
    expect_ok("bypass_no_stub", "issued rename does not occupy RS",
              count_bank() == 0);

    // Seed producer in RS (store-only cycle: make it unready so it stores).
    // Drive producer with ps1=99 absent from bank → ready → would issue.
    // Instead seed by storing two unready ops after planting a blocker via
    // a prior store that we keep (manual: first cycle store ready producer
    // by forcing store — selector will issue ready producer).
    // Plant blocker: store unready pair depending on external 55, but
    // !in_bank ⇒ ready. So plant 55 by issuing nothing: use flush bank
    // and write via dual store of ready ops then... they'd issue.
    //
    // Practical approach: store producer by making selector choose store —
    // fill with older RS? Empty bank → producer issues.
    // Use RAW pair: I0 issues, I1 stores waiting on I0 — but without stub
    // I0 gone from bank, I1's !in_bank becomes true next cycle.
    //
    // Keep I0 in bank: don't issue I0 — only possible if I0 unready.
    // Force I0 unready with ps1 pointing at a seeded bank entry.
    // Seed via backdoor into dut bank is heavy; use two-step:
    // 1) Issue nothing; WB nothing.
    // For this TB: store dependents on a tag we first write by stalling
    // issue... skip — use path where producer is stored because RS full
    // of older ready? Too heavy.
    //
    // Simpler integrated coverage without stubs:
    // - RAW same-cycle: I0 issues, I1 stores
    // - next cycle I1 may become ready (!in_bank) and issue — accept that
    // - path filter, stall when filling with unready-on-seeded-CAM

    // ---- same-pair RAW: I0 issues, I1 stores ----
    @(posedge clk);
    set_disp(0, 1, 6'd50, 6'd0, 6'd0, 0);
    set_disp(1, 1, 6'd51, 6'd50, 6'd0, 0);
    #1;
    expect_ok("disp_raw", "I0 issues; I1 blocked by same-pair RAW",
              valid[0] && !valid[1] && (rob_tag[0] == 6'd50) && !stall_dp);
    @(negedge clk);
    #1;
    expect_ok("disp_raw_store", "I1 written into RS on ↓clk",
              (find_prd(6'd50) < 0) && (find_prd(6'd51) >= 0));

    clear_disp();
    // Without stub, I1 sees !prd_in_bank next cycle and can issue.
    @(posedge clk);
    #1;
    expect_ok("raw_next_issue", "I1 issues once CAM no longer holds I0",
              valid[0] && (rob_tag[0] == 6'd51));
    @(negedge clk);
    #1;
    expect_ok("raw_cleared", "I1 removed from RS after issue",
              find_prd(6'd51) < 0);

    clear_disp();

    // ---- path filter ----
    flush_rs = 1;
    @(negedge clk);
    #1;
    flush_rs = 0;
    clear_disp();
    @(posedge clk);
    #1;

    @(posedge clk);
    path_en  = 1;
    path_sel = 0;
    set_disp(0, 1, 6'd60, 6'd0, 6'd0, 1); // wrong path
    set_disp(1, 1, 6'd61, 6'd0, 6'd0, 0); // live
    #0;
    @(negedge clk);
    #1;
    expect_ok("path_filter", "only live path issues; wrong path dropped",
              valid[0] && (rob_tag[0] == 6'd61) && !valid[1]
              && (find_prd(6'd60) < 0) && (find_prd(6'd61) < 0)
              && !stall_dp);

    clear_disp();

    // Stall when bank is full of unready entries (drive via RS store path).
    // Fill: dual-store ready ops while holding issue off is not possible with
    // cover stall in reservation_station_tb. Here just flush cleanup.
    flush_rs = 1;
    @(negedge clk);
    #1;
    flush_rs = 0;
    @(posedge clk);
    #1;
    expect_ok("flush", "flush clears RS", count_bank() == 0 && !stall_dp);

    tb_summary(pass_cnt, fail_cnt);
    $finish;
  end

endmodule
