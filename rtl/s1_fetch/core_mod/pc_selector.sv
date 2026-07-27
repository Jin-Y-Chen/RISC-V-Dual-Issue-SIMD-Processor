`timescale 1ns / 1ps

import rv_dis_pkg::*;

// Program selector — PC bases for pc.sv (advance +4/+4 or +8/+8 decided in pc).
// Outputs pc_out feed pc.pc_in; speculation is per-lane (spec_in/spec_out).
//
// Each lane keeps its own path: I0 predict steers I0; I1 predict steers I1.
// Lane-1 predict: only pc_out[1] = target (pc_out[0] stays current; sequential +8
// already advanced the pair for the next cycle before pc switches to +4).
// Recovery: execute+4/+8 bases; clears next-spec so pc mode=0 (+8/+8).
// Nested-speculation stall is owned by decode target_predict (spec_stall), not here.
module pc_selector (
  // internal controls
  input  logic          spec_in      [2],
  input  logic          pred_taken   [2],
  input  logic          brch_recover [2],

  // input data
  input  word_t         pc_in        [2],
  input  word_t         pc_target    [2],
  input  word_t         pc_execute   [2],

  // output controls
  output logic          spec_out     [2],

  // PC bases → pc (pc_in)
  output word_t         pc_out       [2]
);

  logic recover_any;

  assign recover_any = brch_recover[0] | brch_recover[1];

  always_comb begin
    for (int i = 0; i < N_DUAL; i++)
      spec_out[i] = (pred_taken[i] | spec_in[i]) && !recover_any;
  end

  always_comb begin
    pc_out[0] = imm_align4(pc_in[0]);
    pc_out[1] = imm_align4(pc_in[1]);

    if (brch_recover[0]) begin
      pc_out[0] = imm_align4(pc_execute[0]) + 32'd4;
      pc_out[1] = imm_align4(pc_execute[0]) + 32'd8;
    end else if (brch_recover[1]) begin
      pc_out[0] = imm_align4(pc_execute[1]) + 32'd4;
      pc_out[1] = imm_align4(pc_execute[1]) + 32'd8;
    end else if (pred_taken[0] && pred_taken[1]) begin
      pc_out[0] = imm_align4(pc_target[0]);
      pc_out[1] = imm_align4(pc_target[0]) + 32'd4;
    end else if (pred_taken[0]) begin
      pc_out[0] = imm_align4(pc_target[0]);
    end else if (pred_taken[1]) begin
      pc_out[1] = imm_align4(pc_target[1]);
    end
  end

endmodule
