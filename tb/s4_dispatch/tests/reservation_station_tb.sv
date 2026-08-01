`timescale 1ns / 1ps

// Directed TB: reservation_station (bank + wakeup + inline ↓clk alloc).
// src_en/store_en: 0/1 write rename, 1/0 clear rs_tag, 1/1 age, 0/0 nop.
import rv_dis_pkg::*;
import rs_pkg::*;

`include "../../common/utils/tb_console.svh"

module reservation_station_tb;

  localparam int CLK_PERIOD = 10;

  logic        clk, rst_n, enable, flush;
  logic        path_en, path_sel, stall_dp;

  logic        valid_dp    [2];
  logic        lane_sel_dp [2];
  logic        path_use_dp [2];
  opcode_t     opcode_dp   [2];
  funct3_t     funct3_dp   [2];
  funct7_t     funct7_dp   [2];
  prf_addr_t   ps1_tag_dp  [2];
  prf_addr_t   ps2_tag_dp  [2];
  prf_addr_t   rob_tag_dp  [2];
  word_t       imm_dp      [2];
  word_t       pc_dp       [2];

  logic        wb_en      [2];
  prf_addr_t   rob_tag_wb [2];

  logic        src_en   [2];
  logic        store_en [2];
  rs_way_t     rs_tag   [2];

  logic        bank_valid    [RS_WAYS];
  rs_way_t     bank_rs_tag   [RS_WAYS];
  rs_age_t     bank_age      [RS_WAYS];
  logic        bank_lane_sel [RS_WAYS];
  logic        bank_spec     [RS_WAYS];
  logic        bank_rs1_rdy  [RS_WAYS];
  logic        bank_rs2_rdy  [RS_WAYS];
  opcode_t     bank_opcode   [RS_WAYS];
  funct3_t     bank_funct3   [RS_WAYS];
  funct7_t     bank_funct7   [RS_WAYS];
  prf_addr_t   bank_ps1      [RS_WAYS];
  prf_addr_t   bank_ps2      [RS_WAYS];
  prf_addr_t   bank_prd      [RS_WAYS];
  word_t       bank_imm      [RS_WAYS];
  word_t       bank_pc       [RS_WAYS];

  int pass_cnt, fail_cnt;

  reservation_station dut (.*);

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  task automatic set_disp(
      input int lane,
      input logic v, input prf_addr_t prd,
      input prf_addr_t ps1, input prf_addr_t ps2,
      input logic spec
  );
    valid_dp[lane]    = v;
    lane_sel_dp[lane] = 0;
    path_use_dp[lane] = spec;
    opcode_dp[lane]   = OPC_OP;
    funct3_dp[lane]   = '0;
    funct7_dp[lane]   = '0;
    ps1_tag_dp[lane]  = ps1;
    ps2_tag_dp[lane]  = ps2;
    rob_tag_dp[lane]  = prd;
    imm_dp[lane]      = '0;
    pc_dp[lane]       = '0;
    if (v) begin
      src_en[lane]   = 0;
      store_en[lane] = 1;
    end
  endtask

  task automatic clear_stim;
    flush    = 0;
    path_en  = 0;
    path_sel = 0;
    stall_dp = 0;
    enable   = 1;
    for (int i = 0; i < 2; i++) begin
      valid_dp[i] = 0; lane_sel_dp[i] = 0; path_use_dp[i] = 0;
      opcode_dp[i] = '0; funct3_dp[i] = '0; funct7_dp[i] = '0;
      ps1_tag_dp[i] = '0; ps2_tag_dp[i] = '0; rob_tag_dp[i] = '0;
      imm_dp[i] = '0; pc_dp[i] = '0;
      wb_en[i] = 0; rob_tag_wb[i] = '0;
      src_en[i] = 0; store_en[i] = 0;
    end
    rs_tag[0] = '0; rs_tag[1] = '0;
  endtask

  task automatic cycle_hold;
    @(negedge clk);
    #1;
    clear_stim();
    #0;
  endtask

  function automatic int count_valid;
    int n;
    n = 0;
    for (int w = 0; w < RS_WAYS; w++)
      if (bank_valid[w]) n++;
    return n;
  endfunction

  function automatic int count_path(input logic spec);
    int n;
    n = 0;
    for (int w = 0; w < RS_WAYS; w++)
      if (bank_valid[w] && (bank_spec[w] == spec)) n++;
    return n;
  endfunction

  function automatic int find_prd(input prf_addr_t prd);
    find_prd = -1;
    for (int w = 0; w < RS_WAYS; w++)
      if (bank_valid[w] && (bank_prd[w] == prd))
        return w;
  endfunction

  task automatic expect_ok(
      input string name, input string detail, input bit pass
  );
    tb_report_open(pass, name, detail);
    tb_log_section("rs state");
    tb_field_in_u32("valid_cnt", count_valid());
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    rst_n = 0;
    clear_stim();
    tb_banner("reservation_station_tb - RS bank/wakeup/alloc");

    repeat (2) @(posedge clk);
    rst_n = 1;
    @(negedge clk);
    #1;
    expect_ok("reset", "empty bank", count_valid() == 0);

    // Rename issued → nop (no stub).
    @(posedge clk);
    set_disp(0, 1, 6'd50, 6'd0, 6'd0, 0);
    src_en[0]   = 0;
    store_en[0] = 0;
    #0;
    cycle_hold;
    @(posedge clk);
    expect_ok("rename_issue_nop", "issued rename leaves bank empty",
              count_valid() == 0);

    // Store producer into bank (blocks CAM), then store dependents.
    @(posedge clk);
    set_disp(0, 1, 6'd50, 6'd0, 6'd0, 0);
    #0;
    cycle_hold;

    @(posedge clk);
    expect_ok("store_producer", "producer parked in RS",
              (count_valid() == 1) && (find_prd(6'd50) >= 0));

    @(posedge clk);
    set_disp(0, 1, 6'd32, 6'd50, 6'd0, 0);
    set_disp(1, 1, 6'd33, 6'd50, 6'd0, 0);
    #0;
    cycle_hold;

    @(posedge clk);
    expect_ok("store_dual_unready", "two entries waiting on working dest p50",
              (count_valid() == 3)
              && (find_prd(6'd32) >= 0) && (find_prd(6'd33) >= 0)
              && !bank_rs1_rdy[find_prd(6'd32)]);

    @(posedge clk);
    wb_en[0] = 1;
    rob_tag_wb[0] = 6'd50;
    #0;
    cycle_hold;

    @(posedge clk);
    begin
      int w0, w1;
      bit pass;
      w0 = find_prd(6'd32);
      w1 = find_prd(6'd33);
      pass = (w0 >= 0) && (w1 >= 0)
          && bank_rs1_rdy[w0] && bank_rs1_rdy[w1]
          && (find_prd(6'd50) < 0);
      expect_ok("wb_frees_dest", "WB frees producer + wakes consumers", pass);
    end

    begin
      int w0;
      rs_age_t age_before;
      w0 = find_prd(6'd32);
      age_before = bank_age[w0];
      @(posedge clk);
      // Clear issued RS entry.
      src_en[0]   = 1;
      store_en[0] = 0;
      rs_tag[0]   = rs_way_t'(w0);
      #0;
      cycle_hold;
      @(posedge clk);
      expect_ok("clear_issued", "RS issue removes entry",
                (find_prd(6'd32) < 0) && (find_prd(6'd33) >= 0));

      w0 = find_prd(6'd33);
      @(posedge clk);
      // Age bump on unpicked RS.
      src_en[0]   = 1;
      store_en[0] = 1;
      rs_tag[0]   = rs_way_t'(w0);
      #0;
      cycle_hold;
      @(posedge clk);
      expect_ok("age_unpicked", "unpicked RS stays valid after age bump",
                (find_prd(6'd33) >= 0)
                && (bank_age[find_prd(6'd33)] >= age_before));
    end

    flush = 1;
    @(negedge clk);
    #1;
    flush = 0;
    #0;
    expect_ok("flush", "bank cleared", count_valid() == 0);

    clear_stim();
    @(posedge clk);
    set_disp(0, 1, 6'd60, 6'd0, 6'd0, 0);
    #0;
    cycle_hold;

    @(posedge clk);
    set_disp(0, 1, 6'd36, 6'd60, 6'd0, 0);
    set_disp(1, 1, 6'd37, 6'd60, 6'd0, 1);
    #0;
    cycle_hold;

    @(posedge clk);
    expect_ok("queued_both_paths", "path0 producer+dep and path1 dep",
              (count_path(0) == 2) && (count_path(1) == 1));

    @(posedge clk);
    path_en  = 1;
    path_sel = 1;
    #0;
    cycle_hold;

    @(posedge clk);
    expect_ok("path_squash", "only path1 remains",
              (count_path(0) == 0) && (count_path(1) == 1));

    @(posedge clk);
    path_en  = 1;
    path_sel = 1;
    set_disp(0, 1, 6'd90, 6'd0, 6'd0, 0);
    valid_dp[0] = 1;
    path_use_dp[0] = 0;
    // Wrong path: still drive store_en but path_ok blocks write.
    set_disp(1, 1, 6'd91, 6'd0, 6'd0, 1);
    #0;
    cycle_hold;
    @(posedge clk);
    expect_ok("path_kill_disp_store", "wrong-path rename not written on ↓clk",
              (find_prd(6'd90) < 0) && (find_prd(6'd91) >= 0)
              && (count_path(0) == 0));

    flush = 1;
    @(negedge clk);
    #1;
    flush = 0;

    @(posedge clk);
    set_disp(0, 1, 6'd70, 6'd0, 6'd0, 0);
    stall_dp = 1;
    #0;
    cycle_hold;
    @(posedge clk);
    expect_ok("stall_blocks_store", "stall_dp prevents alloc",
              count_valid() == 0);

    for (int p = 0; p < 8; p++) begin
      @(posedge clk);
      set_disp(0, 1, prf_addr_t'(32 + 2 * p), 6'd0, 6'd0, 0);
      set_disp(1, 1, prf_addr_t'(33 + 2 * p), 6'd0, 6'd0, 0);
      #0;
      cycle_hold;
    end

    @(posedge clk);
    expect_ok("bank_full", "16 ways occupied", count_valid() == RS_WAYS);

    @(posedge clk);
    set_disp(0, 1, 6'd48, 6'd0, 6'd0, 0);
    set_disp(1, 1, 6'd49, 6'd0, 6'd0, 0);
    #0;
    cycle_hold;
    @(posedge clk);
    expect_ok("overflow_no_new", "still 16 (free_m empty)",
              count_valid() == RS_WAYS);

    tb_summary(pass_cnt, fail_cnt);
    $finish;
  end

endmodule
