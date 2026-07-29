`timescale 1ns / 1ps

// DPI shim - golden logic in model/s1_fetch/pc_selector_gm.cpp
import dpi_pkg::*;

module pc_selector_gm (
  input  logic        spec0_in,
  input  logic        spec1_in,
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
  output logic        spec0_out,
  output logic        spec1_out,
  output logic [31:0] pc0_out,
  output logic [31:0] pc1_out
);

  int s0, s1, p0, p1;

  always @(*) begin
    pc_sel_dpi_eval(
      int'(spec0_in), int'(spec1_in), int'(i0_pred_taken), int'(i1_pred_taken),
      int'(i0_brch_recover), int'(i1_brch_recover),
      int'(pc0_in), int'(pc1_in), int'(i0_pc_target), int'(i1_pc_target),
      int'(i0_pc_execute), int'(i1_pc_execute),
      s0, s1, p0, p1);
    spec0_out = s0[0];
    spec1_out = s1[0];
    pc0_out   = p0[31:0];
    pc1_out   = p1[31:0];
  end

endmodule
