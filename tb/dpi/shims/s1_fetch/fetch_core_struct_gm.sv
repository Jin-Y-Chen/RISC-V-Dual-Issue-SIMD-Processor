`timescale 1ns / 1ps

import rv_dis_pkg::*;
import dpi_pkg::*;

// DPI shim — golden logic in model/s1_fetch/fetch_core_struct_gm.cpp
module fetch_core_struct_gm #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  input  logic  clk,
  input  logic  rst_n,
  input  logic  enable,
  input  logic  dispatch_stall,
  input  logic  spec0_stall,
  input  logic  spec1_stall,
  input  logic  i0_pred_taken,
  input  logic  i1_pred_taken,
  input  logic  i0_brch_recover,
  input  logic  i1_brch_recover,
  input  word_t i0_pc_execute,
  input  word_t i1_pc_execute,
  input  logic  i0_valid_wb,
  input  logic  i1_valid_wb,
  input  word_t i0_pc_wb,
  input  word_t i1_pc_wb,
  input  word_t i0_pc_target_wb,
  input  word_t i1_pc_target_wb,
  output word_t pc0,
  output word_t pc1,
  output word_t i0_pc_target,
  output word_t i1_pc_target,
  output instr_t instr0,
  output instr_t instr1,
  output logic  spec0_en,
  output logic  spec1_en,
  output logic  i0_valid,
  output logic  i1_valid,
  output logic  i0_target_valid,
  output logic  i1_target_valid
);

  chandle h;
  int p0, p1, t0, t1, in0, in1, s0, s1, v0, v1, tv0, tv1;

  initial begin
    h = fetch_dpi_create(int'(RESET_PC));
    if (h == null) $fatal(1, "fetch_dpi_create failed");
  end
  final fetch_dpi_destroy(h);

  always @(*) begin
    fetch_dpi_eval(
      h, int'(rst_n), int'(enable), int'(dispatch_stall),
      int'(spec0_stall), int'(spec1_stall),
      int'(i0_pred_taken), int'(i1_pred_taken),
      int'(i0_brch_recover), int'(i1_brch_recover),
      int'(i0_pc_execute), int'(i1_pc_execute),
      int'(i0_valid_wb), int'(i1_valid_wb),
      int'(i0_pc_wb), int'(i1_pc_wb), int'(i0_pc_target_wb), int'(i1_pc_target_wb),
      p0, p1, t0, t1, in0, in1, s0, s1, v0, v1, tv0, tv1);
    pc0 = p0[31:0]; pc1 = p1[31:0];
    i0_pc_target = t0[31:0]; i1_pc_target = t1[31:0];
    instr0 = in0[31:0]; instr1 = in1[31:0];
    spec0_en = s0[0]; spec1_en = s1[0];
    i0_valid = v0[0]; i1_valid = v1[0];
    i0_target_valid = tv0[0]; i1_target_valid = tv1[0];
  end

  always @(posedge clk) begin
    if (!rst_n)
      fetch_dpi_reset(h);
    else
      fetch_dpi_commit_posedge(
        h, int'(rst_n), int'(enable), int'(dispatch_stall),
        int'(spec0_stall), int'(spec1_stall),
        int'(i0_pred_taken), int'(i1_pred_taken),
        int'(i0_brch_recover), int'(i1_brch_recover),
        int'(i0_pc_execute), int'(i1_pc_execute),
        int'(i0_valid_wb), int'(i1_valid_wb),
        int'(i0_pc_wb), int'(i1_pc_wb), int'(i0_pc_target_wb), int'(i1_pc_target_wb));
  end

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
      ;
    else
      fetch_dpi_commit_negedge(
        h, int'(i0_valid_wb), int'(i1_valid_wb),
        int'(i0_pc_wb), int'(i1_pc_wb), int'(i0_pc_target_wb), int'(i1_pc_target_wb));
  end

endmodule
