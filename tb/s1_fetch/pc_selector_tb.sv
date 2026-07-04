`timescale 1ns / 1ps

// pc_selector_tb — predict/recover routing for pc0_out/pc1_out.
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

  task automatic check_comb(
    input string       name,
    input logic [31:0] exp_pc0,
    input logic [31:0] exp_pc1,
    input logic        exp_mode,
    input logic        exp_stall
  );
    bit pass;
    pass = (pc0_out === exp_pc0) && (pc1_out === exp_pc1)
        && (mode === exp_mode) && (stall === exp_stall);
    tb_report_open(pass, name, "");
    tb_field_u32("pc0_out", pc0_out, exp_pc0);
    tb_field_u32("pc1_out", pc1_out, exp_pc1);
    tb_field_bit("mode", mode, exp_mode);
    tb_field_bit("stall", stall, exp_stall);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    is_spec = 1'b0;
    i0_pred_taken = 1'b0;
    i1_pred_taken = 1'b0;
    i0_brch_recover = 1'b0;
    i1_brch_recover = 1'b0;
    pc0_in = 32'h1000;
    pc1_in = 32'h1004;
    i0_pc_target = 32'h2000;
    i1_pc_target = 32'h3000;
    i0_pc_execute = 32'h4000;
    i1_pc_execute = 32'h5000;

    tb_banner("pc_selector_tb");
    #1;
    check_comb("default_pass", 32'h1000, 32'h1004, 1'b0, 1'b0);

    i0_pred_taken = 1'b1;
    #1;
    check_comb("i0_predict", 32'h2000, 32'h1004, 1'b1, 1'b0);

    i0_pred_taken = 1'b0;
    i1_pred_taken = 1'b1;
    #1;
    check_comb("i1_predict", 32'h3000, 32'h1000, 1'b1, 1'b0);

    i1_pred_taken = 1'b0;
    i0_pred_taken = 1'b1;
    i1_pred_taken = 1'b1;
    #1;
    check_comb("double_predict", 32'h2000, 32'h2004, 1'b0, 1'b0);

    i0_pred_taken = 1'b0;
    i1_pred_taken = 1'b0;
    is_spec = 1'b1;
    #1;
    check_comb("in_spec_hold", 32'h1000, 32'h1004, 1'b0, 1'b0);

    i0_pred_taken = 1'b1;
    #1;
    check_comb("stall_while_spec", 32'h2000, 32'h1004, 1'b1, 1'b1);

    i0_pred_taken = 1'b0;
    i0_brch_recover = 1'b1;
    #1;
    check_comb("i0_recover", 32'h4000, 32'h4004, 1'b0, 1'b0);

    i0_brch_recover = 1'b0;
    i1_brch_recover = 1'b1;
    #1;
    check_comb("i1_recover", 32'h5000, 32'h5004, 1'b0, 1'b0);

    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "pc_selector_tb failed");
    $finish;
  end

endmodule
