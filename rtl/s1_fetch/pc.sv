`timescale 1ns / 1ps

import rv_dis_pkg::*;

// PC unit — pc0/pc1 from pc0_in/pc1_in; mode=1 => +4/+4, mode=0 => +8/+8.
module pc #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  // external controls
  input  logic          clk,
  input  logic          rst_n,
  input  logic          enable,

  // internal controls
  input  logic          fetch_stall,
  input  logic          dispatch_stall, 
  input  logic          mode,
  input  logic          spec0_en,

  // input data
  input  logic [31:0]   pc0_in,
  input  logic [31:0]   pc1_in,

  // output data
  output logic          is_spec,
  output logic [31:0]   pc0_out,
  output logic [31:0]   pc1_out
);

  logic [31:0] pc0_next, pc1_next;
  logic [31:0] pc0_a, pc1_a;
  logic stall;

  function automatic logic [31:0] imm_align4(input logic [31:0] imm);
    return {imm[31:2], 2'b00};
  endfunction

  assign stall = fetch_stall | dispatch_stall;
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
      pc0_out <= RESET_PC;
      pc1_out <= RESET_PC + 32'd4;
      is_spec <= 1'b0;
    end else if (enable && !stall) begin
      pc0_out <= pc0_next;
      pc1_out <= pc1_next;
      is_spec <= spec0_en;
    end
  end

endmodule
