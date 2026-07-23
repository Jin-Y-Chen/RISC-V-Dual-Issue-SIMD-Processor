`timescale 1ns / 1ps

import rv_dis_pkg::*;
import cache_pkg::*;
import dpi_pkg::*;

// DPI shim — model/s2_decode/state_buffer_gm.cpp
module state_buffer_gm #(
  parameter integer INDEX_W = PC_INDEX_AW,
  parameter integer DATA_W  = 2,
  parameter integer WAYS    = 16,
  parameter [1:0] DEFAULT_STATE = 2'b10
) (
  input  logic        clk,
  input  logic        rst_n,
  input  word_t       i0_pc,
  input  word_t       i1_pc,
  input  logic        i0_brch_en,
  input  logic        i1_brch_en,
  input  logic        i0_valid_wb,
  input  logic        i1_valid_wb,
  input  word_t       i0_brch_pc_wb,
  input  word_t       i1_brch_pc_wb,
  input  br_state_t   i0_brch_state_wb,
  input  br_state_t   i1_brch_state_wb,
  output br_state_t   i0_brch_state,
  output br_state_t   i1_brch_state
);

  chandle h;
  int s0, s1;

  initial begin
    h = sbuf_dpi_create();
    if (h == null) $fatal(1, "sbuf_dpi_create failed");
  end
  final sbuf_dpi_destroy(h);

  always @(*) begin
    sbuf_dpi_eval(h, int'(i0_pc), int'(i1_pc), int'(i0_brch_en), int'(i1_brch_en),
                  int'(i0_valid_wb), int'(i1_valid_wb),
                  int'(i0_brch_pc_wb), int'(i1_brch_pc_wb),
                  int'(i0_brch_state_wb), int'(i1_brch_state_wb), s0, s1);
    i0_brch_state = s0[1:0];
    i1_brch_state = s1[1:0];
  end

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
      sbuf_dpi_reset(h);
    else
      sbuf_dpi_commit(h, int'(i0_valid_wb), int'(i1_valid_wb),
                      int'(i0_brch_pc_wb), int'(i1_brch_pc_wb),
                      int'(i0_brch_state_wb), int'(i1_brch_state_wb));
  end

endmodule
