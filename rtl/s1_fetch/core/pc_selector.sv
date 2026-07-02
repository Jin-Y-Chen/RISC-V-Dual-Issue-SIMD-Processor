`timescale 1ns / 1ps

typedef rv_dis_pkg::word_t word_t;

// Program selector — speculative branch routing for I0 only (spec_out); I1 uses norm_out.
// I1 branches are not handled here (dispatch stall / dependent case).
module pc_selector (
  input  logic enable,
  input  logic in_spec,

  input  word_t pc0,
  input  word_t pc1,

  input  word_t i0_pc_predict,
  input  logic i0_pred_taken,

  input  logic recover_en,
  input  logic recover_correct,
  input  logic recover_i0,
  input  word_t recover_pc,
  input  logic recover_use_exec_pc,

  output logic spec,
  output word_t spec_out,
  output word_t norm_out,
  output logic flush
);

  word_t pc0_aligned;
  word_t pc1_aligned;
  word_t recover_pc_aligned;
  word_t recover_fallback;
  word_t fall_next_pc1;

  logic predict_i0;

  assign pc0_aligned        = {pc0[31:2], 2'b00};
  assign pc1_aligned        = {pc1[31:2], 2'b00};
  assign recover_pc_aligned = {recover_pc[31:2], 2'b00};
  assign fall_next_pc1      = pc1_aligned + word_t'(32'd4);

  assign predict_i0 = enable && i0_pred_taken && !in_spec;

  always_comb begin
    recover_fallback = pc0_aligned + word_t'(32'd8);
    if (recover_i0)
      recover_fallback = fall_next_pc1;
  end

  always_comb begin
    spec = in_spec;
    if (recover_en && recover_i0)
      spec = 1'b0;
    else if (predict_i0)
      spec = 1'b1;
  end

  always_comb begin
    spec_out = pc0_aligned;
    norm_out = in_spec ? pc1_aligned : pc0_aligned;
    flush    = recover_en && recover_i0;

    if (predict_i0) begin
      spec_out = {i0_pc_predict[31:2], 2'b00} - word_t'(32'd4);
      norm_out = pc1_aligned;
    end

    if (recover_en && recover_i0) begin
      if (recover_correct) begin
        spec_out = pc0_aligned - word_t'(32'd4);
        norm_out = pc0_aligned;
      end else begin
        spec_out = (recover_use_exec_pc ? recover_pc_aligned : recover_fallback)
                 - word_t'(32'd4);
        norm_out = recover_use_exec_pc ? recover_pc_aligned : recover_fallback;
      end
    end
  end

endmodule
