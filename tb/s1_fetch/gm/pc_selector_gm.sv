`timescale 1ns / 1ps

// Golden model for rtl/s1_fetch/core_mod/pc_selector.sv
// ctrl[4:0] = {is_spec, i0_pred_taken, i1_pred_taken, i0_brch_recover, i1_brch_recover}
// CTRL_LUT lists stall/mode/spec0_en for all 32 control vectors explicitly.
// PC outputs use the same priority mux as the DUT (data-dependent).

module pc_selector_gm (
  input  logic        is_spec,
  input  logic        i0_pred_taken,
  input  logic        i1_pred_taken,
  input  logic        i0_brch_recover,
  input  logic        i1_brch_recover,
  input  logic [31:0] pc0_in,
  input  logic [31:0] pc1_in,
  input  logic [31:0] i0_pc_target,
  input  logic [31:0] i1_pc_target,
  input  logic [31:0] i0_pc_execute,
  input  logic [31:0] i1_pc_execute,
  output logic        stall,
  output logic        mode,
  output logic        spec0_en,
  output logic [31:0] pc0_out,
  output logic [31:0] pc1_out
);

  typedef struct packed {
    logic stall;
    logic mode;
    logic spec0_en;
  } gm_ctrl_lut_row_t;

  logic [4:0] ctrl;

  // 32-entry control LUT — one row per ctrl[4:0]
  localparam gm_ctrl_lut_row_t CTRL_LUT [0:31] = '{
    '{1'b0, 1'b0, 1'b0}, // 5'h00 {0,0,0,0,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h01 {0,0,0,0,1}
    '{1'b0, 1'b0, 1'b0}, // 5'h02 {0,0,0,1,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h03 {0,0,0,1,1}
    '{1'b0, 1'b1, 1'b1}, // 5'h04 {0,0,1,0,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h05 {0,0,1,0,1}
    '{1'b0, 1'b0, 1'b0}, // 5'h06 {0,0,1,1,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h07 {0,0,1,1,1}
    '{1'b0, 1'b1, 1'b1}, // 5'h08 {0,1,0,0,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h09 {0,1,0,0,1}
    '{1'b0, 1'b0, 1'b0}, // 5'h0a {0,1,0,1,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h0b {0,1,0,1,1}
    '{1'b0, 1'b0, 1'b1}, // 5'h0c {0,1,1,0,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h0d {0,1,1,0,1}
    '{1'b0, 1'b0, 1'b0}, // 5'h0e {0,1,1,1,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h0f {0,1,1,1,1}
    '{1'b0, 1'b0, 1'b1}, // 5'h10 {1,0,0,0,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h11 {1,0,0,0,1}
    '{1'b0, 1'b0, 1'b0}, // 5'h12 {1,0,0,1,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h13 {1,0,0,1,1}
    '{1'b1, 1'b1, 1'b1}, // 5'h14 {1,0,1,0,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h15 {1,0,1,0,1}
    '{1'b0, 1'b0, 1'b0}, // 5'h16 {1,0,1,1,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h17 {1,0,1,1,1}
    '{1'b1, 1'b1, 1'b1}, // 5'h18 {1,1,0,0,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h19 {1,1,0,0,1}
    '{1'b0, 1'b0, 1'b0}, // 5'h1a {1,1,0,1,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h1b {1,1,0,1,1}
    '{1'b1, 1'b0, 1'b1}, // 5'h1c {1,1,1,0,0}
    '{1'b0, 1'b0, 1'b0}, // 5'h1d {1,1,1,0,1}
    '{1'b0, 1'b0, 1'b0}, // 5'h1e {1,1,1,1,0}
    '{1'b0, 1'b0, 1'b0}  // 5'h1f {1,1,1,1,1}
  };

  function automatic logic [31:0] imm_align4(input logic [31:0] imm);
    return {imm[31:2], 2'b00};
  endfunction

  assign ctrl     = {is_spec, i0_pred_taken, i1_pred_taken, i0_brch_recover, i1_brch_recover};
  assign stall    = CTRL_LUT[ctrl].stall;
  assign mode     = CTRL_LUT[ctrl].mode;
  assign spec0_en = CTRL_LUT[ctrl].spec0_en;

  always_comb begin
    pc0_out = imm_align4(pc0_in);
    pc1_out = imm_align4(pc1_in);

    if (i0_brch_recover) begin
      pc0_out = imm_align4(i0_pc_execute);
      pc1_out = imm_align4(i0_pc_execute) + 32'd4;
    end else if (i1_brch_recover) begin
      pc0_out = imm_align4(i1_pc_execute);
      pc1_out = imm_align4(i1_pc_execute) + 32'd4;
    end else if (i0_pred_taken && i1_pred_taken) begin
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

endmodule
