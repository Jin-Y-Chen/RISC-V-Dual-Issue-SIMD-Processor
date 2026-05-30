`timescale 1ns / 1ps

// Top-level odd execution lane: LW/SW, branches, jumps, LUI/AUIPC (RV32I).
module odd_lane
  import spu_lite_pkg::*;
(
  input  logic        valid,
  input  logic [6:0]  opcode,
  input  logic [2:0]  funct3,
  input  logic [4:0]  rd,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [31:0] imm,
  input  logic [31:0] pc,

  output logic        branch_taken,
  output logic [31:0] branch_target,
  output logic        jump,
  output logic [31:0] jump_target,
  output logic        mem_read,
  output logic        mem_write,
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  output logic [3:0]  mem_be,
  output logic        reg_write,
  output logic [4:0]  rd_out,
  output logic [31:0] link_data,
  output logic [31:0] wb_data
);

  logic u_type;

  logic branch_cond;

  branch_unit u_branch (
    .funct3       (funct3),
    .rs1_data     (rs1_data),
    .rs2_data     (rs2_data),
    .branch_taken (branch_cond)
  );

  address_gen u_addr (
    .funct3    (funct3),
    // Store byte-enable: SW only (SB/SH disabled in address_gen)
    .is_store  (valid && (opcode == OPC_STORE) && (funct3 == F3_SW)),
    .rs1_data  (rs1_data),
    .rs2_data  (rs2_data),
    .imm       (imm),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_be    (mem_be)
  );

  assign mem_read  = valid && (opcode == OPC_LOAD) && (funct3 == F3_LW);
  assign mem_write = valid && (opcode == OPC_STORE) && (funct3 == F3_SW);

  assign branch_taken  = valid && (opcode == OPC_BRANCH) && branch_cond;
  assign branch_target = pc + imm;

  assign jump        = valid && (opcode == OPC_JAL || opcode == OPC_JALR);
  assign jump_target = (opcode == OPC_JALR) ? ((rs1_data + imm) & 32'hFFFFFFFE) : (pc + imm);

  assign u_type = valid && (opcode == OPC_LUI || opcode == OPC_AUIPC);

  assign reg_write = valid && (
    ((opcode == OPC_LOAD) && (funct3 == F3_LW)) ||
    (opcode == OPC_JAL) ||
    (opcode == OPC_JALR) ||
    u_type
  ) && (rd != 5'd0);

  assign rd_out    = rd;
  assign link_data = pc + 32'd4;
  // U-type: imm = {instr[31:12], 12'b0} from decode_imm / imm_u
  assign wb_data   = (opcode == OPC_AUIPC) ? (pc + imm) : imm;

endmodule
