`timescale 1ns / 1ps

// Program selector — speculative branch routing: I0 -> spec0_pc, I1 -> norm1_pc (double-branch).
// Recovery: mode=0, norm1_pc = execute PC base -> pc.sv sequential norm+8 / norm+12.
// Stall: i0_pred_taken while mode_in blocks new I0 speculation until execute recovery.
module pc_selector
  import rv_dis_pkg::*;
(
  // internal controls
  input  logic          is_spec,
  input  logic          i0_pred_taken,
  input  logic          i1_pred_taken,
  input  logic          i0_exe_recover,
  input  logic          i1_exe_recover,

  // input data
  input  word_t         pc0_in,
  input  word_t         pc1_in,
  input  word_t         i0_pc_target,
  input  word_t         i1_pc_target,
  input  word_t         i0_pc_execute,
  input  word_t         i1_pc_execute,

  // output data
  output logic          stall,
  output logic          mode,
  output logic          spec0_en,
  output word_t         pc0_out,
  output word_t         pc1_out
);

  logic recover_any;

  assign recover_any   = i0_exe_recover | i1_exe_recover;
  assign stall         = (i0_pred_taken | i1_pred_taken) && is_spec && !recover_any;
  assign spec0_en      = (i0_pred_taken | i1_pred_taken | is_spec) && !recover_any;
  assign mode          = (i0_pred_taken ^ i1_pred_taken && !recover_any) ? 1'b1 : 1'b0;

  always_comb begin
    pc0_out = imm_align4(pc0_in);
    pc1_out = imm_align4(pc1_in);

    if (i0_exe_recover) begin 
      pc0_out = imm_align4(i0_pc_execute);
      pc1_out = imm_align4(i0_pc_execute) + word_t'(32'd4);
    end 
    else if (i1_exe_recover) begin
      pc0_out = imm_align4(i1_pc_execute);
      pc1_out = imm_align4(i1_pc_execute) + word_t'(32'd4);
    end 
    else begin
      if (i0_pred_taken && i1_pred_taken) begin
        pc0_out = imm_align4(i0_pc_target);
        pc1_out = imm_align4(i0_pc_target) + word_t'(32'd4);
      end 
      else if (i0_pred_taken) begin
        pc0_out = imm_align4(i0_pc_target);
        pc1_out = imm_align4(pc1_in);
      end 
      else if (i1_pred_taken) begin
        pc0_out = imm_align4(i1_pc_target);
        pc1_out = imm_align4(pc0_in);
      end
    end
  end
endmodule
