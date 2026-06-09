`timescale 1ns / 1ps

// Top-level odd execution lane: LW/SW, branches, jumps, LUI/AUIPC (RV32I).
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
  output logic        mem_en,   // memory request valid
  output logic        mem_act,  // 0 = read (load), 1 = write (store)
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  output logic [3:0]  mem_besel,
  output logic [31:0] link_pc,
  output logic [31:0] alu_result
);

  logic brch_cond;

  branch_unit u_branch (
    .funct3       (funct3),
    .rs1_data     (rs1_data),
    .rs2_data     (rs2_data),
    .brch_taken   (brch_cond)
  );

  // One request pair: mem_en qualifies the access, mem_act gives direction.
  assign mem_en  = enable && (opcode == OPC_LOAD || opcode == OPC_STORE);
  assign mem_act = (opcode == OPC_STORE);

  memory_access u_mem (
    .funct3    (funct3),
    // Store byte-enable: SW only (SB/SH disabled in memory_access)
    .is_store  (mem_en && mem_act),
    .rs1_data  (rs1_data),
    .rs2_data  (rs2_data),
    .imm       (imm),

    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_besel (mem_besel)
  );

  // Control-flow redirect: taken branch or jump (JAL/JALR).
  // JALR target = (rs1 + imm) with LSB cleared; branch/JAL target = pc + imm.
  assign brch_taken = enable && (((opcode == OPC_BRANCH) && brch_cond) ||
                                 (opcode == OPC_JAL) || (opcode == OPC_JALR));
  assign brch_pc    = (opcode == OPC_JALR) ? ((rs1_data + imm) & 32'hFFFFFFFE) : (pc + imm);

  assign link_pc = pc + 32'd4;
  // U-type: imm = {instr[31:12], 12'b0} from decode_imm / imm_u
  assign alu_result   = (opcode == OPC_AUIPC) ? (pc + imm) : imm;

endmodule
