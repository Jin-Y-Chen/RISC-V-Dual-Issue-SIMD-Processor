`timescale 1ns / 1ps

// ID-stage instruction decoder: fields, immediate, lane_sel, GPR uses, legality.
// Decode helper functions live in decode_pkg (core/decode_funct/decode.sv).
// One instance per insn slot (I0 / I1); issue/dispatch sits downstream.
module decoder
  import rv_dis_pkg::*;
  import decode_pkg::*;
(
  // input data
  input  instr_t      instr,

  // output data
  output logic        lane_sel,
  output logic        brch_en,
  output opcode_t     opcode,
  output funct3_t     funct3,
  output funct7_t     funct7,
  output gpr_addr_t   rd,
  output gpr_addr_t   rs1,
  output gpr_addr_t   rs2,
  output imm_t        imm,

  // output controls
  output logic        valid,     // 1 when insn is legal for RV-DIS scalar decode
  output logic        rs1_use,
  output logic        rs2_use,
  output logic        reg_write
);

  opcode_t    opcode_raw;
  funct3_t    funct3_raw;

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
  assign valid      = insn_legal_scalar(opcode_raw, funct3_raw);
  assign brch_en    = valid && decode_brch_en(opcode_raw);

  assign rs1_use    = decode_rs1_use(opcode_raw);
  assign rs2_use    = decode_rs2_use(opcode_raw);
  assign reg_write  = decode_reg_write(opcode_raw, funct3_raw, rd);

endmodule
