`timescale 1ns / 1ps

import rv_dis_pkg::*;
import dpi_pkg::*;

// DPI shim — model/s2_decode/decoder_gm.cpp
module decoder_gm (
  input  instr_t      instr,
  output logic        lane_sel,
  output logic        brch_en,
  output logic        jump_en,
  output opcode_t     opcode,
  output funct3_t     funct3,
  output funct7_t     funct7,
  output gpr_addr_t   rd_addr,
  output gpr_addr_t   rs1_addr,
  output gpr_addr_t   rs2_addr,
  output word_t       imm,
  output logic        valid,
  output logic        rs1_use,
  output logic        rs2_use,
  output logic        store_en,
  output logic        reg_write
);

  int ls, be, je, op, f3, f7, rd, rs1, rs2, im, v, u1, u2, st, rw;

  always @(*) begin
    decoder_dpi_eval(int'(instr), ls, be, je, op, f3, f7, rd, rs1, rs2, im, v, u1, u2, st, rw);
    lane_sel  = ls[0];
    brch_en   = be[0];
    jump_en   = je[0];
    opcode    = op[6:0];
    funct3    = f3[2:0];
    funct7    = f7[6:0];
    rd_addr   = rd[4:0];
    rs1_addr  = rs1[4:0];
    rs2_addr  = rs2[4:0];
    imm       = im[31:0];
    valid     = v[0];
    rs1_use   = u1[0];
    rs2_use   = u2[0];
    store_en  = st[0];
    reg_write = rw[0];
  end

endmodule
