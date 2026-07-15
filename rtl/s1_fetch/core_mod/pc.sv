`timescale 1ns / 1ps

import rv_dis_pkg::*;

// PC unit — registered dual-issue addresses + per-lane speculation flags.
// mode is local: spec0_in ^ spec1_in => +4/+4 split; else +8/+8.
// Stall sources: dispatch back-pressure and decode nested-speculation (spec*_stall).
module pc #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  // external controls
  input  logic          clk,
  input  logic          rst_n,
  input  logic          enable,

  // internal controls
  input  logic          dispatch_stall,
  input  logic          spec0_stall,
  input  logic          spec1_stall,
  input  logic          spec0_in,
  input  logic          spec1_in,

  // input data
  input  logic [31:0]   pc0_in,
  input  logic [31:0]   pc1_in,

  // output data
  output logic [31:0]   pc0_out,
  output logic [31:0]   pc1_out,

  // output controls — registered speculation (fed back to pc_selector)
  output logic          spec0_out,
  output logic          spec1_out
);

  logic [31:0] pc0_next, pc1_next;
  logic [31:0] pc0_a, pc1_a;
  logic        stall;
  logic        mode;

  function automatic logic [31:0] imm_align4(input logic [31:0] imm);
    return {imm[31:2], 2'b00};
  endfunction

  assign stall = dispatch_stall | spec0_stall | spec1_stall;
  // Exactly one next-spec lane => advance each stream by +4; else +8.
  assign mode  = spec0_in ^ spec1_in;
  assign pc0_a = imm_align4(pc0_in);
  assign pc1_a = imm_align4(pc1_in);

  always_comb begin
    pc0_next = pc0_out;
    pc1_next = pc1_out;

    if (!stall && enable) begin
      if (mode) begin
        pc0_next = pc0_a + 32'd4;
        pc1_next = pc1_a + 32'd4;
      end else begin
        pc0_next = pc0_a + 32'd8;
        pc1_next = pc1_a + 32'd8;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc0_out   <= RESET_PC;
      pc1_out   <= RESET_PC + 32'd4;
      spec0_out <= 1'b0;
      spec1_out <= 1'b0;
    end else if (enable && !stall) begin
      pc0_out   <= pc0_next;
      pc1_out   <= pc1_next;
      spec0_out <= spec0_in;
      spec1_out <= spec1_in;
    end
  end

endmodule
