`timescale 1ns / 1ps

import rv_dis_pkg::*;

`include "../include/tb_console.svh"

// fetch_core_struct_tb — integrated fetch; DUT vs gm/fetch_core_struct_gm.sv.
module fetch_core_struct_tb;

  localparam int CLK_PERIOD = 10;
  localparam word_t TB_RESET_PC = word_t'(32'h0000_1000);

  logic   clk;
  logic   rst_n;
  logic   enable;
  logic   dispatch_stall;
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

  word_t  ref_pc0;
  word_t  ref_pc1;
  word_t  ref_i0_pc_target;
  word_t  ref_i1_pc_target;
  instr_t ref_instr0;
  instr_t ref_instr1;

  int pass_cnt;
  int fail_cnt;

  s1_fetch_struct #(
    .RESET_PC(TB_RESET_PC)
  ) dut (
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (enable),
    .dispatch_stall   (dispatch_stall),
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
    .instr1           (instr1)
  );

  fetch_core_struct_gm #(
    .RESET_PC(TB_RESET_PC)
  ) u_fetch_gm (
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (enable),
    .dispatch_stall   (dispatch_stall),
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
    .instr1           (ref_instr1)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic idle_ctrl;
    enable          = 1'b1;
    dispatch_stall  = 1'b0;
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

  task automatic check_cycle(input string name, input string detail);
    bit pass;

    pass = (pc0 === ref_pc0) && (pc1 === ref_pc1)
        && (i0_pc_target === ref_i0_pc_target) && (i1_pc_target === ref_i1_pc_target)
        && (instr0 === ref_instr0) && (instr1 === ref_instr1);

    tb_report_open(pass, name, detail);
    tb_field_u32("pc0",          pc0,          ref_pc0);
    tb_field_u32("pc1",          pc1,          ref_pc1);
    tb_field_u32("i0_pc_target", i0_pc_target, ref_i0_pc_target);
    tb_field_u32("i1_pc_target", i1_pc_target, ref_i1_pc_target);
    tb_field_u32("instr0",       instr0,       ref_instr0);
    tb_field_u32("instr1",       instr1,       ref_instr1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    idle_ctrl();

    tb_banner("fetch_core_struct_tb — DUT vs fetch_core_struct_gm.sv");

    rst_n = 1'b0;
    tick();
    check_cycle("reset", "RESET_PC pair");

    rst_n = 1'b1;
    tick();
    check_cycle("sequential_step", "mode=0 => +8/+8");

    dispatch_stall  = 1'b1;
    i0_pc_wb        = pc0;
    i0_pc_target_wb = word_t'(32'h0000_2000);
    i0_valid_wb     = 1'b1;
    tick();
    i0_valid_wb = 1'b0;
    check_cycle("btb_wb_hold", "dispatch_stall holds PC during BTB write");
    dispatch_stall = 1'b0;

    i0_pred_taken = 1'b1;
    tick();
    check_cycle("i0_predict", "target+4 / fallthrough+4");
    i0_pred_taken = 1'b0;

    tick();
    check_cycle("post_predict_step", "is_spec held, mode=0 => +8/+8");

    i0_pred_taken = 1'b1;
    tick();
    check_cycle("fetch_stall_hold", "predict while is_spec stalls PC");
    i0_pred_taken = 1'b0;

    i0_brch_recover = 1'b1;
    i0_pc_execute   = word_t'(32'h0000_3000);
    tick();
    check_cycle("i0_recover", "recover bases +8/+8");
    i0_brch_recover = 1'b0;

    dispatch_stall = 1'b1;
    tick();
    check_cycle("dispatch_stall_hold", "dispatch_stall blocks PC update");
    dispatch_stall = 1'b0;

    tick();
    check_cycle("sequential_resume", "back to +8/+8");

    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "fetch_core_struct_tb failed");
    $finish;
  end

endmodule
