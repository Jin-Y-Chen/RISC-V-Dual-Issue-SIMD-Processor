`timescale 1ns / 1ps

import rv_dis_pkg::*;
import dpi_pkg::*;

// DPI shim — model/s2_decode/if_id_gm.cpp
module if_id_gm (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall,
  input  logic        i0_fetch_valid,
  input  logic        i1_fetch_valid,
  input  logic        i0_target_valid_if,
  input  logic        i1_target_valid_if,
  input  logic        spec0_en_if,
  input  logic        spec1_en_if,
  input  instr_t      i0_instr_if,
  input  instr_t      i1_instr_if,
  input  word_t       i0_pc_if,
  input  word_t       i1_pc_if,
  input  word_t       i0_pc_target_if,
  input  word_t       i1_pc_target_if,
  output instr_t      i0_instr_id,
  output instr_t      i1_instr_id,
  output word_t       i0_pc_id,
  output word_t       i1_pc_id,
  output word_t       i0_pc_target_id,
  output word_t       i1_pc_target_id,
  output logic        i0_target_valid_id,
  output logic        i1_target_valid_id,
  output logic        spec0_en_id,
  output logic        spec1_en_id
);

  chandle h;
  int in0, in1, p0, p1, t0, t1, tv0, tv1, s0, s1;

  initial begin
    h = ifid_dpi_create();
    if (h == null) $fatal(1, "ifid_dpi_create failed");
  end
  final ifid_dpi_destroy(h);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      ifid_dpi_reset(h);
    else
      ifid_dpi_commit(h, int'(rst_n), int'(enable), int'(flush), int'(stall),
                      int'(i0_fetch_valid), int'(i1_fetch_valid),
                      int'(i0_target_valid_if), int'(i1_target_valid_if),
                      int'(spec0_en_if), int'(spec1_en_if),
                      int'(i0_instr_if), int'(i1_instr_if),
                      int'(i0_pc_if), int'(i1_pc_if),
                      int'(i0_pc_target_if), int'(i1_pc_target_if));
    ifid_dpi_eval(h, in0, in1, p0, p1, t0, t1, tv0, tv1, s0, s1);
    i0_instr_id        <= in0[31:0];
    i1_instr_id        <= in1[31:0];
    i0_pc_id           <= p0[31:0];
    i1_pc_id           <= p1[31:0];
    i0_pc_target_id    <= t0[31:0];
    i1_pc_target_id    <= t1[31:0];
    i0_target_valid_id <= tv0[0];
    i1_target_valid_id <= tv1[0];
    spec0_en_id        <= s0[0];
    spec1_en_id        <= s1[0];
  end

endmodule
