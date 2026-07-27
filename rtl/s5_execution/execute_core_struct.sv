`timescale 1ns / 1ps

// S5 execute — four combinational lanes (RS / PRF / dp_ex live in S4 issue).
// Operands arrive ready; this stage only computes ALU / branch / mem address.
import rv_dis_pkg::*;

module s4_execute_struct (
  input  logic        ev0_enable_ex,
  input  opcode_t     ev0_opcode_ex,
  input  funct3_t     ev0_funct3_ex,
  input  funct7_t     ev0_funct7_ex,
  input  word_t       ev0_imm_ex,
  input  word_t       ev0_rs1_data_ex,
  input  word_t       ev0_rs2_data_ex,

  input  logic        ev1_enable_ex,
  input  opcode_t     ev1_opcode_ex,
  input  funct3_t     ev1_funct3_ex,
  input  funct7_t     ev1_funct7_ex,
  input  word_t       ev1_imm_ex,
  input  word_t       ev1_rs1_data_ex,
  input  word_t       ev1_rs2_data_ex,

  input  logic        od0_enable_ex,
  input  opcode_t     od0_opcode_ex,
  input  funct3_t     od0_funct3_ex,
  input  word_t       od0_imm_ex,
  input  word_t       od0_pc_ex,
  input  word_t       od0_rs1_data_ex,
  input  word_t       od0_rs2_data_ex,

  input  logic        od1_enable_ex,
  input  opcode_t     od1_opcode_ex,
  input  funct3_t     od1_funct3_ex,
  input  word_t       od1_imm_ex,
  input  word_t       od1_pc_ex,
  input  word_t       od1_rs1_data_ex,
  input  word_t       od1_rs2_data_ex,

  output logic        od0_use_link_ex,
  output logic        od1_use_link_ex,
  output logic        od0_brch_taken,
  output logic        od0_mem_en,
  output logic        od0_mem_write,
  output logic        od1_brch_taken,
  output logic        od1_mem_en,
  output logic        od1_mem_write,

  output word_t       ev0_alu_result,
  output word_t       ev1_alu_result,
  output word_t       od0_brch_pc,
  output word_t       od0_mem_addr,
  output word_t       od0_mem_wdata,
  output mem_besel_t  od0_mem_besel,
  output word_t       od0_link_pc,
  output word_t       od0_alu_result,
  output word_t       od1_brch_pc,
  output word_t       od1_mem_addr,
  output word_t       od1_mem_wdata,
  output mem_besel_t  od1_mem_besel,
  output word_t       od1_link_pc,
  output word_t       od1_alu_result
);

  assign od0_use_link_ex = od0_enable_ex &&
                           ((od0_opcode_ex == OPC_JAL) || (od0_opcode_ex == OPC_JALR));
  assign od1_use_link_ex = od1_enable_ex &&
                           ((od1_opcode_ex == OPC_JAL) || (od1_opcode_ex == OPC_JALR));

  even_lane u_ev0 (
    .enable     (ev0_enable_ex),
    .opcode     (ev0_opcode_ex),
    .funct3     (ev0_funct3_ex),
    .funct7     (ev0_funct7_ex),
    .rs1_data   (ev0_rs1_data_ex),
    .rs2_data   (ev0_rs2_data_ex),
    .imm        (ev0_imm_ex),
    .alu_result (ev0_alu_result)
  );

  even_lane u_ev1 (
    .enable     (ev1_enable_ex),
    .opcode     (ev1_opcode_ex),
    .funct3     (ev1_funct3_ex),
    .funct7     (ev1_funct7_ex),
    .rs1_data   (ev1_rs1_data_ex),
    .rs2_data   (ev1_rs2_data_ex),
    .imm        (ev1_imm_ex),
    .alu_result (ev1_alu_result)
  );

  odd_lane u_od0 (
    .enable     (od0_enable_ex),
    .opcode     (od0_opcode_ex),
    .funct3     (od0_funct3_ex),
    .rs1_data   (od0_rs1_data_ex),
    .rs2_data   (od0_rs2_data_ex),
    .imm        (od0_imm_ex),
    .pc         (od0_pc_ex),
    .brch_taken (od0_brch_taken),
    .mem_en     (od0_mem_en),
    .mem_write  (od0_mem_write),
    .brch_pc    (od0_brch_pc),
    .mem_addr   (od0_mem_addr),
    .mem_wdata  (od0_mem_wdata),
    .mem_besel  (od0_mem_besel),
    .link_pc    (od0_link_pc),
    .reg_wdata  (od0_alu_result)
  );

  odd_lane u_od1 (
    .enable     (od1_enable_ex),
    .opcode     (od1_opcode_ex),
    .funct3     (od1_funct3_ex),
    .rs1_data   (od1_rs1_data_ex),
    .rs2_data   (od1_rs2_data_ex),
    .imm        (od1_imm_ex),
    .pc         (od1_pc_ex),
    .brch_taken (od1_brch_taken),
    .mem_en     (od1_mem_en),
    .mem_write  (od1_mem_write),
    .brch_pc    (od1_brch_pc),
    .mem_addr   (od1_mem_addr),
    .mem_wdata  (od1_mem_wdata),
    .mem_besel  (od1_mem_besel),
    .link_pc    (od1_link_pc),
    .reg_wdata  (od1_alu_result)
  );

endmodule
