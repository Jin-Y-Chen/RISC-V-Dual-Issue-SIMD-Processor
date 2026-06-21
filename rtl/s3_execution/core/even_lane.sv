`timescale 1ns / 1ps

// Even execution lane: scalar ALU (RV32I OP / OP-IMM). Instantiates per slot (I0/I1).
module even_lane
  import rv_dis_pkg::*;
  import decode_pkg::*;
(
  // internal controls
  input  logic        enable,

  // input data
  input  logic [6:0]  opcode,
  input  logic [2:0]  funct3,
  input  logic [6:0]  funct7,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [31:0] imm,

  // output controls
  output logic        reg_write,

  // output data
  output logic [31:0] alu_result
);

  alu_op_e     alu_op;
  logic [31:0] operand_b;

  assign reg_write = enable && ((opcode == OPC_OP) || (opcode == OPC_OP_IMM));
  assign alu_op    = decode_alu_op(opcode, funct3, funct7);
  assign operand_b = (opcode == OPC_OP_IMM) ? imm : rs2_data;

  scalar_alu u_scalar_alu (
    .alu_op     (alu_op),
    .operand_a  (rs1_data),
    .operand_b  (operand_b),
    .alu_result (alu_result)
  );

endmodule
