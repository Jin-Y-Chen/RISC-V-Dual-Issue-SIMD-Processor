`timescale 1ns / 1ps

import rv_dis_pkg::*;

// PC unit — registered dual-issue addresses + per-lane speculation flags.
// mode is local: spec_in[0] ^ spec_in[1] => +4/+4 split; else +8/+8.
// Stall sources: dispatch back-pressure and decode nested-speculation (spec_stall).
module pc #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  // external controls
  input  logic          clk,
  input  logic          rst_n,
  input  logic          enable,

  // internal controls
  input  logic          dispatch_stall,
  input  logic          spec_stall [2],
  input  logic          spec_in    [2],

  // input data
  input  word_t         pc_in      [2],

  // output data
  output word_t         pc_out     [2],

  // output controls — registered speculation (fed back to pc_selector)
  output logic          spec_out   [2]
);

  word_t pc_next [2];
  logic  stall;
  logic  mode;

  assign stall = dispatch_stall | spec_stall[0] | spec_stall[1];
  // Exactly one next-spec lane => advance each stream by +4; else +8.
  assign mode  = spec_in[0] ^ spec_in[1];

  always_comb begin
    for (int i = 0; i < N_DUAL; i++) begin
      pc_next[i] = pc_out[i];
      if (!stall && enable)
        pc_next[i] = imm_align4(pc_in[i]) + (mode ? 32'd4 : 32'd8);
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < N_DUAL; i++) begin
        pc_out[i]   <= RESET_PC + word_t'(4 * i);
        spec_out[i] <= 1'b0;
      end
    end else if (enable && !stall) begin
      for (int i = 0; i < N_DUAL; i++) begin
        pc_out[i]   <= pc_next[i];
        spec_out[i] <= spec_in[i];
      end
    end
  end

endmodule
