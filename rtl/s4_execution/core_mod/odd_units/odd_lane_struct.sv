`timescale 1ns / 1ps

// Odd execution lane: LW/SW, branches, jumps, LUI/AUIPC. Instantiates per slot (I0/I1).
import rv_dis_pkg::*;

module odd_lane (
  // internal controls
  input  logic        enable,

  // input data
  input  opcode_t     opcode,
  input  funct3_t     funct3,
  input  word_t       rs1_data,
  input  word_t       rs2_data,
  input  word_t       imm,
  input  word_t       pc,

  // output controls
  output logic        brch_taken,
  output logic        mem_en,
  output logic        mem_write,

  // output data
  output word_t       brch_pc,
  output word_t       mem_addr,
  output word_t       mem_wdata,
  output mem_besel_t  mem_besel,
  output word_t       link_pc,
  output word_t       reg_wdata
);

  word_t operand_a;
  word_t operand_b;
  logic  brch_cond;

  // BRANCH/STORE: rs1 + rs2; LOAD and other odd-lane ops: rs1 + imm.
  assign operand_a = rs1_data;
  assign operand_b = ((opcode == OPC_STORE) || (opcode == OPC_BRANCH)) ? rs2_data : imm;

  branch_target_unit u_branch (
    .funct3     (funct3),
    .operand_a  (operand_a),
    .operand_b  (operand_b),
    .brch_taken (brch_cond)
  );

  assign mem_en    = enable && (opcode == OPC_LOAD || opcode == OPC_STORE);
  assign mem_write = (opcode == OPC_STORE);

  memory_address_unit u_mem (
    .is_store  (mem_en && mem_write),
    .opcode     (opcode),
    .funct3     (funct3),
    .operand_a  (operand_a),
    .operand_b  (operand_b),
    .imm        (imm),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_besel (mem_besel)
  );

  assign brch_taken = enable && (((opcode == OPC_BRANCH) && brch_cond) ||
                                 (opcode == OPC_JAL) || (opcode == OPC_JALR));
  assign brch_pc    = (opcode == OPC_JALR) ? word_t'((operand_a + imm) & word_t'(32'hFFFFFFFE)) : (pc + imm);

  assign link_pc = pc + word_t'(32'd4);
  assign reg_wdata = (opcode == OPC_AUIPC) ? (pc + imm) : imm;

endmodule
