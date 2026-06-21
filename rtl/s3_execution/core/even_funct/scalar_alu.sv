`timescale 1ns / 1ps

// Scalar integer ALU for the even execution lane (RV32I OP / OP-IMM subset).
module scalar_alu
  import rv_dis_pkg::*;
(
  // input data
  input  alu_op_e     alu_op,
  input  logic [31:0] operand_a,
  input  logic [31:0] operand_b,

  // output data
  output logic [31:0] alu_result
);

  logic [4:0] shamt;

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
