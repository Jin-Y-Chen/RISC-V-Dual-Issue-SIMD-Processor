`timescale 1ns / 1ps

// IF/ID pipeline register — one insn per cycle (project_outline decode stage).
// An insn is in IF or ID, not both; this register is the boundary between those stages.
// pc_target_* carries the fetch-stage predicted branch target for mispredict recovery in ID/EX.
module if_id (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        stall_if_id,
  input  logic        flush_if_id,

  // Fetch stage (IF)
  input  logic [31:0] instr_if,
  input  logic [31:0] pc_if,
  input  logic [31:0] pc_target_if,  // predicted branch target (byte PC)

  // Decode stage (ID)
  output logic [31:0] instr_id,
  output logic [31:0] pc_id,
  output logic [31:0] pc_target_id
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      instr_id     <= 32'd0;
      pc_id        <= 32'd0;
      pc_target_id <= 32'd0;
    end else if (flush_if_id) begin
      instr_id     <= 32'd0;
      pc_id        <= 32'd0;
      pc_target_id <= 32'd0;
    end else if (!stall_if_id) begin
      instr_id     <= instr_if;
      pc_id        <= pc_if;
      pc_target_id <= pc_target_if;
    end
  end

endmodule
