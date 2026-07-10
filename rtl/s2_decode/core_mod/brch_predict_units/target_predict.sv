`timescale 1ns / 1ps

import rv_dis_pkg::*;

// Branch/jump target select + direction predict (project_outline Target_Predict).
// Active when pc_valid && (brnch_en | jump_en).
module target_predict (
  // input controls
  input  logic        pc_valid,
  input  logic        brnch_en,
  input  logic        jump_en,

  // input data
  input  word_t       pc,
  input  br_state_t   target_state,
  input  word_t       imm,
  input  word_t       pc_target,

  // output controls
  output logic        set_target,
  output logic        wb_valid,

  // output data
  output word_t       pc_predict
);

  function automatic word_t word_align4(input word_t addr);
    return word_t'({addr[31:2], 2'b00});
  endfunction

  logic  branch_active;
  word_t decode_target;
  logic  use_decode_target;

  assign branch_active     = pc_valid && (brnch_en | jump_en);
  assign decode_target     = word_align4(pc + imm);
  assign use_decode_target = decode_target != pc_target;

  // BTB train when decode target differs from the latched BTB entry.
  assign wb_valid   = branch_active && use_decode_target;

  // JAL/JALR always taken; conditional branches follow state[1].
  assign set_target = branch_active && (jump_en | target_state[1]);

  always_comb begin
    if (!branch_active)
      pc_predict = pc;
    else if (use_decode_target)
      pc_predict = decode_target;
    else
      pc_predict = pc_target;
  end

endmodule
