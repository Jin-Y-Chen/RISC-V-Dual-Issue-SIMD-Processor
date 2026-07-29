`timescale 1ns / 1ps

import rv_dis_pkg::*;
import cache_pkg::*;
import dpi_pkg::*;

// DPI shim - model/s2_decode/state_buffer_gm.cpp ([2] ports match DUT)
module state_buffer_gm #(
  parameter integer INDEX_W = PC_INDEX_AW,
  parameter integer DATA_W  = 2,
  parameter integer WAYS    = 16,
  parameter [1:0] DEFAULT_STATE = 2'b10
) (
  input  logic        clk,
  input  logic        rst_n,
  input  word_t       pc            [2],
  input  logic        brch_en       [2],
  input  logic        valid_wb      [2],
  input  word_t       brch_pc_wb    [2],
  input  br_state_t   brch_state_wb [2],
  output br_state_t   brch_state    [2],
  output logic        state_valid   [2]
);

  chandle h;
  int s0, s1, v0, v1;

  initial begin
    h = sbuf_dpi_create();
    if (h == null) $fatal(1, "sbuf_dpi_create failed");
  end
  final sbuf_dpi_destroy(h);

  always @(*) begin
    sbuf_dpi_eval(h, int'(pc[0]), int'(pc[1]), int'(brch_en[0]), int'(brch_en[1]),
                  int'(valid_wb[0]), int'(valid_wb[1]),
                  int'(brch_pc_wb[0]), int'(brch_pc_wb[1]),
                  int'(brch_state_wb[0]), int'(brch_state_wb[1]),
                  s0, s1, v0, v1);
    brch_state[0]  = s0[1:0];
    brch_state[1]  = s1[1:0];
    state_valid[0] = v0[0];
    state_valid[1] = v1[0];
  end

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
      sbuf_dpi_reset(h);
    else
      sbuf_dpi_commit(h, int'(valid_wb[0]), int'(valid_wb[1]),
                      int'(brch_pc_wb[0]), int'(brch_pc_wb[1]),
                      int'(brch_state_wb[0]), int'(brch_state_wb[1]));
  end

endmodule
