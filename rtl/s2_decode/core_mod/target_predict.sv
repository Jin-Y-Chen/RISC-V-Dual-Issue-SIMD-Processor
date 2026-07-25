`timescale 1ns / 1ps

import rv_dis_pkg::*;

// Branch/jump target select + direction predict (project_outline Target_Predict).
// Decoder guarantee: jump_en=1 => brnch_en=1, so control-flow is just brnch_en.
// Active when brnch_en && !spec_n.
// BTB train (pred_valid_wb): !target_valid or decode target != latched BTB entry.
module target_predict (
  // input controls
  input  logic        target_valid,
  input  logic        brnch_en,
  input  logic        jump_en,
  input  logic        spec_n,

  // input data
  input  word_t       pc,
  input  br_state_t   target_state,
  input  word_t       imm,
  input  word_t       pc_target,

  // output data
  output word_t       pc_predict,

  // output controls
  output logic        pred_taken,
  output logic        pred_valid_wb,
  output logic        nest_spec_stall
);

  word_t decode_target;
  word_t pc_plus_imm;

  assign pc_plus_imm     = pc + imm;
  assign decode_target   = imm_align4(pc_plus_imm);
  assign nest_spec_stall = spec_n && brnch_en;
  assign pred_taken      = brnch_en && !spec_n && (jump_en | target_state[1]);
  assign pred_valid_wb   = brnch_en && !spec_n
                        && (!target_valid || (decode_target != pc_target));

  always_comb begin
    if (!(brnch_en && !spec_n))
      pc_predict = pc;
    else if (!target_valid || (decode_target != pc_target))
      pc_predict = decode_target;
    else
      pc_predict = pc_target;
  end

endmodule
