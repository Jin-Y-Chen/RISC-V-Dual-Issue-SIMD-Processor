`timescale 1ns / 1ps

// Top-level even execution lane: scalar ALU (RV32I OP / OP-IMM integer ops).
module even_lane
  import spu_lite_pkg::*;
(
  input  logic        valid,
  input  logic [6:0]  opcode,
  input  logic [2:0]  funct3,
  input  logic [6:0]  funct7,
  input  logic [4:0]  rd,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [31:0] imm,
  input  logic [31:0] pc,

  output logic        reg_write,
  output logic [4:0]  rd_out,
  output logic [31:0] alu_result,
  output logic [31:0] wb_data
);

  alu_op_e    alu_op;
  alu_a_sel_e alu_a_sel;
  alu_b_sel_e alu_b_sel;

  assign alu_op = decode_alu_op(opcode, funct3, funct7);

  always_comb begin
    alu_a_sel = ALU_A_RS1;
    alu_b_sel = ALU_B_RS2;

    if (valid && (opcode == OPC_OP || opcode == OPC_OP_IMM)) begin
      alu_a_sel = ALU_A_RS1;
      alu_b_sel = (opcode == OPC_OP_IMM) ? ALU_B_IMM : ALU_B_RS2;
    end
  end

  scalar_alu u_scalar_alu (
    .alu_op     (alu_op),
    .alu_a_sel  (alu_a_sel),
    .alu_b_sel  (alu_b_sel),
    .rs1_data   (rs1_data),
    .rs2_data   (rs2_data),
    .imm        (imm),
    .pc         (pc),
    .alu_result (alu_result)
  );

  assign reg_write = valid && (opcode == OPC_OP || opcode == OPC_OP_IMM) && (rd != 5'd0);
  assign rd_out    = rd;
  assign wb_data   = alu_result;

endmodule
