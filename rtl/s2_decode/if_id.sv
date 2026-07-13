`timescale 1ns / 1ps

// IF/ID pipeline register — dual-issue insn pair per cycle (project_outline decode stage).
// An insn is in IF or ID, not both; this register is the boundary between those stages.
// Latches insn/PC/target plus per-lane valid and speculation enables from fetch.
import rv_dis_pkg::*;

module if_id (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls
  input  logic        flush,
  input  logic        stall,
  input  logic        i0_valid_if,
  input  logic        i1_valid_if,
  input  logic        spec0_en_if,
  input  logic        spec1_en_if,

  // input data
  input  instr_t      i0_instr_if,
  input  instr_t      i1_instr_if,
  input  word_t       i0_pc_if,
  input  word_t       i1_pc_if,
  input  word_t       i0_pc_target_if,
  input  word_t       i1_pc_target_if,

  // output data
  output instr_t      i0_instr_id,
  output instr_t      i1_instr_id,
  output word_t       i0_pc_id,
  output word_t       i1_pc_id,
  output word_t       i0_pc_target_id,
  output word_t       i1_pc_target_id,

  // output controls
  output logic        i0_valid_id,
  output logic        i1_valid_id,
  output logic        spec0_en_id,
  output logic        spec1_en_id
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i0_instr_id     <= '0;
      i1_instr_id     <= '0;
      i0_pc_id        <= '0;
      i1_pc_id        <= '0;
      i0_pc_target_id <= '0;
      i1_pc_target_id <= '0;
      i0_valid_id     <= 1'b0;
      i1_valid_id     <= 1'b0;
      spec0_en_id     <= 1'b0;
      spec1_en_id     <= 1'b0;
    end else if (flush) begin
      i0_instr_id     <= '0;
      i1_instr_id     <= '0;
      i0_pc_id        <= '0;
      i1_pc_id        <= '0;
      i0_pc_target_id <= '0;
      i1_pc_target_id <= '0;
      i0_valid_id     <= 1'b0;
      i1_valid_id     <= 1'b0;
      spec0_en_id     <= 1'b0;
      spec1_en_id     <= 1'b0;
    end else if (enable && !stall) begin
      i0_instr_id     <= i0_instr_if;
      i1_instr_id     <= i1_instr_if;
      i0_pc_id        <= i0_pc_if;
      i1_pc_id        <= i1_pc_if;
      i0_pc_target_id <= i0_pc_target_if;
      i1_pc_target_id <= i1_pc_target_if;
      i0_valid_id     <= i0_valid_if;
      i1_valid_id     <= i1_valid_if;
      spec0_en_id     <= spec0_en_if;
      spec1_en_id     <= spec1_en_if;
    end
  end

endmodule
