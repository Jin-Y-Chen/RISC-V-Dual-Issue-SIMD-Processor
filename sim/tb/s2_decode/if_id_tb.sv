`timescale 1ns / 1ps

// if_id_tb - IF/ID pipeline register behavior (reset / stall / flush).
module if_id_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;
  logic        stall_if_id;
  logic        flush_if_id;
  logic [31:0] instr_if;
  logic [31:0] pc_if;
  logic [31:0] pc_target_if;
  logic [31:0] instr_id;
  logic [31:0] pc_id;
  logic [31:0] pc_target_id;

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
    input logic [31:0] instr_v,
    input logic [31:0] pc_v,
    input logic [31:0] pc_target_v
  );
    instr_if     = instr_v;
    pc_if        = pc_v;
    pc_target_if = pc_target_v;
  endtask

  task automatic check_id(
    input string       name,
    input string       detail,
    input logic [31:0] exp_instr,
    input logic [31:0] exp_pc,
    input logic [31:0] exp_pc_target
  );
    bit pass;
    pass = (instr_id === exp_instr) &&
           (pc_id === exp_pc) &&
           (pc_target_id === exp_pc_target);
    tb_report_open(pass, name, detail);
    tb_field_u32("instr_id", instr_id, exp_instr);
    tb_field_u32("pc_id", pc_id, exp_pc);
    tb_field_u32("pc_target_id", pc_target_id, exp_pc_target);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    // Bringup
    rst_n       = 1'b0;
    stall_if_id = 1'b0;
    flush_if_id = 1'b0;
    drive_if(32'hFFFF_FFFF, 32'h1111_1111, 32'h2222_2222);
    tick();
    check_id("reset_clear", "reset clears IF/ID outputs", 32'd0, 32'd0, 32'd0);

    rst_n = 1'b1;
    drive_if(32'h00C5_8633, 32'h0000_1000, 32'h0000_1200);
    tick();
    check_id("capture", "normal cycle captures IF inputs", 32'h00C5_8633, 32'h0000_1000, 32'h0000_1200);

    stall_if_id = 1'b1;
    drive_if(32'hDEAD_BEEF, 32'h0000_2000, 32'h0000_3000);
    tick();
    check_id("stall_hold", "stall holds previous ID state", 32'h00C5_8633, 32'h0000_1000, 32'h0000_1200);

    stall_if_id = 1'b0;
    flush_if_id = 1'b1;
    drive_if(32'h1234_5678, 32'h0000_4000, 32'h0000_5000);
    tick();
    check_id("flush_clear", "flush clears ID state to bubble", 32'd0, 32'd0, 32'd0);

    // flush has priority over stall in DUT.
    stall_if_id = 1'b1;
    flush_if_id = 1'b1;
    drive_if(32'hABCD_EF01, 32'h0000_6000, 32'h0000_7000);
    tick();
    check_id("flush_over_stall", "flush wins when both controls are set", 32'd0, 32'd0, 32'd0);

    stall_if_id = 1'b0;
    flush_if_id = 1'b0;
    drive_if(32'h0052_0213, 32'h0000_1004, 32'h0000_1300);
    tick();
    check_id("capture_after_flush", "pipeline captures again after clear controls", 32'h0052_0213, 32'h0000_1004, 32'h0000_1300);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "if_id_tb failed");
    $finish;
  end

endmodule
