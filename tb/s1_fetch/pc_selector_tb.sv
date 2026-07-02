`timescale 1ns / 1ps

// pc_selector_tb — I0-only speculation; spec state modeled in TB register.
module pc_selector_tb;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic [31:0] pc0;
  logic [31:0] pc1;
  logic [31:0] i0_pc_predict;
  logic        i0_pred_taken;
  logic        i1_pred_taken;
  logic        recover_en;
  logic        recover_correct;
  logic        recover_i0;
  logic        recover_i1;
  logic        recover_use_exec_pc;
  logic [31:0] recover_pc;
  logic        in_spec_q;
  logic        spec;
  logic [31:0] spec_out;
  logic [31:0] norm_out;
  logic        flush;

  int pass_cnt;
  int fail_cnt;

  pc_selector dut (
    .enable              (enable),
    .in_spec             (in_spec_q),
    .pc0                 (pc0),
    .pc1                 (pc1),
    .i0_pc_predict       (i0_pc_predict),
    .i0_pred_taken      (i0_pred_taken),
    .recover_en          (recover_en),
    .recover_correct     (recover_correct),
    .recover_i0          (recover_i0),
    .recover_pc          (recover_pc),
    .recover_use_exec_pc (recover_use_exec_pc),
    .spec                (spec),
    .spec_out            (spec_out),
    .norm_out            (norm_out),
    .flush               (flush)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk = ~clk;

  always_ff @(posedge clk) begin
    if (!rst_n)
      in_spec_q <= 1'b0;
    else
      in_spec_q <= spec;
  end

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic check_comb(
    input string       name,
    input logic [31:0] exp_spec_out,
    input logic [31:0] exp_norm_out,
    input logic        exp_flush
  );
    bit pass;
    pass = (spec_out === exp_spec_out) && (norm_out === exp_norm_out) && (flush === exp_flush);
    tb_report_open(pass, name, "");
    tb_field_u32("spec_out", spec_out, exp_spec_out);
    tb_field_u32("norm_out", norm_out, exp_norm_out);
    tb_field_bit("flush", flush, exp_flush);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_spec_next(input string name, input logic exp_spec);
    bit pass;
    pass = (spec === exp_spec);
    tb_report_open(pass, name, "");
    tb_field_bit("spec", spec, exp_spec);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_spec_q(input string name, input logic exp_spec);
    bit pass;
    pass = (in_spec_q === exp_spec);
    tb_report_open(pass, name, "");
    tb_field_bit("in_spec_q", in_spec_q, exp_spec);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    rst_n = 1'b0;
    enable = 1'b0;
    in_spec_q = 1'b0;
    pc0 = 32'h1000;
    pc1 = 32'h1004;
    i0_pc_predict = 32'h2000;
    i0_pred_taken = 1'b0;
    i1_pred_taken = 1'b0;
    recover_en = 1'b0;
    recover_correct = 1'b0;
    recover_i0 = 1'b0;
    recover_i1 = 1'b0;
    recover_use_exec_pc = 1'b0;
    recover_pc = 32'd0;
    tick();
    rst_n = 1'b1;
    enable = 1'b1;
    tick();

    tb_banner("pc_selector_tb");
    check_comb("default_pass", 32'h1000, 32'h1000, 1'b0);
    check_spec_next("idle_spec_next", 1'b0);

    i0_pred_taken = 1'b1;
    #1;
    check_comb("i0 predict comb", 32'h1FFC, 32'h1004, 1'b0);
    check_spec_next("i0 predict spec next", 1'b1);
    tick();
    i0_pred_taken = 1'b0;
    pc0 = 32'h2000;
    pc1 = 32'h1008;
    check_spec_q("i0 predict spec q", 1'b1);

    check_comb("in_spec_default", 32'h2000, 32'h1008, 1'b0);

    i1_pred_taken = 1'b1;
    #1;
    check_comb("i1 predict ignored", 32'h2000, 32'h1008, 1'b0);
    check_spec_next("i1 predict ignored spec", 1'b1);
    i1_pred_taken = 1'b0;

    recover_en = 1'b1;
    recover_correct = 1'b1;
    recover_i0 = 1'b1;
    #1;
    check_comb("recover correct i0", 32'h1FFC, 32'h2000, 1'b1);
    check_spec_next("recover clears spec next", 1'b0);
    tick();
    recover_en = 1'b0;
    recover_i0 = 1'b0;
    pc0 = 32'h2000;
    pc1 = 32'h2004;
    check_spec_q("recover clears spec q", 1'b0);

    pc0 = 32'h1000;
    pc1 = 32'h1004;
    recover_en = 1'b1;
    recover_correct = 1'b0;
    recover_i0 = 1'b1;
    recover_use_exec_pc = 1'b1;
    recover_pc = 32'h4004;
    #1;
    check_comb("recover wrong i0 exec", 32'h4000, 32'h4004, 1'b1);
    tick();
    recover_en = 1'b0;
    recover_use_exec_pc = 1'b0;
    recover_i0 = 1'b0;

    recover_en = 1'b1;
    recover_i0 = 1'b1;
    pc0 = 32'h1000;
    pc1 = 32'h1004;
    #1;
    check_comb("recover wrong i0 fallback", 32'h1004, 32'h1008, 1'b1);
    tick();
    recover_en = 1'b0;
    recover_i0 = 1'b0;

    recover_en = 1'b1;
    recover_i1 = 1'b1;
    #1;
    check_comb("recover i1 ignored", 32'h1000, 32'h1000, 1'b0);
    tick();
    recover_en = 1'b0;
    recover_i1 = 1'b0;

    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "pc_selector_tb failed");
    $finish;
  end

endmodule
