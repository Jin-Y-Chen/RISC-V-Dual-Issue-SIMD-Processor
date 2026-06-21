`timescale 1ns / 1ps

// ID-stage instruction decoder: fields, immediate, lane_sel, GPR uses, legality.
// One instance per insn slot (I0 / I1); issue/dispatch sits downstream.
module decoder
  import rv_dis_pkg::*;
  import decode_pkg::*;
(
  // input data
  input  logic [31:0] instr,

  // output data
  output lane_sel_e   lane_sel,
  output logic        brch_en,
  output logic [6:0]  opcode,
  output logic [2:0]  funct3,
  output logic [6:0]  funct7,
  output logic [4:0]  rd,
  output logic [4:0]  rs1,
  output logic [4:0]  rs2,
  output logic [31:0] imm,

  // output controls
  output logic        valid,     // 1 when insn is legal for RV-DIS scalar decode
  output logic        rs1_use,
  output logic        rs2_use,
  output logic        reg_write
);

  logic legal;

  logic [6:0] opcode_raw;
  logic [2:0] funct3_raw;

  assign opcode_raw = decode_opcode(instr);
  assign funct3_raw = decode_funct3(instr);
  assign opcode     = opcode_raw;
  assign funct3     = decode_funct3_gpr(opcode_raw, instr);
  assign funct7     = decode_funct7_gpr(opcode_raw, funct3_raw, instr);
  assign rd         = decode_rd_gpr(opcode_raw, instr);
  assign rs1        = decode_rs1_gpr(opcode_raw, instr);
  assign rs2        = decode_rs2_gpr(opcode_raw, instr);
  assign imm        = decode_imm(opcode_raw, funct3_raw, instr);

  assign lane_sel   = decode_lane_sel(opcode_raw);
  assign valid      = insn_legal_scalar(opcode_raw, funct3_raw) && (lane_sel != LANE_NONE);
  assign brch_en   = valid && decode_brch_en(opcode_raw);

  assign rs1_use    = decode_rs1_use(opcode_raw);
  assign rs2_use    = decode_rs2_use(opcode_raw);
  assign reg_write  = decode_reg_write(opcode_raw, funct3_raw, rd);

endmodule
