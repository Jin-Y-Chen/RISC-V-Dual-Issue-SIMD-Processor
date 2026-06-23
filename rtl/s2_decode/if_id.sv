`timescale 1ns / 1ps

// IF/ID pipeline register — dual-issue insn pair per cycle (project_outline decode stage).
// An insn is in IF or ID, not both; this register is the boundary between those stages.
// pc_target_* carries the fetch-stage predicted branch target for mispredict recovery in ID/EX.
module if_id
  import rv_dis_pkg::*;
(
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  // internal controls
  input  logic        flush,
  input  logic        stall,
  // input data
  input  instr_t      i0_instr_if,
  input  instr_t      i1_instr_if,
  input  pc_t         i0_pc_if,
  input  pc_t         i1_pc_if,
  input  pc_t         i0_pc_target_if,
  input  pc_t         i1_pc_target_if,
  // output data
  output instr_t      i0_instr_id,
  output instr_t      i1_instr_id,
  output pc_t         i0_pc_id,
  output pc_t         i1_pc_id,
  output pc_t         i0_pc_target_id,
  output pc_t         i1_pc_target_id
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i0_instr_id     <= '0;
      i1_instr_id     <= '0;
      i0_pc_id        <= '0;
      i1_pc_id        <= '0;
      i0_pc_target_id <= '0;
      i1_pc_target_id <= '0;
    end else if (flush) begin
      i0_instr_id     <= '0;
      i1_instr_id     <= '0;
      i0_pc_id        <= '0;
      i1_pc_id        <= '0;
      i0_pc_target_id <= '0;
      i1_pc_target_id <= '0;
    end else if (enable && !stall) begin
      i0_instr_id     <= i0_instr_if;
      i1_instr_id     <= i1_instr_if;
      i0_pc_id        <= i0_pc_if;
      i1_pc_id        <= i1_pc_if;
      i0_pc_target_id <= i0_pc_target_if;
      i1_pc_target_id <= i1_pc_target_if;
    end
  end

endmodule
