`timescale 1ns / 1ps

// if_id_tb - DUT vs gm/if_id_gm.sv (flush/stall/enable; IF->ID map).

import rv_dis_pkg::*;

`include "../../common/utils/tb_console.svh"

module if_id_tb;

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic        stall;
  logic        flush;
  logic        fetch_valid_if  [2];
  logic        target_valid_if [2];
  logic        spec_en_if      [2];
  instr_t      instr_if        [2];
  word_t       pc_if           [2];
  word_t       pc_target_if    [2];
  instr_t      instr_id         [2];
  word_t       pc_id            [2];
  word_t       pc_target_id     [2];
  logic        fetch_valid_id   [2];
  logic        target_valid_id  [2];
  logic        spec_en_id       [2];

  instr_t      ref_instr_id         [2];
  word_t       ref_pc_id            [2];
  word_t       ref_pc_target_id     [2];
  logic        ref_fetch_valid_id   [2];
  logic        ref_target_valid_id  [2];
  logic        ref_spec_en_id       [2];

  int pass_cnt;
  int fail_cnt;

  if_id dut (.*);

  if_id_gm u_if_id_gm (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    .flush           (flush),
    .stall           (stall),
    .fetch_valid_if  (fetch_valid_if),
    .target_valid_if (target_valid_if),
    .spec_en_if      (spec_en_if),
    .instr_if        (instr_if),
    .pc_if           (pc_if),
    .pc_target_if    (pc_target_if),
    .instr_id        (ref_instr_id),
    .pc_id           (ref_pc_id),
    .pc_target_id    (ref_pc_target_id),
    .fetch_valid_id  (ref_fetch_valid_id),
    .target_valid_id (ref_target_valid_id),
    .spec_en_id      (ref_spec_en_id)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk;

  task automatic tick;
    tb_advance(clk);
  endtask

  task automatic drive_if(
    input logic        fv0,
    input logic        fv1,
    input logic        tv0,
    input logic        tv1,
    input logic        spec0_v,
    input logic        spec1_v,
    input logic [31:0] instr0_v,
    input logic [31:0] instr1_v,
    input logic [31:0] pc0_v,
    input logic [31:0] pc1_v,
    input logic [31:0] pct0_v,
    input logic [31:0] pct1_v
  );
    fetch_valid_if[0]  = fv0;
    fetch_valid_if[1]  = fv1;
    target_valid_if[0] = tv0;
    target_valid_if[1] = tv1;
    spec_en_if[0]      = spec0_v;
    spec_en_if[1]      = spec1_v;
    instr_if[0]        = instr0_v;
    instr_if[1]        = instr1_v;
    pc_if[0]           = pc0_v;
    pc_if[1]           = pc1_v;
    pc_target_if[0]    = pct0_v;
    pc_target_if[1]    = pct1_v;
  endtask

  task automatic check_id(input string name, input string detail);
    bit pass;
    pass = (instr_id[0] === ref_instr_id[0]) &&
           (instr_id[1] === ref_instr_id[1]) &&
           (pc_id[0] === ref_pc_id[0]) &&
           (pc_id[1] === ref_pc_id[1]) &&
           (pc_target_id[0] === ref_pc_target_id[0]) &&
           (pc_target_id[1] === ref_pc_target_id[1]) &&
           (fetch_valid_id[0] === ref_fetch_valid_id[0]) &&
           (fetch_valid_id[1] === ref_fetch_valid_id[1]) &&
           (target_valid_id[0] === ref_target_valid_id[0]) &&
           (target_valid_id[1] === ref_target_valid_id[1]) &&
           (spec_en_id[0] === ref_spec_en_id[0]) &&
           (spec_en_id[1] === ref_spec_en_id[1]);
    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_clk(clk);
    tb_field_in_bit("rst_n",              rst_n);
    tb_field_in_bit("enable",             enable);
    tb_field_in_bit("flush",              flush);
    tb_field_in_bit("stall",              stall);
    tb_field_in_bit("fetch_valid_if[0]",  fetch_valid_if[0]);
    tb_field_in_bit("fetch_valid_if[1]",  fetch_valid_if[1]);
    tb_field_in_bit("target_valid_if[0]", target_valid_if[0]);
    tb_field_in_bit("target_valid_if[1]", target_valid_if[1]);
    tb_field_in_bit("spec_en_if[0]",      spec_en_if[0]);
    tb_field_in_bit("spec_en_if[1]",      spec_en_if[1]);
    tb_field_in_u32("instr_if[0]",        instr_if[0]);
    tb_field_in_u32("instr_if[1]",        instr_if[1]);
    tb_field_in_u32("pc_if[0]",           pc_if[0]);
    tb_field_in_u32("pc_if[1]",           pc_if[1]);
    tb_field_in_u32("pc_target_if[0]",    pc_target_if[0]);
    tb_field_in_u32("pc_target_if[1]",    pc_target_if[1]);
    $display("");
    tb_log_section("check");
    tb_field_bit("fetch_valid_id[0]", fetch_valid_id[0], ref_fetch_valid_id[0]);
    tb_field_bit("fetch_valid_id[1]", fetch_valid_id[1], ref_fetch_valid_id[1]);
    tb_field_bit("target_valid_id[0]", target_valid_id[0], ref_target_valid_id[0]);
    tb_field_bit("target_valid_id[1]", target_valid_id[1], ref_target_valid_id[1]);
    tb_field_bit("spec_en_id[0]", spec_en_id[0], ref_spec_en_id[0]);
    tb_field_bit("spec_en_id[1]", spec_en_id[1], ref_spec_en_id[1]);
    tb_field_u32("instr_id[0]", instr_id[0], ref_instr_id[0]);
    tb_field_u32("instr_id[1]", instr_id[1], ref_instr_id[1]);
    tb_field_u32("pc_id[0]", pc_id[0], ref_pc_id[0]);
    tb_field_u32("pc_id[1]", pc_id[1], ref_pc_id[1]);
    tb_field_u32("pc_target_id[0]", pc_target_id[0], ref_pc_target_id[0]);
    tb_field_u32("pc_target_id[1]", pc_target_id[1], ref_pc_target_id[1]);
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
    check_id("capture_both", "both lanes map IF -> ID");

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
    check_id("map_i1_miss_flag", "I1 fetch_valid_if=0 still maps payload; flag latched");

    drive_if(1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0,
             32'h1111_1111, 32'h00A0_0293, 32'h0000_2000, 32'h0000_2004,
             32'h0000_2100, 32'h0000_2200);
    tick();
    check_id("map_i0_miss_flag", "I0 fetch_valid_if=0 still maps payload; flag latched");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "if_id_tb failed");
    $finish;
  end

endmodule
