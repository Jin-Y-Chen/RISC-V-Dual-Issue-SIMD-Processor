`timescale 1ns / 1ps

// if_id_tb - DUT vs gm/if_id_gm.sv (flush/stall/enable + per-lane fetch_valid).

import rv_dis_pkg::*;

`include "../../common/utils/tb_console.svh"

module if_id_tb;

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic        stall;
  logic        flush;
  logic        i0_fetch_valid, i1_fetch_valid;
  logic        i0_target_valid_if, i1_target_valid_if;
  logic        spec0_en_if, spec1_en_if;
  logic [31:0] i0_instr_if, i1_instr_if;
  logic [31:0] i0_pc_if, i1_pc_if;
  logic [31:0] i0_pc_target_if, i1_pc_target_if;
  logic [31:0] i0_instr_id, i1_instr_id;
  logic [31:0] i0_pc_id, i1_pc_id;
  logic [31:0] i0_pc_target_id, i1_pc_target_id;
  logic        i0_target_valid_id, i1_target_valid_id;
  logic        spec0_en_id, spec1_en_id;

  logic [31:0] ref_i0_instr_id, ref_i1_instr_id;
  logic [31:0] ref_i0_pc_id, ref_i1_pc_id;
  logic [31:0] ref_i0_pc_target_id, ref_i1_pc_target_id;
  logic        ref_i0_target_valid_id, ref_i1_target_valid_id;
  logic        ref_spec0_en_id, ref_spec1_en_id;

  int pass_cnt;
  int fail_cnt;

  if_id dut (.*);

  if_id_gm u_if_id_gm (
    .clk                 (clk),
    .rst_n               (rst_n),
    .enable              (enable),
    .flush               (flush),
    .stall               (stall),
    .i0_fetch_valid      (i0_fetch_valid),
    .i1_fetch_valid      (i1_fetch_valid),
    .i0_target_valid_if  (i0_target_valid_if),
    .i1_target_valid_if  (i1_target_valid_if),
    .spec0_en_if         (spec0_en_if),
    .spec1_en_if         (spec1_en_if),
    .i0_instr_if         (i0_instr_if),
    .i1_instr_if         (i1_instr_if),
    .i0_pc_if            (i0_pc_if),
    .i1_pc_if            (i1_pc_if),
    .i0_pc_target_if     (i0_pc_target_if),
    .i1_pc_target_if     (i1_pc_target_if),
    .i0_instr_id         (ref_i0_instr_id),
    .i1_instr_id         (ref_i1_instr_id),
    .i0_pc_id            (ref_i0_pc_id),
    .i1_pc_id            (ref_i1_pc_id),
    .i0_pc_target_id     (ref_i0_pc_target_id),
    .i1_pc_target_id     (ref_i1_pc_target_id),
    .i0_target_valid_id  (ref_i0_target_valid_id),
    .i1_target_valid_id  (ref_i1_target_valid_id),
    .spec0_en_id         (ref_spec0_en_id),
    .spec1_en_id         (ref_spec1_en_id)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk;

  task automatic tick;
    tb_advance(clk);
  endtask

  task automatic drive_if(
    input logic        i0_fv,
    input logic        i1_fv,
    input logic        i0_tv,
    input logic        i1_tv,
    input logic        spec0_v,
    input logic        spec1_v,
    input logic [31:0] i0_instr_v,
    input logic [31:0] i1_instr_v,
    input logic [31:0] i0_pc_v,
    input logic [31:0] i1_pc_v,
    input logic [31:0] i0_pc_target_v,
    input logic [31:0] i1_pc_target_v
  );
    i0_fetch_valid     = i0_fv;
    i1_fetch_valid     = i1_fv;
    i0_target_valid_if = i0_tv;
    i1_target_valid_if = i1_tv;
    spec0_en_if     = spec0_v;
    spec1_en_if     = spec1_v;
    i0_instr_if     = i0_instr_v;
    i1_instr_if     = i1_instr_v;
    i0_pc_if        = i0_pc_v;
    i1_pc_if        = i1_pc_v;
    i0_pc_target_if = i0_pc_target_v;
    i1_pc_target_if = i1_pc_target_v;
  endtask

  task automatic check_id(input string name, input string detail);
    bit pass;
    pass = (i0_instr_id === ref_i0_instr_id) &&
           (i1_instr_id === ref_i1_instr_id) &&
           (i0_pc_id === ref_i0_pc_id) &&
           (i1_pc_id === ref_i1_pc_id) &&
           (i0_pc_target_id === ref_i0_pc_target_id) &&
           (i1_pc_target_id === ref_i1_pc_target_id) &&
           (i0_target_valid_id === ref_i0_target_valid_id) &&
           (i1_target_valid_id === ref_i1_target_valid_id) &&
           (spec0_en_id === ref_spec0_en_id) &&
           (spec1_en_id === ref_spec1_en_id);
    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_bit("clk",                clk);
    tb_field_in_bit("rst_n",              rst_n);
    tb_field_in_bit("enable",             enable);
    tb_field_in_bit("flush",              flush);
    tb_field_in_bit("stall",              stall);
    tb_field_in_bit("i0_fetch_valid",     i0_fetch_valid);
    tb_field_in_bit("i1_fetch_valid",     i1_fetch_valid);
    tb_field_in_bit("i0_target_valid_if", i0_target_valid_if);
    tb_field_in_bit("i1_target_valid_if", i1_target_valid_if);
    tb_field_in_bit("spec0_en_if",        spec0_en_if);
    tb_field_in_bit("spec1_en_if",        spec1_en_if);
    tb_field_in_u32("i0_instr_if",        i0_instr_if);
    tb_field_in_u32("i1_instr_if",        i1_instr_if);
    tb_field_in_u32("i0_pc_if",           i0_pc_if);
    tb_field_in_u32("i1_pc_if",           i1_pc_if);
    tb_field_in_u32("i0_pc_target_if",    i0_pc_target_if);
    tb_field_in_u32("i1_pc_target_if",    i1_pc_target_if);
    $display("");
    tb_log_section("check");
    tb_field_bit("i0_target_valid_id", i0_target_valid_id, ref_i0_target_valid_id);
    tb_field_bit("i1_target_valid_id", i1_target_valid_id, ref_i1_target_valid_id);
    tb_field_bit("spec0_en_id", spec0_en_id, ref_spec0_en_id);
    tb_field_bit("spec1_en_id", spec1_en_id, ref_spec1_en_id);
    tb_field_u32("i0_instr_id", i0_instr_id, ref_i0_instr_id);
    tb_field_u32("i1_instr_id", i1_instr_id, ref_i1_instr_id);
    tb_field_u32("i0_pc_id", i0_pc_id, ref_i0_pc_id);
    tb_field_u32("i1_pc_id", i1_pc_id, ref_i1_pc_id);
    tb_field_u32("i0_pc_target_id", i0_pc_target_id, ref_i0_pc_target_id);
    tb_field_u32("i1_pc_target_id", i1_pc_target_id, ref_i1_pc_target_id);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("if_id_tb: DUT vs if_id_gm.sv");

    rst_n  = 1'b0;
    enable = 1'b1;
    stall  = 1'b0;
    flush  = 1'b0;
    drive_if(1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0,
             32'hFFFF_FFFF, 32'hEEEE_EEEE, 32'h1111_1111, 32'h1111_1115,
             32'h2222_2222, 32'h2222_2226);
    tick();
    check_id("reset_clear", "reset clears both IF/ID outputs");

    rst_n = 1'b1;
    drive_if(1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0,
             32'h00C5_8633, 32'h0052_0213, 32'h0000_1000, 32'h0000_1004,
             32'h0000_1200, 32'h0000_1300);
    tick();
    check_id("capture_both", "both fetch_valid clocks both lanes");

    stall = 1'b1;
    drive_if(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
             32'hDEAD_BEEF, 32'hCAFE_BABE, 32'h0000_2000, 32'h0000_2004,
             32'h0000_3000, 32'h0000_3004);
    tick();
    check_id("stall_hold", "stall holds previous ID state for both slots");

    stall = 1'b0;
    flush = 1'b1;
    drive_if(1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1,
             32'h1234_5678, 32'h8765_4321, 32'h0000_4000, 32'h0000_4004,
             32'h0000_5000, 32'h0000_5004);
    tick();
    check_id("flush_clear", "flush clears both ID slots to bubble");

    stall = 1'b1;
    flush = 1'b1;
    drive_if(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1,
             32'hABCD_EF01, 32'h10FE_ED01, 32'h0000_6000, 32'h0000_6004,
             32'h0000_7000, 32'h0000_7004);
    tick();
    check_id("flush_over_stall", "flush wins when both controls are set");

    stall = 1'b0;
    flush = 1'b0;
    drive_if(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1,
             32'h0052_0213, 32'h00C5_8633, 32'h0000_1004, 32'h0000_1008,
             32'h0000_1300, 32'h0000_1400);
    tick();
    check_id("capture_i0_only", "i1 miss: i1 -> INSTR_NOP bubble");

    drive_if(1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0,
             32'h1111_1111, 32'h00A0_0293, 32'h0000_2000, 32'h0000_2004,
             32'h0000_2100, 32'h0000_2200);
    tick();
    check_id("capture_i1_only", "i0 miss: i0 -> INSTR_NOP bubble");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "if_id_tb failed");
    $finish;
  end

endmodule
