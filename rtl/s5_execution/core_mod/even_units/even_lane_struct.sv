`timescale 1ns / 1ps

// Even execution lane: scalar ALU (RV32I OP / OP-IMM). Instantiates per slot (I0/I1).
import rv_dis_pkg::*;

module even_lane (
  // internal controls
  input  logic        enable,

  // input data
  input  opcode_t     opcode,
  input  funct3_t     funct3,
  input  funct7_t     funct7,
  input  word_t       rs1_data,
  input  word_t       rs2_data,
  input  word_t       imm,

  // output controls
  output logic        reg_write,

  // output data
  output word_t        alu_result
);

  word_t operand_a;
  word_t operand_b;

  assign reg_write = enable && ((opcode == OPC_OP) || (opcode == OPC_OP_IMM));

  // OP: rs1 + rs2; OP-IMM: rs1 + imm (only opcodes routed to this lane).
  assign operand_a = rs1_data;
  assign operand_b = (opcode == OPC_OP) ? rs2_data : imm;

  scalar_alu u_scalar_alu (
    .opcode     (opcode),
    .funct3     (funct3),
    .funct7     (funct7),
    .operand_a  (operand_a),
    .operand_b  (operand_b),
    .alu_result (alu_result)
  );

endmodule
