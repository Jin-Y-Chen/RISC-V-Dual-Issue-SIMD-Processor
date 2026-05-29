`timescale 1ns / 1ps

// Scalar integer ALU for the even execution lane (RV32I OP / OP-IMM subset).
module scalar_alu
  import spu_lite_pkg::*;
(
  input  alu_op_e     alu_op,
  input  alu_a_sel_e  alu_a_sel,
  input  alu_b_sel_e  alu_b_sel,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [31:0] imm,
  input  logic [31:0] pc,
  output logic [31:0] alu_result
);

  logic [31:0] operand_a;
  logic [31:0] operand_b;
  logic [4:0]  shamt;

  always_comb begin
    unique case (alu_a_sel)
      ALU_A_RS1: operand_a = rs1_data;
      ALU_A_PC:  operand_a = pc;
      default:   operand_a = rs1_data;
    endcase
  end

  always_comb begin
    unique case (alu_b_sel)
      ALU_B_RS2: operand_b = rs2_data;
      ALU_B_IMM: operand_b = imm;
      ALU_B_FOUR: operand_b = 32'd4;
      default:   operand_b = rs2_data;
    endcase
  end

  assign shamt = operand_b[4:0];

  always_comb begin
    unique case (alu_op)
      ALU_ADD: alu_result = operand_a + operand_b;
      ALU_SUB: alu_result = operand_a - operand_b;
      ALU_SLL: alu_result = operand_a << shamt;
      ALU_SLT: alu_result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
      ALU_XOR: alu_result = operand_a ^ operand_b;
      ALU_SRL: alu_result = operand_a >> shamt;
      ALU_SRA: alu_result = $signed(operand_a) >>> shamt;
      ALU_AND: alu_result = operand_a & operand_b;
      ALU_OR:  alu_result = operand_a | operand_b;
      default: alu_result = 32'h0;
    endcase
  end

endmodule
