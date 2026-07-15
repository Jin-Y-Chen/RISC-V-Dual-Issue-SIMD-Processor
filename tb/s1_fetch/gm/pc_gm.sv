`timescale 1ns / 1ps

// Golden model for rtl/s1_fetch/core_mod/pc.sv
import rv_dis_pkg::*;

module pc_gm #(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        dispatch_stall,
  input  logic        spec0_stall,
  input  logic        spec1_stall,
  input  br_map_t     branch_map_in,
  input  logic [31:0] pc0_in,
  input  logic [31:0] pc1_in,
  output logic [31:0] pc0_out,
  output logic [31:0] pc1_out,
  output br_map_t     branch_map_out
);

  logic stall;
  logic split;
  logic [31:0] aligned_pc0;
  logic [31:0] aligned_pc1;

  assign stall        = dispatch_stall | spec0_stall | spec1_stall;
  assign split        = (branch_map_in == BR_MAP_I0) || (branch_map_in == BR_MAP_I1);
  assign aligned_pc0  = pc0_in & ~32'd3;
  assign aligned_pc1  = pc1_in & ~32'd3;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc0_out        <= RESET_PC;
      pc1_out        <= RESET_PC + 32'd4;
      branch_map_out <= BR_MAP_NONE;
    end else if (enable && !stall) begin
      if (split) begin
        pc0_out <= aligned_pc0 + 32'd4;
        pc1_out <= aligned_pc1 + 32'd4;
      end else begin
        pc0_out <= aligned_pc0 + 32'd8;
        pc1_out <= aligned_pc1 + 32'd8;
      end
      branch_map_out <= branch_map_in;
    end
  end

endmodule
