`timescale 1ns / 1ps

// Program selector — dual-issue PC redirect + branch_map generation.
// branch_map = {i1_pred_taken, i0_pred_taken}; cleared on recover.
// Nested-speculation stall is owned by decode target_predict, not here.
import rv_dis_pkg::*;

module pc_selector (
  // internal controls
  input  br_map_t       branch_map_in,
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
  output br_map_t       branch_map_out,
  output logic [31:0]   pc0_out,
  output logic [31:0]   pc1_out
);

  function automatic logic [31:0] imm_align4(input logic [31:0] imm);
    return {imm[31:2], 2'b00};
  endfunction

  wire     recover_any = i0_brch_recover | i1_brch_recover;
  br_map_t pred_map;
  assign pred_map = {i1_pred_taken, i0_pred_taken};

  // Hold speculation until recover; OR in new taken predicts.
  assign branch_map_out = recover_any ? BR_MAP_NONE : (pred_map | branch_map_in);

  always_comb begin
    pc0_out = imm_align4(pc0_in);
    pc1_out = imm_align4(pc1_in);

    if (i0_brch_recover) begin
      pc0_out = imm_align4(i0_pc_execute) + 32'd4;
      pc1_out = imm_align4(i0_pc_execute) + 32'd8;
    end else if (i1_brch_recover) begin
      pc0_out = imm_align4(i1_pc_execute) + 32'd4;
      pc1_out = imm_align4(i1_pc_execute) + 32'd8;
    end else begin
      unique case (pred_map)
        BR_MAP_BOTH: begin
          pc0_out = imm_align4(i0_pc_target);
          pc1_out = imm_align4(i0_pc_target) + 32'd4;
        end
        BR_MAP_I0: begin
          pc0_out = imm_align4(i0_pc_target);
          pc1_out = imm_align4(pc1_in);
        end
        BR_MAP_I1: begin
          pc0_out = imm_align4(i1_pc_target);
          pc1_out = imm_align4(pc0_in);
        end
        default: begin
          // BR_MAP_NONE — sequential pair already assigned
        end
      endcase
    end
  end

endmodule
