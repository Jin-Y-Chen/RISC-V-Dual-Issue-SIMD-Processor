`timescale 1ns / 1ps

// Golden model for rtl/s1_fetch/core_mod/pc_selector.sv
// Exhaustive 5-bit control LUT - one explicit table row per ctrl[4:0].
// PC math in gm_route_pcs() keyed by per-row route id (any TB stimulus).
//
// ctrl[4:0] = {is_spec, i0_pred_taken, i1_pred_taken, i0_brch_recover, i1_brch_recover}

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

  typedef enum logic [2:0] {
    GM_PC_FALLTHROUGH = 3'd0,
    GM_PC_I0_RECOVER  = 3'd1,
    GM_PC_I1_RECOVER  = 3'd2,
    GM_PC_BOTH_TAKEN  = 3'd3,
    GM_PC_I0_TAKEN    = 3'd4,
    GM_PC_I1_TAKEN    = 3'd5
  } gm_pc_route_e;

  typedef struct packed {
    gm_pc_route_e route;
    logic         stall;
    logic         mode;
    logic         spec0_en;
  } gm_lut_row_t;

  logic [4:0]      ctrl;
  gm_lut_row_t     lut_row;

  // -------------------------------------------------------------------------
  // CTRL_LUT[ctrl] - 32 rows, index = packed control bus (all 2^5 inputs).
  // Comment format: 5'hNN  {is_spec,i0_pred,i1_pred,i0_rec,i1_rec}
  //   row = {route, stall, mode, spec0_en}
  // -------------------------------------------------------------------------
  localparam gm_lut_row_t CTRL_LUT [0:31] = '{
    '{GM_PC_FALLTHROUGH, 1'b0, 1'b0, 1'b0}, // 5'h00 {0,0,0,0,0}
    '{GM_PC_I1_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h01 {0,0,0,0,1}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h02 {0,0,0,1,0}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h03 {0,0,0,1,1}
    '{GM_PC_I1_TAKEN,    1'b0, 1'b1, 1'b1}, // 5'h04 {0,0,1,0,0}
    '{GM_PC_I1_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h05 {0,0,1,0,1}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h06 {0,0,1,1,0}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h07 {0,0,1,1,1}
    '{GM_PC_I0_TAKEN,    1'b0, 1'b1, 1'b1}, // 5'h08 {0,1,0,0,0}
    '{GM_PC_I1_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h09 {0,1,0,0,1}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h0a {0,1,0,1,0}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h0b {0,1,0,1,1}
    '{GM_PC_BOTH_TAKEN,  1'b0, 1'b0, 1'b1}, // 5'h0c {0,1,1,0,0}
    '{GM_PC_I1_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h0d {0,1,1,0,1}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h0e {0,1,1,1,0}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h0f {0,1,1,1,1}
    '{GM_PC_FALLTHROUGH, 1'b0, 1'b0, 1'b1}, // 5'h10 {1,0,0,0,0}
    '{GM_PC_I1_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h11 {1,0,0,0,1}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h12 {1,0,0,1,0}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h13 {1,0,0,1,1}
    '{GM_PC_I1_TAKEN,    1'b1, 1'b1, 1'b1}, // 5'h14 {1,0,1,0,0}
    '{GM_PC_I1_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h15 {1,0,1,0,1}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h16 {1,0,1,1,0}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h17 {1,0,1,1,1}
    '{GM_PC_I0_TAKEN,    1'b1, 1'b1, 1'b1}, // 5'h18 {1,1,0,0,0}
    '{GM_PC_I1_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h19 {1,1,0,0,1}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h1a {1,1,0,1,0}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h1b {1,1,0,1,1}
    '{GM_PC_BOTH_TAKEN,  1'b1, 1'b0, 1'b1}, // 5'h1c {1,1,1,0,0}
    '{GM_PC_I1_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h1d {1,1,1,0,1}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}, // 5'h1e {1,1,1,1,0}
    '{GM_PC_I0_RECOVER,  1'b0, 1'b0, 1'b0}  // 5'h1f {1,1,1,1,1}
  };

  function automatic logic [31:0] gm_word_align(input logic [31:0] addr);
    return {addr[31:2], 2'b00};
  endfunction

  function automatic void gm_route_pcs(
    input  gm_pc_route_e route,
    input  logic [31:0]  in0,
    input  logic [31:0]  in1,
    input  logic [31:0]  tgt0,
    input  logic [31:0]  tgt1,
    input  logic [31:0]  ex0,
    input  logic [31:0]  ex1,
    output logic [31:0]  out0,
    output logic [31:0]  out1
  );
    logic [31:0] base;
    begin
      unique case (route)
        GM_PC_I0_RECOVER: begin
          base  = gm_word_align(ex0);
          out0  = base + 32'd4;
          out1  = base + 32'd8;
        end
        GM_PC_I1_RECOVER: begin
          base  = gm_word_align(ex1);
          out0  = base + 32'd4;
          out1  = base + 32'd8;
        end
        GM_PC_BOTH_TAKEN: begin
          base  = gm_word_align(tgt0);
          out0  = base;
          out1  = base + 32'd4;
        end
        GM_PC_I0_TAKEN: begin
          out0  = gm_word_align(tgt0);
          out1  = gm_word_align(in1);
        end
        GM_PC_I1_TAKEN: begin
          out0  = gm_word_align(tgt1);
          out1  = gm_word_align(in0);
        end
        default: begin
          out0  = gm_word_align(in0);
          out1  = gm_word_align(in1);
        end
      endcase
    end
  endfunction

  assign ctrl     = {is_spec, i0_pred_taken, i1_pred_taken, i0_brch_recover, i1_brch_recover};
  assign lut_row  = CTRL_LUT[ctrl];
  assign stall    = lut_row.stall;
  assign mode     = lut_row.mode;
  assign spec0_en = lut_row.spec0_en;

  always_comb
    gm_route_pcs(
      lut_row.route,
      pc0_in, pc1_in,
      i0_pc_target, i1_pc_target,
      i0_pc_execute, i1_pc_execute,
      pc0_out, pc1_out
    );

endmodule
