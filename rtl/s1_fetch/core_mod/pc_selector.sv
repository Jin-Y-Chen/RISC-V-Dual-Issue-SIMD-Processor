`timescale 1ns / 1ps

// Program selector — PC bases for pc.sv (advance +4/+4 or +8/+8 decided in pc).
// Outputs pc0_out/pc1_out feed pc.pc*_in; speculation is per-lane (spec0/spec1).
//
// Each lane keeps its own path: I0 predict steers I0; I1 predict steers I1.
// i1_pred: only pc1_out = target (pc0_out stays current; sequential +8 already
// advanced the pair for the next cycle before pc switches to +4).
// Recovery: execute+4/+8 bases; clears next-spec so pc mode=0 (+8/+8).
// Nested-speculation stall is owned by decode target_predict (spec_stall), not here.
module pc_selector (
  // internal controls
  input  logic          spec0_in,
  input  logic          spec1_in,
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

  // output controls
  output logic          spec0_out,
  output logic          spec1_out,

  // PC bases → pc (pc0_in / pc1_in)
  output logic [31:0]   pc0_out,
  output logic [31:0]   pc1_out
);

  function automatic logic [31:0] imm_align4(input logic [31:0] imm);
    return {imm[31:2], 2'b00};
  endfunction

  logic recover_any;

  assign recover_any = i0_brch_recover | i1_brch_recover;
  assign spec0_out   = (i0_pred_taken | spec0_in) && !recover_any;
  assign spec1_out   = (i1_pred_taken | spec1_in) && !recover_any;

  always_comb begin
    pc0_out = imm_align4(pc0_in);
    pc1_out = imm_align4(pc1_in);

    if (i0_brch_recover) begin
      pc0_out = imm_align4(i0_pc_execute) + 32'd4;
      pc1_out = imm_align4(i0_pc_execute) + 32'd8;
    end else if (i1_brch_recover) begin
      pc0_out = imm_align4(i1_pc_execute) + 32'd4;
      pc1_out = imm_align4(i1_pc_execute) + 32'd8;
    end else if (i0_pred_taken && i1_pred_taken) begin
      pc0_out = imm_align4(i0_pc_target);
      pc1_out = imm_align4(i0_pc_target) + 32'd4;
    end else if (i0_pred_taken) begin
      pc0_out = imm_align4(i0_pc_target);
    end else if (i1_pred_taken) begin
      pc1_out = imm_align4(i1_pc_target);
    end
  end

endmodule
