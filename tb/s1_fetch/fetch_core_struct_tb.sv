`timescale 1ns / 1ps

import rv_dis_pkg::*;

`include "../include/tb_console.svh"

// fetch_core_struct_tb - integrated fetch; DUT vs gm/fetch_core_struct_gm.sv.
// Nested-speculation freeze uses decode-style spec*_stall (no fetch_stall).
module fetch_core_struct_tb;

  localparam int CLK_PERIOD = 10;
  localparam word_t TB_RESET_PC = word_t'(32'h0000_1000);

  logic   clk;
  logic   rst_n;
  logic   enable;
  logic   dispatch_stall;
  logic   spec0_stall;
  logic   spec1_stall;
  logic   i0_pred_taken;
  logic   i1_pred_taken;
  logic   i0_brch_recover;
  logic   i1_brch_recover;
  word_t  i0_pc_execute;
  word_t  i1_pc_execute;
  logic   i0_valid_wb;
  logic   i1_valid_wb;
  word_t  i0_pc_wb;
  word_t  i1_pc_wb;
  word_t  i0_pc_target_wb;
  word_t  i1_pc_target_wb;
  word_t  pc0;
  word_t  pc1;
  word_t  i0_pc_target;
  word_t  i1_pc_target;
  instr_t instr0;
  instr_t instr1;
  br_map_t branch_map;
  logic    i0_valid, i1_valid;

  word_t  ref_pc0;
  word_t  ref_pc1;
  word_t  ref_i0_pc_target;
  word_t  ref_i1_pc_target;
  instr_t ref_instr0;
  instr_t ref_instr1;
  br_map_t ref_branch_map;

  int pass_cnt;
  int fail_cnt;

  s1_fetch_struct #(
    .RESET_PC(TB_RESET_PC)
  ) dut (
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (enable),
    .dispatch_stall   (dispatch_stall),
    .spec0_stall      (spec0_stall),
    .spec1_stall      (spec1_stall),
    .i0_pred_taken    (i0_pred_taken),
    .i1_pred_taken    (i1_pred_taken),
    .i0_brch_recover  (i0_brch_recover),
    .i1_brch_recover  (i1_brch_recover),
    .i0_pc_execute    (i0_pc_execute),
    .i1_pc_execute    (i1_pc_execute),
    .i0_valid_wb      (i0_valid_wb),
    .i1_valid_wb      (i1_valid_wb),
    .i0_pc_wb         (i0_pc_wb),
    .i1_pc_wb         (i1_pc_wb),
    .i0_pc_target_wb  (i0_pc_target_wb),
    .i1_pc_target_wb  (i1_pc_target_wb),
    .pc0              (pc0),
    .pc1              (pc1),
    .i0_pc_target     (i0_pc_target),
    .i1_pc_target     (i1_pc_target),
    .instr0           (instr0),
    .instr1           (instr1),
    .branch_map       (branch_map),
    .i0_valid         (i0_valid),
    .i1_valid         (i1_valid)
  );

  fetch_core_struct_gm #(
    .RESET_PC(TB_RESET_PC)
  ) u_fetch_gm (
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (enable),
    .dispatch_stall   (dispatch_stall),
    .spec0_stall      (spec0_stall),
    .spec1_stall      (spec1_stall),
    .i0_pred_taken    (i0_pred_taken),
    .i1_pred_taken    (i1_pred_taken),
    .i0_brch_recover  (i0_brch_recover),
    .i1_brch_recover  (i1_brch_recover),
    .i0_pc_execute    (i0_pc_execute),
    .i1_pc_execute    (i1_pc_execute),
    .i0_valid_wb      (i0_valid_wb),
    .i1_valid_wb      (i1_valid_wb),
    .i0_pc_wb         (i0_pc_wb),
    .i1_pc_wb         (i1_pc_wb),
    .i0_pc_target_wb  (i0_pc_target_wb),
    .i1_pc_target_wb  (i1_pc_target_wb),
    .pc0              (ref_pc0),
    .pc1              (ref_pc1),
    .i0_pc_target     (ref_i0_pc_target),
    .i1_pc_target     (ref_i1_pc_target),
    .instr0           (ref_instr0),
    .instr1           (ref_instr1),
    .branch_map       (ref_branch_map)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk;

  task automatic idle_ctrl;
    enable          = 1'b1;
    dispatch_stall  = 1'b0;
    spec0_stall     = 1'b0;
    spec1_stall     = 1'b0;
    i0_pred_taken   = 1'b0;
    i1_pred_taken   = 1'b0;
    i0_brch_recover = 1'b0;
    i1_brch_recover = 1'b0;
    i0_pc_execute   = '0;
    i1_pc_execute   = '0;
    i0_valid_wb     = 1'b0;
    i1_valid_wb     = 1'b0;
    i0_pc_wb        = '0;
    i1_pc_wb        = '0;
    i0_pc_target_wb = '0;
    i1_pc_target_wb = '0;
  endtask

  task automatic step_and_check(input string name, input string detail);
    bit pass;

    @(negedge clk);
    #0;
    @(posedge clk);
    #0;

    pass = (pc0 === ref_pc0) && (pc1 === ref_pc1)
        && (i0_pc_target === ref_i0_pc_target) && (i1_pc_target === ref_i1_pc_target)
        && (branch_map === ref_branch_map);

    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_bit("enable",          enable);
    tb_field_in_bit("dispatch_stall",  dispatch_stall);
    tb_field_in_bit("spec0_stall",     spec0_stall);
    tb_field_in_bit("spec1_stall",     spec1_stall);
    tb_field_in_bit("i0_pred_taken",   i0_pred_taken);
    tb_field_in_bit("i1_pred_taken",   i1_pred_taken);
    tb_field_in_bit("i0_brch_recover", i0_brch_recover);
    tb_field_in_bit("i1_brch_recover", i1_brch_recover);
    tb_field_in_u32("i0_pc_execute",   i0_pc_execute);
    tb_field_in_u32("i1_pc_execute",   i1_pc_execute);
    tb_field_in_bit("i0_valid_wb",     i0_valid_wb);
    tb_field_in_bit("i1_valid_wb",     i1_valid_wb);
    tb_field_in_u32("i0_pc_wb",        i0_pc_wb);
    tb_field_in_u32("i1_pc_wb",        i1_pc_wb);
    tb_field_in_u32("i0_pc_target_wb", i0_pc_target_wb);
    tb_field_in_u32("i1_pc_target_wb", i1_pc_target_wb);
    $display("");
    tb_log_section("check");
    tb_field_u32("pc0",          pc0,          ref_pc0);
    tb_field_u32("pc1",          pc1,          ref_pc1);
    tb_field_u32("i0_pc_target", i0_pc_target, ref_i0_pc_target);
    tb_field_u32("i1_pc_target", i1_pc_target, ref_i1_pc_target);
    tb_field_u32("branch_map",   {30'b0, branch_map}, {30'b0, ref_branch_map});
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    rst_n    = 1'b0;
    idle_ctrl();

    tb_banner("fetch_core_struct_tb: DUT vs fetch_core_struct_gm.sv");

    step_and_check("reset", "RESET_PC pair, br_map=00");

    @(negedge clk);
    rst_n = 1'b1;
    idle_ctrl();
    step_and_check("sequential_step", "br_map=00 => +8/+8");

    @(negedge clk);
    idle_ctrl();
    dispatch_stall  = 1'b1;
    i0_pc_wb        = pc0;
    i0_pc_target_wb = word_t'(32'h0000_2000);
    i0_valid_wb     = 1'b1;
    step_and_check("btb_wb_hold", "dispatch_stall holds PC during BTB write");

    @(negedge clk);
    idle_ctrl();
    i0_pred_taken = 1'b1;
    step_and_check("i0_predict", "br_map=01, I0 target into next-PC bases");

    @(negedge clk);
    idle_ctrl();
    step_and_check("post_predict_step", "sticky br_map=01 => +4/+4 split");

    // Decode-style nested-speculation stall freezes PC
    @(negedge clk);
    idle_ctrl();
    spec0_stall = 1'b1;
    step_and_check("spec_stall_hold", "spec0_stall freezes PC");

    @(negedge clk);
    idle_ctrl();
    i0_brch_recover = 1'b1;
    i0_pc_execute   = word_t'(32'h0000_3000);
    step_and_check("i0_recover", "recover clears br_map, execute+4/+8");

    @(negedge clk);
    idle_ctrl();
    dispatch_stall = 1'b1;
    step_and_check("dispatch_stall_hold", "dispatch_stall blocks PC update");

    @(negedge clk);
    idle_ctrl();
    step_and_check("sequential_resume", "br_map=00 => +8/+8");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $error("fetch_core_struct_tb: %0d failure(s)", fail_cnt);
    $finish;
  end

endmodule
