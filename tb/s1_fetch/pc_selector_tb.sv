`timescale 1ns / 1ps

// pc_selector_tb — predict / recover / stall routing (combinational DUT).
module pc_selector_tb;

  `include "../common/tb_console.svh"

  logic        is_spec;
  logic        i0_pred_taken;
  logic        i1_pred_taken;
  logic        i0_brch_recover;
  logic        i1_brch_recover;
  logic [31:0] pc0_in;
  logic [31:0] pc1_in;
  logic [31:0] i0_pc_target;
  logic [31:0] i1_pc_target;
  logic [31:0] i0_pc_execute;
  logic [31:0] i1_pc_execute;
  logic        stall;
  logic        mode;
  logic        spec0_en;
  logic [31:0] pc0_out;
  logic [31:0] pc1_out;

  int pass_cnt;
  int fail_cnt;

  pc_selector dut (
    .is_spec         (is_spec),
    .i0_pred_taken   (i0_pred_taken),
    .i1_pred_taken   (i1_pred_taken),
    .i0_brch_recover (i0_brch_recover),
    .i1_brch_recover (i1_brch_recover),
    .pc0_in          (pc0_in),
    .pc1_in          (pc1_in),
    .i0_pc_target    (i0_pc_target),
    .i1_pc_target    (i1_pc_target),
    .i0_pc_execute   (i0_pc_execute),
    .i1_pc_execute   (i1_pc_execute),
    .stall           (stall),
    .mode            (mode),
    .spec0_en        (spec0_en),
    .pc0_out         (pc0_out),
    .pc1_out         (pc1_out)
  );

  function automatic logic [31:0] align4(input logic [31:0] v);
    return {v[31:2], 2'b00};
  endfunction

  task automatic model_ref(
    input  logic        is_spec_v,
    input  logic        i0_pred_v,
    input  logic        i1_pred_v,
    input  logic        i0_rec_v,
    input  logic        i1_rec_v,
    input  logic [31:0] pc0_in_v,
    input  logic [31:0] pc1_in_v,
    input  logic [31:0] i0_tgt_v,
    input  logic [31:0] i1_tgt_v,
    input  logic [31:0] i0_exec_v,
    input  logic [31:0] i1_exec_v,
    output logic [31:0] exp_pc0,
    output logic [31:0] exp_pc1,
    output logic        exp_stall,
    output logic        exp_mode,
    output logic        exp_spec0_en
  );
    logic recover_any;
    recover_any = i0_rec_v | i1_rec_v;
    exp_stall    = (i0_pred_v | i1_pred_v) && is_spec_v && !recover_any;
    exp_spec0_en = (i0_pred_v | i1_pred_v | is_spec_v) && !recover_any;
    exp_mode     = (i0_pred_v ^ i1_pred_v) && !recover_any;

    exp_pc0 = align4(pc0_in_v);
    exp_pc1 = align4(pc1_in_v);

    if (i0_rec_v) begin
      exp_pc0 = align4(i0_exec_v);
      exp_pc1 = align4(i0_exec_v) + 32'd4;
    end else if (i1_rec_v) begin
      exp_pc0 = align4(i1_exec_v);
      exp_pc1 = align4(i1_exec_v) + 32'd4;
    end else begin
      if (i0_pred_v && i1_pred_v) begin
        exp_pc0 = align4(i0_tgt_v);
        exp_pc1 = align4(i0_tgt_v) + 32'd4;
      end else if (i0_pred_v) begin
        exp_pc0 = align4(i0_tgt_v);
        exp_pc1 = align4(pc1_in_v);
      end else if (i1_pred_v) begin
        exp_pc0 = align4(i1_tgt_v);
        exp_pc1 = align4(pc0_in_v);
      end
    end
  endtask

  task automatic drive(
    input logic        is_spec_v,
    input logic        i0_pred_v,
    input logic        i1_pred_v,
    input logic        i0_rec_v,
    input logic        i1_rec_v,
    input logic [31:0] pc0_in_v,
    input logic [31:0] pc1_in_v,
    input logic [31:0] i0_tgt_v,
    input logic [31:0] i1_tgt_v,
    input logic [31:0] i0_exec_v,
    input logic [31:0] i1_exec_v
  );
    is_spec         = is_spec_v;
    i0_pred_taken   = i0_pred_v;
    i1_pred_taken   = i1_pred_v;
    i0_brch_recover = i0_rec_v;
    i1_brch_recover = i1_rec_v;
    pc0_in          = pc0_in_v;
    pc1_in          = pc1_in_v;
    i0_pc_target    = i0_tgt_v;
    i1_pc_target    = i1_tgt_v;
    i0_pc_execute   = i0_exec_v;
    i1_pc_execute   = i1_exec_v;
    #0;
  endtask

  task automatic check_state(input string name, input string detail);
    bit pass;
    logic [31:0] exp_pc0, exp_pc1;
    logic        exp_stall, exp_mode, exp_spec0_en;

    model_ref(
      is_spec, i0_pred_taken, i1_pred_taken, i0_brch_recover, i1_brch_recover,
      pc0_in, pc1_in, i0_pc_target, i1_pc_target, i0_pc_execute, i1_pc_execute,
      exp_pc0, exp_pc1, exp_stall, exp_mode, exp_spec0_en
    );

    pass = (pc0_out === exp_pc0) && (pc1_out === exp_pc1)
        && (stall === exp_stall) && (mode === exp_mode)
        && (spec0_en === exp_spec0_en);

    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_bit("is_spec",         is_spec);
    tb_field_in_bit("i0_pred_taken",   i0_pred_taken);
    tb_field_in_bit("i1_pred_taken",   i1_pred_taken);
    tb_field_in_bit("i0_brch_recover", i0_brch_recover);
    tb_field_in_bit("i1_brch_recover", i1_brch_recover);
    tb_field_in_u32("pc0_in",         pc0_in);
    tb_field_in_u32("pc1_in",          pc1_in);
    tb_field_in_u32("i0_pc_target",    i0_pc_target);
    tb_field_in_u32("i1_pc_target",    i1_pc_target);
    tb_field_in_u32("i0_pc_execute",   i0_pc_execute);
    tb_field_in_u32("i1_pc_execute",   i1_pc_execute);
    $display("");
    tb_log_section("check");
    tb_field_u32("pc0_out",  pc0_out,  exp_pc0);
    tb_field_u32("pc1_out",  pc1_out,  exp_pc1);
    tb_field_bit("stall",    stall,    exp_stall);
    tb_field_bit("mode",     mode,     exp_mode);
    tb_field_bit("spec0_en", spec0_en, exp_spec0_en);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("pc_selector_tb — predict / recover / stall");

    // -------------------------------------------------------------------------
    // Default pass-through (aligned)
    // -------------------------------------------------------------------------
    drive(0, 0, 0, 0, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("default_pass", "no predict, no recover — align(pc_in)");

    drive(0, 0, 0, 0, 0, 32'h1003, 32'h1007, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("default_align", "unaligned pc_in word-aligned on output");

    // -------------------------------------------------------------------------
    // Single-lane predict
    // -------------------------------------------------------------------------
    drive(0, 1, 0, 0, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("i0_predict", "I0 taken: pc0=target, pc1=pc1_in, mode=1");

    drive(0, 0, 1, 0, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("i1_predict", "I1 taken: pc0=target, pc1=pc0_in, mode=1");

    drive(0, 1, 0, 0, 0, 32'h1000, 32'h1004, 32'h2003, 32'h3000, 32'h4000, 32'h5000);
    check_state("i0_predict_align", "I0 target aligned before route");

    // -------------------------------------------------------------------------
    // Dual predict (both taken — I0 target pair)
    // -------------------------------------------------------------------------
    drive(0, 1, 1, 0, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("double_predict", "both taken: I0 target +4 pair, mode=0");

    // -------------------------------------------------------------------------
    // In-spec hold / stall
    // -------------------------------------------------------------------------
    drive(1, 0, 0, 0, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("in_spec_hold", "is_spec=1, no new predict — pass-through, spec0_en=1");

    drive(1, 1, 0, 0, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("stall_i0_in_spec", "predict while in_spec asserts stall");

    drive(1, 0, 1, 0, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("stall_i1_in_spec", "I1 predict while in_spec asserts stall");

    drive(1, 1, 1, 0, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("stall_both_in_spec", "dual predict while in_spec asserts stall");

    // -------------------------------------------------------------------------
    // Branch recover (I0 priority over I1)
    // -------------------------------------------------------------------------
    drive(0, 0, 0, 1, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("i0_recover", "I0 execute pair replaces PCs, clears spec");

    drive(0, 0, 0, 0, 1, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("i1_recover", "I1 execute pair replaces PCs");

    drive(0, 0, 0, 1, 1, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4005, 32'h5009);
    check_state("i0_recover_priority", "I0 recover wins when both recover asserted");

    drive(0, 0, 0, 1, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4005, 32'h5000);
    check_state("i0_recover_align", "execute PC aligned to pair base");

    // -------------------------------------------------------------------------
    // Recover overrides predict + clears stall
    // -------------------------------------------------------------------------
    drive(1, 1, 0, 1, 0, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("recover_over_predict", "recover suppresses stall and spec0_en");

    drive(1, 1, 1, 0, 1, 32'h1000, 32'h1004, 32'h2000, 32'h3000, 32'h4000, 32'h5000);
    check_state("recover_over_dual_pred", "I1 recover wins over dual predict");

    // -------------------------------------------------------------------------
    // Predict does not assert stall outside spec
    // -------------------------------------------------------------------------
    drive(0, 1, 1, 0, 0, 32'hA000, 32'hA004, 32'hB000, 32'hC000, 32'hD000, 32'hE000);
    check_state("dual_predict_no_stall", "dual predict out of spec: stall=0, spec0_en=1");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "pc_selector_tb failed");
    $finish;
  end

endmodule
