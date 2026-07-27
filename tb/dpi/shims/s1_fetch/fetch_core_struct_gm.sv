`timescale 1ns / 1ps

import rv_dis_pkg::*;
import dpi_pkg::*;

// DPI shim — golden logic in model/s1_fetch/fetch_core_struct_gm.cpp
// Port API matches s1_fetch_struct ([2] arrays); DPI stays scalar dual-slot.
module fetch_core_struct_gm #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  input  logic  clk,
  input  logic  rst_n,
  input  logic  enable,
  input  logic  dispatch_stall,
  input  logic  spec_stall   [2],
  input  logic  pred_taken   [2],
  input  logic  brch_recover [2],
  input  logic  valid_wb     [2],
  input  word_t pc_execute   [2],
  input  word_t pc_wb        [2],
  input  word_t pc_target_wb [2],
  output word_t pc_if        [2],
  output word_t pc_target    [2],
  output instr_t instr       [2],
  output logic  spec_en      [2],
  output logic  valid        [2],
  output logic  target_valid [2]
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
      int'(spec_stall[0]), int'(spec_stall[1]),
      int'(pred_taken[0]), int'(pred_taken[1]),
      int'(brch_recover[0]), int'(brch_recover[1]),
      int'(pc_execute[0]), int'(pc_execute[1]),
      int'(valid_wb[0]), int'(valid_wb[1]),
      int'(pc_wb[0]), int'(pc_wb[1]), int'(pc_target_wb[0]), int'(pc_target_wb[1]),
      p0, p1, t0, t1, in0, in1, s0, s1, v0, v1, tv0, tv1);
    pc_if[0] = p0[31:0]; pc_if[1] = p1[31:0];
    pc_target[0] = t0[31:0]; pc_target[1] = t1[31:0];
    instr[0] = in0[31:0]; instr[1] = in1[31:0];
    spec_en[0] = s0[0]; spec_en[1] = s1[0];
    valid[0] = v0[0]; valid[1] = v1[0];
    target_valid[0] = tv0[0]; target_valid[1] = tv1[0];
  end

  always @(posedge clk) begin
    if (!rst_n)
      fetch_dpi_reset(h);
    else
      fetch_dpi_commit_posedge(
        h, int'(rst_n), int'(enable), int'(dispatch_stall),
        int'(spec_stall[0]), int'(spec_stall[1]),
        int'(pred_taken[0]), int'(pred_taken[1]),
        int'(brch_recover[0]), int'(brch_recover[1]),
        int'(pc_execute[0]), int'(pc_execute[1]),
        int'(valid_wb[0]), int'(valid_wb[1]),
        int'(pc_wb[0]), int'(pc_wb[1]), int'(pc_target_wb[0]), int'(pc_target_wb[1]));
  end

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
      ;
    else
      fetch_dpi_commit_negedge(
        h, int'(valid_wb[0]), int'(valid_wb[1]),
        int'(pc_wb[0]), int'(pc_wb[1]), int'(pc_target_wb[0]), int'(pc_target_wb[1]));
  end

endmodule
