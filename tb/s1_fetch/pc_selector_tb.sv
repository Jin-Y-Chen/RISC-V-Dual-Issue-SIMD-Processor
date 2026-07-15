`timescale 1ns / 1ps

`include "../include/tb_console.svh"

// pc_selector_tb - exhaustive 6-bit control sweep; reference = gm/pc_selector_gm.sv.
// ctrl = {spec0_in, spec1_in, i0_pred, i1_pred, i0_rec, i1_rec}
module pc_selector_tb;

  localparam int CTRL_BITS  = 6;
  localparam int N_VECTORS  = 1 << CTRL_BITS;
  localparam int CLK_PERIOD = 10;

  localparam logic [31:0] PC0_IN = 32'h0000_1000;
  localparam logic [31:0] PC1_IN = 32'h0000_1004;
  localparam logic [31:0] TGT0   = 32'h0000_2000;
  localparam logic [31:0] TGT1   = 32'h0000_3000;
  localparam logic [31:0] EXEC0  = 32'h0000_4000;
  localparam logic [31:0] EXEC1  = 32'h0000_5000;

  logic        spec0_in;
  logic        spec1_in;
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
  logic        spec0_out;
  logic        spec1_out;
  logic [31:0] pc0_out;
  logic [31:0] pc1_out;

  logic        ref_spec0_out;
  logic        ref_spec1_out;
  logic [31:0] ref_pc0_out;
  logic [31:0] ref_pc1_out;

  logic        clk;

  int pass_cnt;
  int fail_cnt;

  pc_selector dut (
    .spec0_in        (spec0_in),
    .spec1_in        (spec1_in),
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
    .spec0_out       (spec0_out),
    .spec1_out       (spec1_out),
    .pc0_out         (pc0_out),
    .pc1_out         (pc1_out)
  );

  pc_selector_gm u_pc_selector_gm (
    .spec0_in        (spec0_in),
    .spec1_in        (spec1_in),
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
    .spec0_out       (ref_spec0_out),
    .spec1_out       (ref_spec1_out),
    .pc0_out         (ref_pc0_out),
    .pc1_out         (ref_pc1_out)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk;

  task automatic check_vector(input int unsigned ctrl);
    bit pass;
    string detail;

    @(posedge clk);
    spec0_in        = ctrl[5];
    spec1_in        = ctrl[4];
    i0_pred_taken   = ctrl[3];
    i1_pred_taken   = ctrl[2];
    i0_brch_recover = ctrl[1];
    i1_brch_recover = ctrl[0];
    pc0_in          = PC0_IN;
    pc1_in          = PC1_IN;
    i0_pc_target    = TGT0;
    i1_pc_target    = TGT1;
    i0_pc_execute   = EXEC0;
    i1_pc_execute   = EXEC1;
    #0;

    pass = (spec0_out === ref_spec0_out) && (spec1_out === ref_spec1_out)
        && (pc0_out === ref_pc0_out) && (pc1_out === ref_pc1_out);

    detail = $sformatf("ctrl=%06b", ctrl[5:0]);
    tb_report_open(pass, $sformatf("ctrl_%02x", ctrl), detail);
    tb_log_section("inputs");
    tb_field_in_bit("spec0_in",        spec0_in);
    tb_field_in_bit("spec1_in",        spec1_in);
    tb_field_in_bit("i0_pred_taken",   i0_pred_taken);
    tb_field_in_bit("i1_pred_taken",   i1_pred_taken);
    tb_field_in_bit("i0_brch_recover", i0_brch_recover);
    tb_field_in_bit("i1_brch_recover", i1_brch_recover);
    tb_field_in_u32("pc0_in",          pc0_in);
    tb_field_in_u32("pc1_in",          pc1_in);
    tb_field_in_u32("i0_pc_target",    i0_pc_target);
    tb_field_in_u32("i1_pc_target",    i1_pc_target);
    tb_field_in_u32("i0_pc_execute",   i0_pc_execute);
    tb_field_in_u32("i1_pc_execute",   i1_pc_execute);
    $display("");
    tb_log_section("check");
    tb_field_bit("spec0_out", spec0_out, ref_spec0_out);
    tb_field_bit("spec1_out", spec1_out, ref_spec1_out);
    tb_field_u32("pc0_out",   pc0_out,   ref_pc0_out);
    tb_field_u32("pc1_out",   pc1_out,   ref_pc1_out);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    int unsigned ctrl;

    pass_cnt = 0;
    fail_cnt = 0;
    tb_banner($sformatf("pc_selector_tb: DUT vs pc_selector_gm.sv (%0d vectors)", N_VECTORS));

    for (ctrl = 0; ctrl < N_VECTORS; ctrl++)
      check_vector(ctrl);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (pass_cnt + fail_cnt != N_VECTORS)
      $error("pc_selector_tb: expected %0d vectors, ran %0d", N_VECTORS, pass_cnt + fail_cnt);
    else if (fail_cnt != 0)
      $error("pc_selector_tb: %0d failure(s)", fail_cnt);
    $finish;
  end

endmodule
