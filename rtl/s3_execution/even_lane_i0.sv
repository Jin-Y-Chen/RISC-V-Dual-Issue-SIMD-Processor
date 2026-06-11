`timescale 1ns / 1ps

// Top-level even execution lane, I0 slot (older insn): scalar ALU (RV32I OP / OP-IMM).
// I0-only output: unit_done flags that the result is final in EX, so it can be
// forwarded to the younger I1 slot in the same cycle.
module even_lane_i0
  import rv_dis_pkg::*;
  import decode_pkg::*;
(
  input  logic        enable,
  input  logic [6:0]  opcode,
  input  logic [2:0]  funct3,
  input  logic [6:0]  funct7,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [31:0] imm,

  output logic        unit_done,   // I0 result final in EX (forwardable to I1)
  output logic        reg_write,
  // EX result: latch as alu_result_ex/mem for forwarding and GPR writeback
  output logic [31:0] alu_result
);

  alu_op_e         alu_op;
  logic [31:0]     operand_b;

  assign alu_op    = decode_alu_op(opcode, funct3, funct7);
  assign operand_b = (opcode == OPC_OP_IMM) ? imm : rs2_data;

  scalar_alu u_scalar_alu (
    .alu_op     (alu_op),
    .operand_a  (rs1_data),
    .operand_b  (operand_b),
    .alu_result (alu_result)
  );

  assign reg_write = enable && (opcode == OPC_OP || opcode == OPC_OP_IMM);

  // ALU ops are single-cycle: result is ready the cycle the lane is enabled.
  assign unit_done = enable && (opcode == OPC_OP || opcode == OPC_OP_IMM);

endmodule
