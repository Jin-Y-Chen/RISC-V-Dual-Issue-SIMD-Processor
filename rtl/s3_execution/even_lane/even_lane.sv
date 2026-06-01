`timescale 1ns / 1ps

// Top-level even execution lane: scalar ALU (RV32I OP / OP-IMM integer ops).
module even_lane
  import rv_dis_pkg::*;
  import rv_dis_decode_pkg::*;
(
  input  logic        valid,
  input  logic [6:0]  opcode,
  input  logic [2:0]  funct3,
  input  logic [6:0]  funct7,
  input  logic [4:0]  rd,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [31:0] imm,
  input  logic [31:0] pc,       // insn byte address (program-order tag for WB / hazards)

  output logic        reg_write,
  output logic [4:0]  rd_out,
  // EX result: latch as alu_result_ex/mem for forwarding and GPR writeback
  output logic [31:0] alu_result,
  output logic [31:0] pc_out    // passthrough; latch in ex_mem_even → WB age vs odd lane
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

  assign reg_write = valid && (opcode == OPC_OP || opcode == OPC_OP_IMM) && (rd != 5'd0);
  assign rd_out    = rd;
  assign pc_out    = pc;

endmodule
