`timescale 1ns / 1ps

import rv_dis_pkg::*;
import dpi_pkg::*;

// DPI shim — model/s2_decode/target_predict_gm.cpp
module target_predict_gm (
  input  logic        target_valid,
  input  logic        brnch_en,
  input  logic        jump_en,
  input  logic        spec_n,
  input  word_t       pc,
  input  br_state_t   target_state,
  input  word_t       imm,
  input  word_t       pc_target,
  output word_t       pc_predict,
  output logic        pred_taken,
  output logic        pred_valid_wb,
  output logic        nest_spec_stall
);

  int pp, pt, pv, ns;

  always @(*) begin
    tpred_dpi_eval(int'(target_valid), int'(brnch_en), int'(jump_en), int'(spec_n),
                   int'(pc), int'(target_state), int'(imm), int'(pc_target),
                   pp, pt, pv, ns);
    pc_predict      = pp[31:0];
    pred_taken      = pt[0];
    pred_valid_wb   = pv[0];
    nest_spec_stall = ns[0];
  end

endmodule
