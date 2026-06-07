`timescale 1ns / 1ps

// IF/ID pipeline register — dual-issue fetch pair (project_outline Dual Decoder).
// Holds I0 (older, lower PC) and I1 (younger, PC+4) in parallel for two decoder instances.
// An insn is in IF or ID, not both; this register is the boundary between those stages.
module if_id (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        stall_if_id,
  input  logic        flush_if_id,

  // Fetch stage (IF) — two aligned 32-bit insns per cycle
  input  logic [31:0] i0_instr_if,
  input  logic [31:0] i0_pc_if,
  input  logic [31:0] i1_instr_if,
  input  logic [31:0] i1_pc_if,

  // Decode stage (ID) — one decoder instance per slot (see decoder.sv)
  output logic [31:0] i0_instr_id,
  output logic [31:0] i0_pc_id,
  output logic [31:0] i1_instr_id,
  output logic [31:0] i1_pc_id
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i0_instr_id <= 32'd0;
      i0_pc_id    <= 32'd0;
      i1_instr_id <= 32'd0;
      i1_pc_id    <= 32'd0;
    end else if (flush_if_id) begin
      i0_instr_id <= 32'd0;
      i0_pc_id    <= 32'd0;
      i1_instr_id <= 32'd0;
      i1_pc_id    <= 32'd0;
    end else if (!stall_if_id) begin
      i0_instr_id <= i0_instr_if;
      i0_pc_id    <= i0_pc_if;
      i1_instr_id <= i1_instr_if;
      i1_pc_id    <= i1_pc_if;
    end
  end

endmodule
