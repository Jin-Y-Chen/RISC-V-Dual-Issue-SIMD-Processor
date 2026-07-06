`timescale 1ns / 1ps

import rv_dis_pkg::*;

module target_predict (
  input  word_t         pc,
  input  logic        brch_en,
  input  br_state_t   target_state,
  input  word_t        imm,
  input  logic        pc_valid,
  input  word_t         pc_target,

  output word_t         pc_predict,
  output logic        set_target,
  output logic        wb_valid
);

endmodule
