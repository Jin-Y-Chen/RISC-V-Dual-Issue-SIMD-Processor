`timescale 1ns / 1ps

import rv_dis_pkg::word_t;

`include "../include/tb_console.svh"

// target_buffer_tb — BTB lookup/WB; DUT vs gm/target_buffer_gm.sv.
module target_buffer_tb;

  localparam int INDEX_W = 13;
  localparam int WAYS    = 16;

  localparam word_t PC0       = word_t'(32'h0000_1000);
  localparam word_t PC1       = word_t'(32'h0000_1004);
  localparam word_t BR_PC     = word_t'(32'h0000_2000);
  localparam word_t BR_TARGET = word_t'(32'h0000_3000);
  localparam word_t BR2_PC    = word_t'(32'h0000_2010);
  localparam word_t BR2_TGT   = word_t'(32'h0000_4000);
  localparam word_t COLD_PC   = word_t'(32'h0000_8000);

  logic [31:0] i0_pc;
  logic [31:0] i1_pc;
  logic        i0_valid_wb;
  logic        i1_valid_wb;
  logic [31:0] i0_pc_wb;
  logic [31:0] i1_pc_wb;
  logic [31:0] i0_pc_target_wb;
  logic [31:0] i1_pc_target_wb;
  logic [31:0] i0_pc_target;
  logic [31:0] i1_pc_target;
  logic [31:0] ref_i0_pc_target;
  logic [31:0] ref_i1_pc_target;
  logic        clk;
  logic        rst_n;

  int pass_cnt;
  int fail_cnt;

  target_buffer #(
    .INDEX_W(INDEX_W),
    .WAYS   (WAYS)
  ) dut (.*);

  target_buffer_gm #(
    .INDEX_W(INDEX_W),
    .WAYS   (WAYS)
  ) u_target_gm (
    .clk             (clk),
    .rst_n           (rst_n),
    .i0_pc           (i0_pc),
    .i1_pc           (i1_pc),
    .i0_valid_wb     (i0_valid_wb),
    .i1_valid_wb     (i1_valid_wb),
    .i0_pc_wb        (i0_pc_wb),
    .i1_pc_wb        (i1_pc_wb),
    .i0_pc_target_wb (i0_pc_target_wb),
    .i1_pc_target_wb (i1_pc_target_wb),
    .i0_pc_target    (ref_i0_pc_target),
    .i1_pc_target    (ref_i1_pc_target)
  );

  task automatic drive(
    input word_t i0_pc_v,
    input word_t i1_pc_v,
    input logic  v0_wb,
    input word_t pc0_wb,
    input word_t tgt0_wb,
    input logic  v1_wb,
    input word_t pc1_wb,
    input word_t tgt1_wb
  );
    i0_pc           = i0_pc_v;
    i1_pc           = i1_pc_v;
    i0_valid_wb     = v0_wb;
    i1_valid_wb     = v1_wb;
    i0_pc_wb        = pc0_wb;
    i1_pc_wb        = pc1_wb;
    i0_pc_target_wb = tgt0_wb;
    i1_pc_target_wb = tgt1_wb;
    #0;
    @(posedge clk);
  endtask

  task automatic check_state(input string name, input string detail);
    bit pass;

    pass = (i0_pc_target === ref_i0_pc_target) && (i1_pc_target === ref_i1_pc_target);

    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_u32("i0_pc",           i0_pc);
    tb_field_in_u32("i1_pc",           i1_pc);
    tb_field_in_bit("i0_valid_wb",     i0_valid_wb);
    tb_field_in_bit("i1_valid_wb",     i1_valid_wb);
    tb_field_in_u32("i0_pc_wb",        i0_pc_wb);
    tb_field_in_u32("i1_pc_wb",        i1_pc_wb);
    tb_field_in_u32("i0_pc_target_wb", i0_pc_target_wb);
    tb_field_in_u32("i1_pc_target_wb", i1_pc_target_wb);
    $display("");
    tb_log_section("check");
    tb_field_u32("i0_pc_target", i0_pc_target, ref_i0_pc_target);
    tb_field_u32("i1_pc_target", i1_pc_target, ref_i1_pc_target);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    i0_valid_wb     = 1'b0;
    i1_valid_wb     = 1'b0;
    i0_pc_wb        = '0;
    i1_pc_wb        = '0;
    i0_pc_target_wb = '0;
    i1_pc_target_wb = '0;

    clk   = 1'b0;
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    tb_banner("target_buffer_tb — DUT vs target_buffer_gm.sv");

    drive(PC0, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("cold_miss", "empty bank => i0/i1 predict sequential pc+4");

    drive(PC0, PC1, 1'b1, BR_PC, BR_TARGET, 1'b0, '0, '0);
    check_state("i0_wb_train", "WB cycle still reads prior miss (lookup pc unchanged)");

    drive(BR_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("i0_wb_hit", "trained branch PC returns stored target on I0");

    drive(PC0, PC1, 1'b0, '0, '0, 1'b1, BR2_PC, BR2_TGT);
    check_state("i1_wb_train", "I1 WB installs second entry");

    drive(PC0, BR2_PC, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("i1_wb_hit", "I1 trained PC returns stored target");

    drive(PC0, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    drive(PC0, PC1,
          1'b1, PC0, word_t'(32'h0000_A000),
          1'b1, PC1, word_t'(32'h0000_B004));
    check_state("dual_wb_same_cycle",
                "both WB valid same cycle — each way updated independently");

    drive(PC0, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("dual_wb_hit", "both slots hit their trained targets");

    drive(BR_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    drive(BR_PC, PC1,
          1'b1, BR_PC, word_t'(32'h0000_D003),
          1'b0, '0,    '0);
    check_state("overwrite_align",
                "re-train same index overwrites; target imm_align4 on store");

    drive(BR_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("overwrite_hit", "read returns updated aligned target 0xD000");

    drive(COLD_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("index_miss", "untrained PC => fallthrough; other slot unchanged");

    drive(COLD_PC, PC1,
          1'b1, COLD_PC, word_t'(32'h0000_E000),
          1'b0, '0,      '0);
    check_state("read_during_wb",
                "lookup pc == wb pc same cycle => hit new target immediately");

    drive(BR_PC, BR_PC, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("dual_port_same_pc", "i0_pc == i1_pc => identical targets");

    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "target_buffer_tb failed");
    $finish;
  end

endmodule
