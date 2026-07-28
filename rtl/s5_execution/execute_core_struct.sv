`timescale 1ns / 1ps

// S5 execute — four combinational lanes (RS / PRF / dp_ex live in S4 issue).
// Even/odd EX ports are [2] arrays: index 0 = first port, index 1 = second.
// Operands arrive ready; this stage only computes ALU / branch / mem address.
import rv_dis_pkg::*;

module s4_execute_struct (
  input  logic        ev_enable_ex   [2],
  input  opcode_t     ev_opcode_ex   [2],
  input  funct3_t     ev_funct3_ex   [2],
  input  funct7_t     ev_funct7_ex   [2],
  input  word_t       ev_imm_ex      [2],
  input  word_t       ev_rs1_data_ex [2],
  input  word_t       ev_rs2_data_ex [2],

  input  logic        od_enable_ex   [2],
  input  opcode_t     od_opcode_ex   [2],
  input  funct3_t     od_funct3_ex   [2],
  input  word_t       od_imm_ex      [2],
  input  word_t       od_pc_ex       [2],
  input  word_t       od_rs1_data_ex [2],
  input  word_t       od_rs2_data_ex [2],

  output logic        od_use_link_ex [2],
  output logic        od_brch_taken  [2],
  output logic        od_mem_en      [2],
  output logic        od_mem_write   [2],

  output word_t       ev_alu_result  [2],
  output word_t       od_brch_pc     [2],
  output word_t       od_mem_addr    [2],
  output word_t       od_mem_wdata   [2],
  output mem_besel_t  od_mem_besel   [2],
  output word_t       od_link_pc     [2],
  output word_t       od_alu_result  [2]
);

  for (genvar i = 0; i < N_DUAL; i++) begin : g_od_link
    assign od_use_link_ex[i] = od_enable_ex[i] &&
                               ((od_opcode_ex[i] == OPC_JAL) ||
                                (od_opcode_ex[i] == OPC_JALR));
  end

  for (genvar i = 0; i < N_DUAL; i++) begin : g_ev
    even_lane u_ev (
      .enable     (ev_enable_ex[i]),
      .opcode     (ev_opcode_ex[i]),
      .funct3     (ev_funct3_ex[i]),
      .funct7     (ev_funct7_ex[i]),
      .rs1_data   (ev_rs1_data_ex[i]),
      .rs2_data   (ev_rs2_data_ex[i]),
      .imm        (ev_imm_ex[i]),
      .alu_result (ev_alu_result[i])
    );
  end

  for (genvar i = 0; i < N_DUAL; i++) begin : g_od
    odd_lane u_od (
      .enable     (od_enable_ex[i]),
      .opcode     (od_opcode_ex[i]),
      .funct3     (od_funct3_ex[i]),
      .rs1_data   (od_rs1_data_ex[i]),
      .rs2_data   (od_rs2_data_ex[i]),
      .imm        (od_imm_ex[i]),
      .pc         (od_pc_ex[i]),
      .brch_taken (od_brch_taken[i]),
      .mem_en     (od_mem_en[i]),
      .mem_write  (od_mem_write[i]),
      .brch_pc    (od_brch_pc[i]),
      .mem_addr   (od_mem_addr[i]),
      .mem_wdata  (od_mem_wdata[i]),
      .mem_besel  (od_mem_besel[i]),
      .link_pc    (od_link_pc[i]),
      .reg_wdata  (od_alu_result[i])
    );
  end

endmodule
