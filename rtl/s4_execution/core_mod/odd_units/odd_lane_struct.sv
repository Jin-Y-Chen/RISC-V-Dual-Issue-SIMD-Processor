`timescale 1ns / 1ps

// Odd execution lane: LW/SW, branches, jumps, LUI/AUIPC. Instantiates per slot (I0/I1).
module odd_lane
  import rv_dis_pkg::*;
(
  // internal controls
  input  logic        enable,

  // input data
  input  opcode_t     opcode,
  input  funct3_t     funct3,
  input  logic        rs1_use,    // decode: rs1 is a real GPR read
  input  logic        rs2_use,    // decode: rs2 is a real GPR read
  input  reg_t        rs1_data,
  input  reg_t        rs2_data,
  input  imm_t        imm,
  input  pc_t         pc,

  // output controls
  output logic        brch_taken,
  output logic        mem_en,
  output logic        mem_act,

  // output data
  output pc_t         brch_pc,
  output pc_t         mem_addr,
  output reg_t        mem_wdata,
  output mem_besel_t  mem_besel,
  output pc_t         link_pc,
  output reg_t        reg_wdata
);

  logic brch_cond;

  branch_target_unit u_branch (
    .funct3     (funct3),
    .rs1_use    (rs1_use),
    .rs2_use    (rs2_use),
    .rs1_data   (rs1_data),
    .rs2_data   (rs2_data),
    .brch_taken (brch_cond)
  );

  assign mem_en  = enable && (opcode == OPC_LOAD || opcode == OPC_STORE);
  assign mem_act = (opcode == OPC_STORE);

  memory_address_unit u_mem (
    .funct3    (funct3),
    .is_store  (mem_en && mem_act),
    .rs1_use   (rs1_use),
    .rs2_use   (rs2_use),
    .rs1_data  (rs1_data),
    .rs2_data  (rs2_data),
    .imm       (imm),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_besel (mem_besel)
  );

  assign brch_taken = enable && (((opcode == OPC_BRANCH) && brch_cond) ||
                                 (opcode == OPC_JAL) || (opcode == OPC_JALR));
  assign brch_pc    = (opcode == OPC_JALR) ? pc_t'((rs1_data + imm) & pc_t'(32'hFFFFFFFE)) : (pc + imm);

  assign link_pc = pc + pc_t'(32'd4);
  assign reg_wdata = (opcode == OPC_AUIPC) ? (pc + imm) : imm;

endmodule
