`timescale 1ns / 1ps

// Program selector — speculative branch routing: I0 -> pc0_out, I1 -> pc1_out.
// Recovery: mode=0, execute PC bases -> pc.sv sequential +8/+8.
// Stall: predict while is_spec blocks new speculation until execute recovery.
module pc_selector (
  // internal controls
  input  logic          is_spec,
  input  logic          i0_pred_taken,
  input  logic          i1_pred_taken,
  input  logic          i0_brch_recover,
  input  logic          i1_brch_recover,

  // input data
  input  logic [31:0]   pc0_in,
  input  logic [31:0]   pc1_in,
  input  logic [31:0]   i0_pc_target,
  input  logic [31:0]   i1_pc_target,
  input  logic [31:0]   i0_pc_execute,
  input  logic [31:0]   i1_pc_execute,

  // output data
  output logic          stall,
  output logic          mode,
  output logic          spec0_en,
  output logic [31:0]   pc0_out,
  output logic [31:0]   pc1_out
);

  // Keep this module package-independent for easier standalone tool parsing.
  function automatic logic [31:0] imm_align4(input logic [31:0] imm);
    return {imm[31:2], 2'b00};
  endfunction

  logic recover_any;

  assign recover_any   = i0_brch_recover | i1_brch_recover;
  assign stall         = (i0_pred_taken | i1_pred_taken) && is_spec && !recover_any;
  assign spec0_en      = (i0_pred_taken | i1_pred_taken | is_spec) && !recover_any;
  assign mode          = ((i0_pred_taken ^ i1_pred_taken) && !recover_any) ? 1'b1 : 1'b0;

  always_comb begin
    pc0_out = imm_align4(pc0_in);
    pc1_out = imm_align4(pc1_in);

    if (i0_brch_recover) begin
      pc0_out = imm_align4(i0_pc_execute);
      pc1_out = imm_align4(i0_pc_execute) + 32'd4;
    end else if (i1_brch_recover) begin
      pc0_out = imm_align4(i1_pc_execute);
      pc1_out = imm_align4(i1_pc_execute) + 32'd4;
    end else begin
      if (i0_pred_taken && i1_pred_taken) begin
        pc0_out = imm_align4(i0_pc_target);
        pc1_out = imm_align4(i0_pc_target) + 32'd4;
      end else if (i0_pred_taken) begin
        pc0_out = imm_align4(i0_pc_target);
        pc1_out = imm_align4(pc1_in);
      end else if (i1_pred_taken) begin
        pc0_out = imm_align4(i1_pc_target);
        pc1_out = imm_align4(pc0_in);
      end
    end
  end

endmodule
