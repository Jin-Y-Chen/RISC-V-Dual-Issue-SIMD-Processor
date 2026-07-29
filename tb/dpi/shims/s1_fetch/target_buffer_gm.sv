`timescale 1ns / 1ps

import rv_dis_pkg::*;
import dpi_pkg::*;

// DPI shim - golden logic in model/s1_fetch/target_buffer_gm.cpp
module target_buffer_gm #(
  parameter integer INDEX_W = 13,
  parameter integer DATA_W  = 32,
  parameter integer WAYS    = 16,
  parameter integer CAP     = 64
) (
  input  logic  clk,
  input  logic  rst_n,
  input  word_t i0_pc,
  input  word_t i1_pc,
  input  logic  i0_valid_wb,
  input  logic  i1_valid_wb,
  input  word_t i0_pc_wb,
  input  word_t i1_pc_wb,
  input  word_t i0_pc_target_wb,
  input  word_t i1_pc_target_wb,
  output logic  i0_valid,
  output logic  i1_valid,
  output word_t i0_pc_target,
  output word_t i1_pc_target
);

  chandle h;
  int v0, v1, t0, t1;

  initial begin
    h = btb_dpi_create();
    if (h == null) $fatal(1, "btb_dpi_create failed");
  end
  final btb_dpi_destroy(h);

  always @(*) begin
    btb_dpi_eval(h, int'(i0_pc), int'(i1_pc), int'(i0_valid_wb), int'(i1_valid_wb),
                 int'(i0_pc_wb), int'(i1_pc_wb), int'(i0_pc_target_wb), int'(i1_pc_target_wb),
                 v0, v1, t0, t1);
    i0_valid     = v0[0];
    i1_valid     = v1[0];
    i0_pc_target = t0[31:0];
    i1_pc_target = t1[31:0];
  end

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
      btb_dpi_reset(h);
    else
      btb_dpi_commit(h, int'(i0_valid_wb), int'(i1_valid_wb),
                     int'(i0_pc_wb), int'(i1_pc_wb),
                     int'(i0_pc_target_wb), int'(i1_pc_target_wb));
  end

endmodule
