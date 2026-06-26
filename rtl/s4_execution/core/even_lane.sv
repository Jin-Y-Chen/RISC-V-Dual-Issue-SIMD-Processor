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
  input  reg_t        rs1_data,
  input  reg_t        rs2_data,
  input  imm_t        imm,

  // output controls
  output logic        reg_write,

  // output data
  output reg_t        alu_result
);

  reg_t operand_b;

  assign reg_write = enable && ((opcode == OPC_OP) || (opcode == OPC_OP_IMM));
  assign operand_b = (opcode == OPC_OP_IMM) ? imm : rs2_data;

  scalar_alu u_scalar_alu (
    .opcode     (opcode),
    .funct3     (funct3),
    .funct7     (funct7),
    .operand_a  (rs1_data),
    .operand_b  (operand_b),
    .alu_result (alu_result)
  );

endmodule
