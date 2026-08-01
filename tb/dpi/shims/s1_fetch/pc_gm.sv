`timescale 1ns / 1ps

// DPI shim - golden logic in model/s1_fetch/pc_gm.cpp
import dpi_pkg::*;

module pc_gm #(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        dispatch_stall,
  input  logic        spec0_stall,
  input  logic        spec1_stall,
  input  logic        spec0_in,
  input  logic        spec1_in,
  input  logic [31:0] pc0_in,
  input  logic [31:0] pc1_in,
  output logic [31:0] pc0_out,
  output logic [31:0] pc1_out,
  output logic        spec0_out,
  output logic        spec1_out
);

  chandle h;
  int p0, p1, s0, s1;

  initial begin
    h = pc_dpi_create(int'(RESET_PC));
    if (h == null) $fatal(1, "pc_dpi_create failed");
  end
  final pc_dpi_destroy(h);

  always @(posedge clk) begin
    pc_dpi_commit(h, int'(rst_n), int'(enable), int'(dispatch_stall),
                  int'(spec0_stall), int'(spec1_stall), int'(spec0_in), int'(spec1_in),
                  int'(pc0_in), int'(pc1_in));
    pc_dpi_eval(h, p0, p1, s0, s1);
    pc0_out   <= p0[31:0];
    pc1_out   <= p1[31:0];
    spec0_out <= s0[0];
    spec1_out <= s1[0];
  end

endmodule
