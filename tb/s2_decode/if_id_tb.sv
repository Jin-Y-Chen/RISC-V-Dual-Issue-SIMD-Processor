`timescale 1ns / 1ps

// if_id_tb - dual IF/ID pipeline register behavior (reset / stall / flush).
module if_id_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic        stall;
  logic        flush;
  logic [31:0] i0_instr_if;
  logic [31:0] i1_instr_if;
  logic [31:0] i0_pc_if;
  logic [31:0] i1_pc_if;
  logic [31:0] i0_pc_target_if;
  logic [31:0] i1_pc_target_if;
  logic [31:0] i0_instr_id;
  logic [31:0] i1_instr_id;
  logic [31:0] i0_pc_id;
  logic [31:0] i1_pc_id;
  logic [31:0] i0_pc_target_id;
  logic [31:0] i1_pc_target_id;

  int pass_cnt;
  int fail_cnt;

  if_id dut (.*);

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic drive_if(
    input logic [31:0] i0_instr_v,
    input logic [31:0] i1_instr_v,
    input logic [31:0] i0_pc_v,
    input logic [31:0] i1_pc_v,
    input logic [31:0] i0_pc_target_v,
    input logic [31:0] i1_pc_target_v
  );
    i0_instr_if     = i0_instr_v;
    i1_instr_if     = i1_instr_v;
    i0_pc_if        = i0_pc_v;
    i1_pc_if        = i1_pc_v;
    i0_pc_target_if = i0_pc_target_v;
    i1_pc_target_if = i1_pc_target_v;
  endtask

  task automatic check_id(
    input string       name,
    input string       detail,
    input logic [31:0] exp_i0_instr,
    input logic [31:0] exp_i1_instr,
    input logic [31:0] exp_i0_pc,
    input logic [31:0] exp_i1_pc,
    input logic [31:0] exp_i0_pc_target,
    input logic [31:0] exp_i1_pc_target
  );
    bit pass;
    pass = (i0_instr_id === exp_i0_instr) &&
           (i1_instr_id === exp_i1_instr) &&
           (i0_pc_id === exp_i0_pc) &&
           (i1_pc_id === exp_i1_pc) &&
           (i0_pc_target_id === exp_i0_pc_target) &&
           (i1_pc_target_id === exp_i1_pc_target);
    tb_report_open(pass, name, detail);
    tb_field_u32("i0_instr_id", i0_instr_id, exp_i0_instr);
    tb_field_u32("i1_instr_id", i1_instr_id, exp_i1_instr);
    tb_field_u32("i0_pc_id", i0_pc_id, exp_i0_pc);
    tb_field_u32("i1_pc_id", i1_pc_id, exp_i1_pc);
    tb_field_u32("i0_pc_target_id", i0_pc_target_id, exp_i0_pc_target);
    tb_field_u32("i1_pc_target_id", i1_pc_target_id, exp_i1_pc_target);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    // Bringup
    rst_n   = 1'b0;
    enable  = 1'b1;
    stall = 1'b0;
    flush   = 1'b0;
    drive_if(32'hFFFF_FFFF, 32'hEEEE_EEEE, 32'h1111_1111, 32'h1111_1115,
             32'h2222_2222, 32'h2222_2226);
    tick();
    check_id("reset_clear", "reset clears both IF/ID outputs",
             32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0);

    rst_n = 1'b1;
    drive_if(32'h00C5_8633, 32'h0052_0213, 32'h0000_1000, 32'h0000_1004,
             32'h0000_1200, 32'h0000_1300);
    tick();
    check_id("capture", "normal cycle captures both IF inputs",
             32'h00C5_8633, 32'h0052_0213, 32'h0000_1000, 32'h0000_1004,
             32'h0000_1200, 32'h0000_1300);

    stall = 1'b1;
    drive_if(32'hDEAD_BEEF, 32'hCAFE_BABE, 32'h0000_2000, 32'h0000_2004,
             32'h0000_3000, 32'h0000_3004);
    tick();
    check_id("stall_hold", "stall holds previous ID state for both slots",
             32'h00C5_8633, 32'h0052_0213, 32'h0000_1000, 32'h0000_1004,
             32'h0000_1200, 32'h0000_1300);

    stall = 1'b0;
    flush   = 1'b1;
    drive_if(32'h1234_5678, 32'h8765_4321, 32'h0000_4000, 32'h0000_4004,
             32'h0000_5000, 32'h0000_5004);
    tick();
    check_id("flush_clear", "flush clears both ID slots to bubble",
             32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0);

    // flush has priority over stall in DUT.
    stall = 1'b1;
    flush   = 1'b1;
    drive_if(32'hABCD_EF01, 32'h10FE_ED01, 32'h0000_6000, 32'h0000_6004,
             32'h0000_7000, 32'h0000_7004);
    tick();
    check_id("flush_over_stall", "flush wins when both controls are set",
             32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0);

    stall = 1'b0;
    flush   = 1'b0;
    drive_if(32'h0052_0213, 32'h00C5_8633, 32'h0000_1004, 32'h0000_1008,
             32'h0000_1300, 32'h0000_1400);
    tick();
    check_id("capture_after_flush", "pipeline captures again after clear controls",
             32'h0052_0213, 32'h00C5_8633, 32'h0000_1004, 32'h0000_1008,
             32'h0000_1300, 32'h0000_1400);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "if_id_tb failed");
    $finish;
  end

endmodule
