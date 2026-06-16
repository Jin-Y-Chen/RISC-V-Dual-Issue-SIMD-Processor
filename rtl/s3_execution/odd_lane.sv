`timescale 1ns / 1ps

// Odd execution lane: LW/SW, branches, jumps, LUI/AUIPC. Instantiates per slot (I0/I1).
module odd_lane
  import rv_dis_pkg::*;
(
  input  logic        enable,
  input  logic [6:0]  opcode,
  input  logic [2:0]  funct3,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [31:0] imm,
  input  logic [31:0] pc,

  output logic        brch_taken,
  output logic [31:0] brch_pc,
  output logic        mem_en,
  output logic        mem_act,
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  output logic [3:0]  mem_besel,
  output logic [31:0] link_pc,
  output logic [31:0] reg_wdata
);

  logic brch_cond;

  branch_unit u_branch (
    .funct3     (funct3),
    .rs1_data   (rs1_data),
    .rs2_data   (rs2_data),
    .brch_taken (brch_cond)
  );

  assign mem_en  = enable && (opcode == OPC_LOAD || opcode == OPC_STORE);
  assign mem_act = (opcode == OPC_STORE);

  memory_access u_mem (
    .funct3    (funct3),
    .is_store  (mem_en && mem_act),
    .rs1_data  (rs1_data),
    .rs2_data  (rs2_data),
    .imm       (imm),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_besel (mem_besel)
  );

  assign brch_taken = enable && (((opcode == OPC_BRANCH) && brch_cond) ||
                                 (opcode == OPC_JAL) || (opcode == OPC_JALR));
  assign brch_pc    = (opcode == OPC_JALR) ? ((rs1_data + imm) & 32'hFFFFFFFE) : (pc + imm);

  assign link_pc = pc + 32'd4;
  assign reg_wdata = (opcode == OPC_AUIPC) ? (pc + imm) : imm;

endmodule
