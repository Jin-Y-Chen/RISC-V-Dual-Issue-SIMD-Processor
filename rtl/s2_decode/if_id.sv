`timescale 1ns / 1ps

// IF/ID pipeline register — dual-issue pair ([2]: index 0 = I0, 1 = I1).
// Maps IF → ID every enabled cycle (no per-lane fetch_valid gate).
// fetch_valid_if = I$ hit; target_valid_if = BTB hit. rst/flush => bubble.
import rv_dis_pkg::*;

module if_id (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall,

  input  logic        fetch_valid_if  [2],
  input  logic        target_valid_if [2],
  input  logic        spec_en_if      [2],
  input  instr_t      instr_if        [2],
  input  word_t       pc_if           [2],
  input  word_t       pc_target_if    [2],

  output instr_t      instr_id         [2],
  output word_t       pc_id            [2],
  output word_t       pc_target_id     [2],
  output logic        fetch_valid_id   [2],
  output logic        target_valid_id  [2],
  output logic        spec_en_id       [2]
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      for (int i = 0; i < N_DUAL; i++) begin
        instr_id[i]        <= INSTR_NOP;
        pc_id[i]           <= '0;
        pc_target_id[i]    <= '0;
        fetch_valid_id[i]  <= 1'b0;
        target_valid_id[i] <= 1'b0;
        spec_en_id[i]      <= 1'b0;
      end
    end else if (enable && !stall) begin
      for (int i = 0; i < N_DUAL; i++) begin
        instr_id[i]        <= instr_if[i];
        pc_id[i]           <= pc_if[i];
        pc_target_id[i]    <= pc_target_if[i];
        fetch_valid_id[i]  <= fetch_valid_if[i];
        target_valid_id[i] <= target_valid_if[i];
        spec_en_id[i]      <= spec_en_if[i];
      end
    end
  end

endmodule
