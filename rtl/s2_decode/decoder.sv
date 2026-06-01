`timescale 1ns / 1ps

// ID-stage instruction decoder: fields, immediate, lane_sel, GPR uses, legality.
// One instance per insn slot (I0 / I1); issue/dispatch sits downstream.
module decoder
  import rv_dis_pkg::*;
  import rv_dis_decode_pkg::*;
(
  input  logic        valid_in,
  input  logic [31:0] instr,
  input  logic [31:0] pc,       // byte address of this instruction (program-order tag)

  output logic        valid_out, // valid_in && legal; reject = valid_in && !valid_out
  output lane_sel_e   lane_sel,
  output logic [6:0]  opcode,
  output logic [2:0]  funct3,
  output logic [6:0]  funct7,
  output logic [4:0]  rd,
  output logic [4:0]  rs1,
  output logic [4:0]  rs2,
  output logic [31:0] imm,
  output logic [31:0] pc_out,
  output logic        rs1_use,
  output logic        rs2_use,
  output logic        reg_write
);

  logic legal;

  assign opcode  = decode_opcode(instr);
  assign funct3  = decode_funct3(instr);
  assign funct7  = decode_funct7(instr);
  assign rd      = decode_rd(instr);
  assign rs1     = decode_rs1(instr);
  assign rs2     = decode_rs2(instr);
  assign imm     = decode_imm(opcode, funct3, instr);
  assign pc_out  = pc;

  assign lane_sel   = decode_lane_sel(opcode);
  assign legal      = insn_legal_scalar(opcode, funct3) && (lane_sel != LANE_NONE);
  assign valid_out = valid_in && legal;

  assign rs1_use    = decode_rs1_use(opcode);
  assign rs2_use    = decode_rs2_use(opcode);
  assign reg_write  = decode_reg_write(opcode, funct3, rd);

endmodule
