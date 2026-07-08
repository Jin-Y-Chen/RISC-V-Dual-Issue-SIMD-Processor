`timescale 1ns / 1ps

import rv_dis_pkg::*;

module target_predict (

  // input controls
  input  logic        pc_valid,
  input  logic        brnch_en,

  // input data
  input  word_t       pc,
  input  br_state_t   target_state,
  input  word_t       imm,
  input  word_t       pc_target,

  // output controls
  output logic        set_target,
  output logic        wb_valid

  // output data
  output word_t       pc_predict,
);

endmodule



