`timescale 1ns / 1ps

// Decode struct smoke + nested-speculation stall vs per-lane spec*_en_id.
import rv_dis_pkg::*;

`include "../include/tb_console.svh"

module decode_core_struct_tb;
  logic        clk;
  logic        rst_n;
  logic        i0_valid_id, i1_valid_id;
  logic        spec0_en_id, spec1_en_id;
  instr_t      i0_instr_id, i1_instr_id;
  word_t       i0_pc_id, i1_pc_id, i0_pc_target_id, i1_pc_target_id;
  logic        i0_brch_valid_wb, i1_brch_valid_wb;
  word_t       i0_brch_pc_wb, i1_brch_pc_wb;
  br_state_t   i0_brch_state_wb, i1_brch_state_wb;

  logic        i0_lane_sel, i1_lane_sel;
  opcode_t     i0_opcode, i1_opcode;
  funct3_t     i0_funct3, i1_funct3;
  funct7_t     i0_funct7, i1_funct7;
  gpr_addr_t   i0_rd_addr, i0_rs1_addr, i0_rs2_addr;
  gpr_addr_t   i1_rd_addr, i1_rs1_addr, i1_rs2_addr;
  word_t       i0_imm, i1_imm;
  logic        i0_valid, i0_brch_en, i0_jump_en, i0_rs1_use, i0_rs2_use, i0_reg_write;
  logic        i1_valid, i1_brch_en, i1_jump_en, i1_rs1_use, i1_rs2_use, i1_reg_write;
  br_state_t   i0_brch_state, i1_brch_state;
  word_t       i0_pc_predict, i1_pc_predict;
  logic        i0_pred_taken, i1_pred_taken;
  logic        i0_pred_valid_wb, i1_pred_valid_wb;
  logic        i0_nest_spec_stall, i1_nest_spec_stall;

  int pass_cnt, fail_cnt;

  s2_decode_struct dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  // JAL x0, 0 — always control-flow for nest stall checks
  localparam instr_t JAL0 = 32'h0000006f;

  task automatic expect_stall(
    input string name,
    input logic  exp_i0,
    input logic  exp_i1
  );
    bit pass;
    #1;
    pass = (i0_nest_spec_stall === exp_i0) && (i1_nest_spec_stall === exp_i1);
    tb_report_open(pass, name, $sformatf("spec=%0b%0b", spec1_en_id, spec0_en_id));
    tb_field_bit("i0_nest_spec_stall", i0_nest_spec_stall, exp_i0);
    tb_field_bit("i1_nest_spec_stall", i1_nest_spec_stall, exp_i1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0; fail_cnt = 0;
    rst_n = 0;
    i0_valid_id = 0; i1_valid_id = 0;
    spec0_en_id = 0; spec1_en_id = 0;
    i0_instr_id = '0; i1_instr_id = '0;
    i0_pc_id = '0; i1_pc_id = '0;
    i0_pc_target_id = '0; i1_pc_target_id = '0;
    i0_brch_valid_wb = 0; i1_brch_valid_wb = 0;
    i0_brch_pc_wb = '0; i1_brch_pc_wb = '0;
    i0_brch_state_wb = '0; i1_brch_state_wb = '0;

    tb_banner("decode_core_struct_tb: nest_spec_stall");
    repeat (2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    spec0_en_id = 0; spec1_en_id = 0;
    i0_valid_id = 1; i1_valid_id = 1;
    i0_instr_id = JAL0; i1_instr_id = JAL0;
    i0_pc_id = 32'h100; i1_pc_id = 32'h104;
    @(posedge clk);
    expect_stall("none_no_nest", 1'b0, 1'b0);

    spec0_en_id = 1; spec1_en_id = 0;
    @(posedge clk);
    expect_stall("spec0_nests_i0", 1'b1, 1'b0);

    spec0_en_id = 0; spec1_en_id = 1;
    @(posedge clk);
    expect_stall("spec1_nests_i1", 1'b0, 1'b1);

    spec0_en_id = 1; spec1_en_id = 1;
    @(posedge clk);
    expect_stall("both_nests", 1'b1, 1'b1);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0) $error("decode_core_struct_tb: %0d failure(s)", fail_cnt);
    $finish;
  end
endmodule
