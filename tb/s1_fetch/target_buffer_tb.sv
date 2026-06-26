`timescale 1ns / 1ps

// target_buffer_tb — BTB lookup (miss => pc+4) and per-slot WB update.
module target_buffer_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  localparam logic [31:0] PC0       = 32'h0000_1000;
  localparam logic [31:0] PC1       = 32'h0000_1004;
  localparam logic [31:0] BR_PC     = 32'h0000_2000;
  localparam logic [31:0] BR_TARGET = 32'h0000_3000;

  logic        clk;
  logic        rst_n;
  logic [31:0] i0_pc;
  logic [31:0] i1_pc;
  logic        i0_valid_wb;
  logic        i1_valid_wb;
  logic [31:0] i0_pc_wb;
  logic [31:0] i1_pc_wb;
  logic [31:0] i0_target_wb;
  logic [31:0] i1_target_wb;
  logic [31:0] i0_pc_target;
  logic [31:0] i1_pc_target;

  int pass_cnt;
  int fail_cnt;

  target_buffer dut (.*);

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    tb_advance(clk);
  endtask

  task automatic check_targets(
    input string       name,
    input string       detail,
    input logic [31:0] exp_t0,
    input logic [31:0] exp_t1
  );
    bit pass;
    #0;
    pass = (i0_pc_target === exp_t0) && (i1_pc_target === exp_t1);
    tb_report_open(pass, name, detail);
    tb_field_u32("i0_pc_target", i0_pc_target, exp_t0);
    tb_field_u32("i1_pc_target", i1_pc_target, exp_t1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    i0_valid_wb  = 1'b0;
    i1_valid_wb  = 1'b0;
    i0_pc_wb     = '0;
    i1_pc_wb     = '0;
    i0_target_wb = '0;
    i1_target_wb = '0;

    tb_banner("target_buffer_tb - miss fall-through and WB update");

    rst_n = 1'b0;
    i0_pc = PC0;
    i1_pc = PC1;
    tick();
    rst_n = 1'b1;

    check_targets("miss_fallthrough",
                  "cold BTB predicts sequential pc+4",
                  PC0 + 32'd4, PC1 + 32'd4);

    i0_pc_wb     = BR_PC;
    i0_target_wb = BR_TARGET;
    i0_valid_wb  = 1'b1;
    tick();
    i0_valid_wb  = 1'b0;

    i0_pc = BR_PC;
    i1_pc = PC1;
    check_targets("update_hit",
                  "WB-updated branch PC returns stored target",
                  BR_TARGET, PC1 + 32'd4);

    i0_pc = 32'h0000_4000;
    check_targets("index_miss",
                  "untrained PC index => fall-through",
                  32'h0000_4000 + 32'd4, PC1 + 32'd4);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "target_buffer_tb failed");
    $finish;
  end

endmodule
