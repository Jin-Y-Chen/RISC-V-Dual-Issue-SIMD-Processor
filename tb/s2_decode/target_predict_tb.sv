`timescale 1ns / 1ps

import rv_dis_pkg::*;

`include "../dpi/tb_console.svh"

// target_predict_tb - DUT vs gm/target_predict_gm.sv (combinational lane predict).
module target_predict_tb;

  localparam word_t PC_BASE = word_t'(32'h0000_1000);
  localparam word_t IMM_POS = word_t'(32'h0000_0010);  // +16 -> target 0x1010
  localparam word_t IMM_NEG = word_t'(32'hFFFF_FFF0);  // -16 -> target 0x0FF0
  localparam word_t BTB_HIT = word_t'(32'h0000_1010);
  localparam word_t BTB_BAD = word_t'(32'h0000_2000);

  logic      target_valid;
  logic      brnch_en;
  logic      jump_en;
  logic      spec_n;
  word_t     pc;
  br_state_t target_state;
  word_t     imm;
  word_t     pc_target;

  word_t     pc_predict;
  logic      pred_taken;
  logic      pred_valid_wb;
  logic      nest_spec_stall;

  word_t     ref_pc_predict;
  logic      ref_pred_taken;
  logic      ref_pred_valid_wb;
  logic      ref_nest_spec_stall;

  int pass_cnt;
  int fail_cnt;

  target_predict dut (
    .target_valid    (target_valid),
    .brnch_en        (brnch_en),
    .jump_en         (jump_en),
    .spec_n          (spec_n),
    .pc              (pc),
    .target_state    (target_state),
    .imm             (imm),
    .pc_target       (pc_target),
    .pc_predict      (pc_predict),
    .pred_taken      (pred_taken),
    .pred_valid_wb   (pred_valid_wb),
    .nest_spec_stall (nest_spec_stall)
  );

  target_predict_gm u_target_predict_gm (
    .target_valid    (target_valid),
    .brnch_en        (brnch_en),
    .jump_en         (jump_en),
    .spec_n          (spec_n),
    .pc              (pc),
    .target_state    (target_state),
    .imm             (imm),
    .pc_target       (pc_target),
    .pc_predict      (ref_pc_predict),
    .pred_taken      (ref_pred_taken),
    .pred_valid_wb   (ref_pred_valid_wb),
    .nest_spec_stall (ref_nest_spec_stall)
  );

  task automatic check_predict(input string name, input string detail);
    bit pass;
    pass = (pc_predict === ref_pc_predict)
        && (pred_taken === ref_pred_taken)
        && (pred_valid_wb === ref_pred_valid_wb)
        && (nest_spec_stall === ref_nest_spec_stall);

    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_bit("target_valid",  target_valid);
    tb_field_in_bit("brnch_en",      brnch_en);
    tb_field_in_bit("jump_en",       jump_en);
    tb_field_in_bit("spec_n",        spec_n);
    tb_field_in_u32("pc",            pc);
    tb_field_in_u2 ("target_state",  target_state);
    tb_field_in_u32("imm",           imm);
    tb_field_in_u32("pc_target",     pc_target);
    $display("");
    tb_log_section("check");
    tb_field_u32("pc_predict",      pc_predict,      ref_pc_predict);
    tb_field_bit("pred_taken",      pred_taken,      ref_pred_taken);
    tb_field_bit("pred_valid_wb",   pred_valid_wb,   ref_pred_valid_wb);
    tb_field_bit("nest_spec_stall", nest_spec_stall, ref_nest_spec_stall);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic drive(
    input logic      target_valid_i,
    input logic      brnch_en_i,
    input logic      jump_en_i,
    input logic      spec_n_i,
    input word_t     pc_i,
    input br_state_t target_state_i,
    input word_t     imm_i,
    input word_t     pc_target_i,
    input string     name,
    input string     detail
  );
    target_valid = target_valid_i;
    brnch_en     = brnch_en_i;
    jump_en      = jump_en_i;
    spec_n       = spec_n_i;
    pc           = pc_i;
    target_state = target_state_i;
    imm          = imm_i;
    pc_target    = pc_target_i;
    #0;
    check_predict(name, detail);
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("target_predict_tb: DUT vs target_predict_gm.sv");

    // Non-control-flow: pass PC through, quiet predict outputs.
    drive(1'b0, 1'b0, 1'b0, 1'b0, PC_BASE, 2'b10, IMM_POS, BTB_HIT,
          "idle", "non-branch => pc_predict=pc, quiet");

    // Branch, BTB miss: train + decode target; weakly-taken state => taken.
    drive(1'b0, 1'b1, 1'b0, 1'b0, PC_BASE, 2'b10, IMM_POS, BTB_BAD,
          "br_miss_taken", "miss + state=10 => train, taken, decode tgt");

    // Branch, BTB miss, not-taken / weakly-not-taken state.
    drive(1'b0, 1'b1, 1'b0, 1'b0, PC_BASE, 2'b01, IMM_POS, BTB_BAD,
          "br_miss_ntaken", "miss + state=01 => train, not taken");

    // Branch, BTB hit matching decode target: trust BTB, no train.
    drive(1'b1, 1'b1, 1'b0, 1'b0, PC_BASE, 2'b11, IMM_POS, BTB_HIT,
          "br_hit_match", "valid match => pc_target, no train");

    // Branch, BTB stale (valid but wrong target): retrain to decode target.
    drive(1'b1, 1'b1, 1'b0, 1'b0, PC_BASE, 2'b11, IMM_POS, BTB_BAD,
          "br_stale", "valid but stale => train decode tgt");

    // Negative imm decode target (word-aligned).
    drive(1'b0, 1'b1, 1'b0, 1'b0, PC_BASE, 2'b10, IMM_NEG, BTB_BAD,
          "br_neg_imm", "miss + negative imm => aligned decode tgt");

    // Unconditional jump: always taken; miss trains.
    drive(1'b0, 1'b1, 1'b1, 1'b0, PC_BASE, 2'b00, IMM_POS, BTB_BAD,
          "jump_miss", "jump_en => always taken + train on miss");

    // Jump with matching BTB: taken, no train.
    drive(1'b1, 1'b1, 1'b1, 1'b0, PC_BASE, 2'b00, IMM_POS, BTB_HIT,
          "jump_hit", "jump + BTB hit => taken, no train");

    // Nested speculation: stall + quiet (pc_predict stays pc).
    drive(1'b1, 1'b1, 1'b0, 1'b1, PC_BASE, 2'b11, IMM_POS, BTB_HIT,
          "nest_stall_br", "spec_n && brnch_en => nest_spec_stall");

    // Nested jump still stalls (jump_en implies brnch_en).
    drive(1'b0, 1'b1, 1'b1, 1'b1, PC_BASE, 2'b00, IMM_POS, BTB_BAD,
          "nest_stall_jump", "nested jump => stall, quiet predict");

    // spec_n alone without branch: no stall.
    drive(1'b0, 1'b0, 1'b0, 1'b1, PC_BASE, 2'b10, IMM_POS, BTB_HIT,
          "spec_idle", "spec_n without brnch_en => no nest stall");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "target_predict_tb failed");
    $finish;
  end

endmodule
