`timescale 1ns / 1ps

// Even execution lane: scalar ALU (RV32I OP / OP-IMM). Instantiates per slot (I0/I1).
module even_lane
  import rv_dis_pkg::*;
(
  // internal controls
  input  logic        enable,

  // input data
  input  opcode_t     opcode,
  input  funct3_t     funct3,
  input  funct7_t     funct7,
  input  logic        rs1_use,    // decode: rs1 is a real GPR read
  input  logic        rs2_use,    // decode: rs2 is a real GPR read
  input  word_t        rs1_data,
  input  word_t        rs2_data,
  input  word_t        imm,

  // output controls
  output logic        reg_write,

  // output data
  output word_t        alu_result
);

  word_t operand_a;
  word_t operand_b;

  assign reg_write = enable && ((opcode == OPC_OP) || (opcode == OPC_OP_IMM));

  // ALUSrc select: use the register value when decode marks the source used,
  // otherwise the immediate stands in (e.g. OP-IMM has rs2_use = 0 -> operand_b = imm).
  assign operand_a = rs1_use ? rs1_data : imm;
  assign operand_b = rs2_use ? rs2_data : imm;

  scalar_alu u_scalar_alu (
    .opcode     (opcode),
    .funct3     (funct3),
    .funct7     (funct7),
    .operand_a  (operand_a),
    .operand_b  (operand_b),
    .alu_result (alu_result)
  );

endmodule
