`timescale 1ns / 1ps

import rv_dis_pkg::*;
import imem_hex_loader_pkg::*;

`include "../../common/utils/tb_console.svh"

// fetch_core_struct_tb - integrated fetch; DUT vs gm/fetch_core_struct_gm.sv.
// Nested-speculation freeze uses decode-style spec_stall (no fetch_stall).
module fetch_core_struct_tb;

  localparam int CLK_PERIOD = 10;
  localparam word_t TB_RESET_PC = word_t'(32'h0000_1000);

  logic   clk;
  logic   rst_n;
  logic   enable;
  logic   dispatch_stall;
  logic   spec_stall   [2];
  logic   pred_taken   [2];
  logic   brch_recover [2];
  logic   valid_wb     [2];
  word_t  pc_execute   [2];
  word_t  pc_wb        [2];
  word_t  pc_target_wb [2];
  word_t  pc_if        [2];
  word_t  pc_target    [2];
  instr_t instr        [2];
  logic   spec_en      [2];
  logic   valid        [2];
  logic   target_valid [2];

  word_t  ref_pc_if        [2];
  word_t  ref_pc_target    [2];
  instr_t ref_instr        [2];
  logic   ref_spec_en      [2];
  logic   ref_valid        [2];
  logic   ref_target_valid [2];

  imem_prog_entry_t prog [256];
  int               prog_len;
  string            mem_file;

  int pass_cnt;
  int fail_cnt;

  s1_fetch_struct #(
    .RESET_PC(TB_RESET_PC)
  ) dut (
    .clk, .rst_n, .enable, .dispatch_stall,
    .spec_stall, .pred_taken, .brch_recover, .valid_wb,
    .pc_execute, .pc_wb, .pc_target_wb,
    .pc_if, .pc_target, .instr, .spec_en, .valid, .target_valid
  );

  fetch_core_struct_gm #(
    .RESET_PC(TB_RESET_PC)
  ) u_fetch_gm (
    .clk, .rst_n, .enable, .dispatch_stall,
    .spec_stall, .pred_taken, .brch_recover, .valid_wb,
    .pc_execute, .pc_wb, .pc_target_wb,
    .pc_if(ref_pc_if), .pc_target(ref_pc_target), .instr(ref_instr),
    .spec_en(ref_spec_en), .valid(ref_valid), .target_valid(ref_target_valid)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk;

  // Preload the DUT's current cache storage from the architectural program
  // image. The GM remains PC-keyed and independent of this bank geometry.
  task automatic preload_icache;
    int set_idx;
    int way_idx;
    for (int i = 0; i < prog_len; i++) begin
      way_idx = int'(prog[i].pc[2]);
      set_idx = int'(prog[i].pc[14:3]);
      dut.u_icache.bank[set_idx][way_idx] = {1'b1, prog[i].word};
    end
  endtask

  task automatic idle_ctrl;
    enable         = 1'b1;
    dispatch_stall = 1'b0;
    for (int i = 0; i < N_DUAL; i++) begin
      spec_stall[i]   = 1'b0;
      pred_taken[i]   = 1'b0;
      brch_recover[i] = 1'b0;
      valid_wb[i]     = 1'b0;
      pc_execute[i]   = '0;
      pc_wb[i]        = '0;
      pc_target_wb[i] = '0;
    end
  endtask

  task automatic step_and_check(input string name, input string detail);
    bit pass;

    @(negedge clk);
    #0;
    @(posedge clk);
    #0;

    pass = (pc_if[0] === ref_pc_if[0]) && (pc_if[1] === ref_pc_if[1])
        && (pc_target[0] === ref_pc_target[0]) && (pc_target[1] === ref_pc_target[1])
        && (instr[0] === ref_instr[0]) && (instr[1] === ref_instr[1])
        && (spec_en[0] === ref_spec_en[0]) && (spec_en[1] === ref_spec_en[1])
        && (valid[0] === ref_valid[0]) && (valid[1] === ref_valid[1])
        && (target_valid[0] === ref_target_valid[0])
        && (target_valid[1] === ref_target_valid[1]);

    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_bit("clk",             clk);
    tb_field_in_bit("rst_n",           rst_n);
    tb_field_in_bit("enable",          enable);
    tb_field_in_bit("dispatch_stall",  dispatch_stall);
    tb_field_in_bit("spec_stall[0]",   spec_stall[0]);
    tb_field_in_bit("spec_stall[1]",   spec_stall[1]);
    tb_field_in_bit("pred_taken[0]",   pred_taken[0]);
    tb_field_in_bit("pred_taken[1]",   pred_taken[1]);
    tb_field_in_bit("brch_recover[0]", brch_recover[0]);
    tb_field_in_bit("brch_recover[1]", brch_recover[1]);
    tb_field_in_u32("pc_execute[0]",   pc_execute[0]);
    tb_field_in_u32("pc_execute[1]",   pc_execute[1]);
    tb_field_in_bit("valid_wb[0]",     valid_wb[0]);
    tb_field_in_bit("valid_wb[1]",     valid_wb[1]);
    tb_field_in_u32("pc_wb[0]",        pc_wb[0]);
    tb_field_in_u32("pc_wb[1]",        pc_wb[1]);
    tb_field_in_u32("pc_target_wb[0]", pc_target_wb[0]);
    tb_field_in_u32("pc_target_wb[1]", pc_target_wb[1]);
    $display("");
    tb_log_section("check");
    tb_field_u32("pc_if[0]",          pc_if[0],          ref_pc_if[0]);
    tb_field_u32("pc_if[1]",          pc_if[1],          ref_pc_if[1]);
    tb_field_u32("pc_target[0]",      pc_target[0],      ref_pc_target[0]);
    tb_field_u32("pc_target[1]",      pc_target[1],      ref_pc_target[1]);
    tb_field_u32("instr[0]",          instr[0],          ref_instr[0]);
    tb_field_u32("instr[1]",          instr[1],          ref_instr[1]);
    tb_field_bit("spec_en[0]",        spec_en[0],        ref_spec_en[0]);
    tb_field_bit("spec_en[1]",        spec_en[1],        ref_spec_en[1]);
    tb_field_bit("valid[0]",          valid[0],          ref_valid[0]);
    tb_field_bit("valid[1]",          valid[1],          ref_valid[1]);
    tb_field_bit("target_valid[0]",   target_valid[0],   ref_target_valid[0]);
    tb_field_bit("target_valid[1]",   target_valid[1],   ref_target_valid[1]);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    rst_n    = 1'b0;
    idle_ctrl();
    if (!$value$plusargs("imem_mem=%s", mem_file))
      mem_file = "program/bin/demo_instructions.mem";
    imem_load_mem_program(mem_file, prog, prog_len);

    tb_banner("fetch_core_struct_tb: DUT vs fetch_core_struct_gm.sv");

    step_and_check("reset", "RESET_PC pair, spec=00");

    @(negedge clk);
    rst_n = 1'b1;
    preload_icache();
    idle_ctrl();
    step_and_check("sequential_step", "spec=00 => +8/+8");

    @(negedge clk);
    idle_ctrl();
    dispatch_stall  = 1'b1;
    pc_wb[0]        = pc_if[0];
    pc_target_wb[0] = word_t'(32'h0000_2000);
    valid_wb[0]     = 1'b1;
    step_and_check("btb_wb_hold", "dispatch_stall holds PC during BTB write");

    @(negedge clk);
    idle_ctrl();
    pred_taken[0]   = 1'b1;
    pc_target_wb[0] = word_t'(32'h0000_2000); // decode pc_predict
    step_and_check("i0_predict", "spec sticky both, I0 target into next-PC bases");

    @(negedge clk);
    idle_ctrl();
    step_and_check("post_predict_step", "sticky spec => +4/+4 split");

    // Decode-style nested-speculation stall freezes PC
    @(negedge clk);
    idle_ctrl();
    spec_stall[0] = 1'b1;
    step_and_check("spec_stall_hold", "spec_stall[0] freezes PC");

    @(negedge clk);
    idle_ctrl();
    brch_recover[0] = 1'b1;
    pc_execute[0]   = word_t'(32'h0000_3000);
    step_and_check("i0_recover", "recover clears spec, execute+4/+8");

    @(negedge clk);
    idle_ctrl();
    dispatch_stall = 1'b1;
    step_and_check("dispatch_stall_hold", "dispatch_stall blocks PC update");

    @(negedge clk);
    idle_ctrl();
    step_and_check("sequential_resume", "spec=00 => +8/+8");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $error("fetch_core_struct_tb: %0d failure(s)", fail_cnt);
    $finish;
  end

endmodule
