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
  input  logic        fetch_valid_if  [2],
  input  logic        target_valid_if [2],
  input  logic        spec_en_if      [2],
  input  instr_t      instr_if        [2],
  input  word_t       pc_if           [2],
  input  word_t       pc_target_if    [2],
  output instr_t      instr_id         [2],
  output word_t       pc_id            [2],
  output word_t       pc_target_id     [2],
  output logic        fetch_valid_id   [2],
  output logic        target_valid_id  [2],
  output logic        spec_en_id       [2]
);

  chandle h;
  int in0, in1, p0, p1, t0, t1, fv0, fv1, tv0, tv1, s0, s1;

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
                      int'(fetch_valid_if[0]), int'(fetch_valid_if[1]),
                      int'(target_valid_if[0]), int'(target_valid_if[1]),
                      int'(spec_en_if[0]), int'(spec_en_if[1]),
                      int'(instr_if[0]), int'(instr_if[1]),
                      int'(pc_if[0]), int'(pc_if[1]),
                      int'(pc_target_if[0]), int'(pc_target_if[1]));
    ifid_dpi_eval(h, in0, in1, p0, p1, t0, t1, fv0, fv1, tv0, tv1, s0, s1);
    instr_id[0]        <= in0[31:0];
    instr_id[1]        <= in1[31:0];
    pc_id[0]           <= p0[31:0];
    pc_id[1]           <= p1[31:0];
    pc_target_id[0]    <= t0[31:0];
    pc_target_id[1]    <= t1[31:0];
    fetch_valid_id[0]  <= fv0[0];
    fetch_valid_id[1]  <= fv1[0];
    target_valid_id[0] <= tv0[0];
    target_valid_id[1] <= tv1[0];
    spec_en_id[0]      <= s0[0];
    spec_en_id[1]      <= s1[0];
  end

endmodule
