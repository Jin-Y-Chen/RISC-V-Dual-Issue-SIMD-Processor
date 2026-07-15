`timescale 1ns / 1ps

import rv_dis_pkg::*;

// Branch/jump target select + direction predict (project_outline Target_Predict).
// Active when pc_valid && (brnch_en | jump_en) && !spec_stall.
// Nested speculation: already speculative (this lane's br_map bit) and another
// branch/jump => disable predict outputs and assert spec_stall.
module target_predict (
  // input controls
  input  logic        pc_valid,
  input  logic        brnch_en,
  input  logic        jump_en,
  input  br_map_t     br_map,
  input  logic        lane_is_i1,

  // input data
  input  word_t       pc,
  input  br_state_t   target_state,
  input  word_t       imm,
  input  word_t       pc_target,

  // output data
  output word_t       pc_predict,

  // output controls
  output logic        predict_taken,
  output logic        wb_valid,
  output logic        spec_stall
);

  function automatic word_t word_align4(input word_t addr);
    return word_t'({addr[31:2], 2'b00});
  endfunction

  logic  ctl_flow;
  logic  already_spec;
  logic  branch_active;
  word_t decode_target;
  logic  use_decode_target;

  assign ctl_flow      = brnch_en | jump_en;
  assign already_spec  = lane_is_i1 ? br_map[1] : br_map[0];

  // Stall PC when a control-flow insn arrives while this lane is already speculative.
  assign spec_stall = already_spec && pc_valid && ctl_flow;

  assign branch_active     = pc_valid && ctl_flow && !spec_stall;
  assign decode_target     = word_align4(pc + imm);
  assign use_decode_target = decode_target != pc_target;

  assign wb_valid      = branch_active && use_decode_target;
  assign predict_taken = branch_active && (jump_en | target_state[1]);

  always_comb begin
    if (!branch_active)
      pc_predict = pc;
    else if (use_decode_target)
      pc_predict = decode_target;
    else
      pc_predict = pc_target;
  end

endmodule
