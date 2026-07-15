`timescale 1ns / 1ps

// Golden model for rtl/s1_fetch/core_mod/pc.sv
// Exhaustive control LUT for advance/hold; spec flags pass through on ADV.
//
// ctrl[6:0] = {rst_n, enable, dispatch_stall, spec0_stall, spec1_stall, spec0_in, spec1_in}
// mode = spec0_in ^ spec1_in  => ADV4 else ADV8

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

  typedef enum logic [1:0] {
    GM_RESET = 2'd0,
    GM_HOLD  = 2'd1,
    GM_ADV4  = 2'd2,
    GM_ADV8  = 2'd3
  } gm_op_e;

  function automatic gm_op_e gm_op(
    input logic rst_n_i,
    input logic en_i,
    input logic dstall_i,
    input logic s0_i,
    input logic s1_i,
    input logic mode_i
  );
    begin
      if (!rst_n_i)
        return GM_RESET;
      if (!en_i || dstall_i || s0_i || s1_i)
        return GM_HOLD;
      return mode_i ? GM_ADV4 : GM_ADV8;
    end
  endfunction

  logic        mode;
  logic [6:0]  ctrl;
  gm_op_e      lut_op;
  logic [31:0] aligned_pc0;
  logic [31:0] aligned_pc1;

  assign mode        = spec0_in ^ spec1_in;
  assign ctrl        = {rst_n, enable, dispatch_stall, spec0_stall, spec1_stall,
                        spec0_in, spec1_in};
  assign lut_op      = gm_op(rst_n, enable, dispatch_stall, spec0_stall, spec1_stall, mode);
  assign aligned_pc0 = pc0_in & ~32'd3;
  assign aligned_pc1 = pc1_in & ~32'd3;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc0_out   <= RESET_PC;
      pc1_out   <= RESET_PC + 32'd4;
      spec0_out <= 1'b0;
      spec1_out <= 1'b0;
    end else begin
      unique case (lut_op)
        GM_HOLD: begin
        end
        GM_ADV4: begin
          pc0_out   <= aligned_pc0 + 32'd4;
          pc1_out   <= aligned_pc1 + 32'd4;
          spec0_out <= spec0_in;
          spec1_out <= spec1_in;
        end
        GM_ADV8: begin
          pc0_out   <= aligned_pc0 + 32'd8;
          pc1_out   <= aligned_pc1 + 32'd8;
          spec0_out <= spec0_in;
          spec1_out <= spec1_in;
        end
        default: begin
        end
      endcase
    end
  end

endmodule
