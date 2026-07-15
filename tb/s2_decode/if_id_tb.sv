`timescale 1ns / 1ps

// if_id_tb - DUT vs gm/if_id_gm.sv (4-bit CLEAR/HOLD/CAPTURE LUT).

import rv_dis_pkg::*;

`include "../include/tb_console.svh"

module if_id_tb;

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic        stall;
  logic        flush;
  logic        i0_valid_if, i1_valid_if;
  br_map_t     br_map_if;
  logic [31:0] i0_instr_if, i1_instr_if;
  logic [31:0] i0_pc_if, i1_pc_if;
  logic [31:0] i0_pc_target_if, i1_pc_target_if;
  logic [31:0] i0_instr_id, i1_instr_id;
  logic [31:0] i0_pc_id, i1_pc_id;
  logic [31:0] i0_pc_target_id, i1_pc_target_id;
  logic        i0_valid_id, i1_valid_id;
  br_map_t     br_map_id;

  logic [31:0] ref_i0_instr_id, ref_i1_instr_id;
  logic [31:0] ref_i0_pc_id, ref_i1_pc_id;
  logic [31:0] ref_i0_pc_target_id, ref_i1_pc_target_id;
  logic        ref_i0_valid_id, ref_i1_valid_id;
  br_map_t     ref_br_map_id;

  int pass_cnt;
  int fail_cnt;

  if_id dut (.*);
  if_id_gm u_if_id_gm (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    .flush           (flush),
    .stall           (stall),
    .i0_valid_if     (i0_valid_if),
    .i1_valid_if     (i1_valid_if),
    .br_map_if       (br_map_if),
    .i0_instr_if     (i0_instr_if),
    .i1_instr_if     (i1_instr_if),
    .i0_pc_if        (i0_pc_if),
    .i1_pc_if        (i1_pc_if),
    .i0_pc_target_if (i0_pc_target_if),
    .i1_pc_target_if (i1_pc_target_if),
    .i0_instr_id     (ref_i0_instr_id),
    .i1_instr_id     (ref_i1_instr_id),
    .i0_pc_id        (ref_i0_pc_id),
    .i1_pc_id        (ref_i1_pc_id),
    .i0_pc_target_id (ref_i0_pc_target_id),
    .i1_pc_target_id (ref_i1_pc_target_id),
    .i0_valid_id     (ref_i0_valid_id),
    .i1_valid_id     (ref_i1_valid_id),
    .br_map_id       (ref_br_map_id)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk;

  task automatic tick;
    tb_advance(clk);
  endtask

  task automatic drive_if(
    input logic        i0_valid_v,
    input logic        i1_valid_v,
    input br_map_t     br_map_v,
    input logic [31:0] i0_instr_v,
    input logic [31:0] i1_instr_v,
    input logic [31:0] i0_pc_v,
    input logic [31:0] i1_pc_v,
    input logic [31:0] i0_pc_target_v,
    input logic [31:0] i1_pc_target_v
  );
    i0_valid_if     = i0_valid_v;
    i1_valid_if     = i1_valid_v;
    br_map_if       = br_map_v;
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
           (i0_valid_id === ref_i0_valid_id) &&
           (i1_valid_id === ref_i1_valid_id) &&
           (br_map_id === ref_br_map_id);
    tb_report_open(pass, name, detail);
    tb_field_bit("i0_valid_id", i0_valid_id, ref_i0_valid_id);
    tb_field_bit("i1_valid_id", i1_valid_id, ref_i1_valid_id);
    tb_field_u32("br_map_id", {30'b0, br_map_id}, {30'b0, ref_br_map_id});
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
    pass_cnt = 0; fail_cnt = 0;
    rst_n = 0; enable = 0; flush = 0; stall = 0;
    drive_if(0, 0, BR_MAP_NONE, 0, 0, 0, 0, 0, 0);
    tb_banner("if_id_tb: DUT vs if_id_gm.sv");

    tick();
    rst_n = 1; enable = 1;
    tick();
    check_id("reset_clear", "after reset");

    drive_if(1, 1, BR_MAP_I0, 32'h1111_0000, 32'h2222_0000,
             32'h1000, 32'h1004, 32'h2000, 32'h2004);
    tick();
    check_id("capture", "br_map=01 captured");

    stall = 1;
    drive_if(1, 0, BR_MAP_BOTH, 32'hDEAD, 32'hBEEF, 0, 0, 0, 0);
    tick();
    check_id("stall_hold", "stall holds previous");

    stall = 0; flush = 1;
    tick();
    check_id("flush_clear", "flush clears");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0) $error("if_id_tb: %0d failure(s)", fail_cnt);
    $finish;
  end

endmodule
