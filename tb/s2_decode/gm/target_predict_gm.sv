`timescale 1ns / 1ps

// Executable branch/jump target-prediction specification for target_predict.sv.
//
// Independent of the RTL netlist: one decision function answers
// "given fetch BTB state, decoder control, and speculation status, what should
// the lane predict / train / stall?"  Uses only architectural types/helpers
// from rv_dis_pkg (no decode_pkg, no RTL instantiation).
import rv_dis_pkg::*;

module target_predict_gm (
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

  typedef struct packed {
    word_t pc_predict;
    logic  pred_taken;
    logic  pred_valid_wb;
    logic  nest_spec_stall;
  } predict_result_t;

  // Architectural next PC for a PC-relative branch/jump: word-align(pc + imm).
  function automatic word_t gm_decode_target(input word_t pc_i, input word_t imm_i);
    return imm_align4(pc_i + imm_i);
  endfunction

  // Direction bit of the 2-bit saturating predictor: 1 => predict taken.
  function automatic logic gm_state_taken(input br_state_t state);
    return state[1];
  endfunction

  // Full per-lane prediction decision (combinational scoreboard reference).
  function automatic predict_result_t gm_predict(
    input logic      target_valid_i,
    input logic      brnch_en_i,
    input logic      jump_en_i,
    input logic      spec_n_i,
    input word_t     pc_i,
    input br_state_t target_state_i,
    input word_t     imm_i,
    input word_t     pc_target_i
  );
    predict_result_t result;
    word_t           decode_target;
    logic            control_flow;
    logic            nested;
    logic            active;
    logic            btb_miss;
    logic            btb_stale;

    decode_target = gm_decode_target(pc_i, imm_i);
    // Decoder contract: jump_en implies brnch_en; control-flow is brnch_en.
    control_flow = brnch_en_i;
    nested = spec_n_i && control_flow;
    active = control_flow && !nested;
    btb_miss = !target_valid_i;
    btb_stale = target_valid_i && (decode_target != pc_target_i);

    // Quiet / freeze defaults.
    result.pc_predict = pc_i;
    result.pred_taken = 1'b0;
    result.pred_valid_wb = 1'b0;
    result.nest_spec_stall = nested;

    if (active) begin
      // Direction: unconditional jumps always taken; branches use state MSB.
      result.pred_taken = jump_en_i || gm_state_taken(target_state_i);

      // Address: train and use decode target on miss/stale; else trust BTB.
      if (btb_miss || btb_stale) begin
        result.pc_predict = decode_target;
        result.pred_valid_wb = 1'b1;
      end else begin
        result.pc_predict = pc_target_i;
        result.pred_valid_wb = 1'b0;
      end
    end

    return result;
  endfunction

  predict_result_t expected;
  assign expected = gm_predict(
    target_valid, brnch_en, jump_en, spec_n,
    pc, target_state, imm, pc_target
  );

  assign pc_predict      = expected.pc_predict;
  assign pred_taken      = expected.pred_taken;
  assign pred_valid_wb   = expected.pred_valid_wb;
  assign nest_spec_stall = expected.nest_spec_stall;

endmodule
