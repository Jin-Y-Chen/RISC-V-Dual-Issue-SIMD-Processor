// Scalar integer ALU for the even execution lane (ADD, SUB, AND, OR, XOR).
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

  always_comb begin
    unique case (alu_op)
      ALU_ADD: alu_result = operand_a + operand_b;
      ALU_SUB: alu_result = operand_a - operand_b;
      ALU_AND: alu_result = operand_a & operand_b;
      ALU_OR:  alu_result = operand_a | operand_b;
      ALU_XOR: alu_result = operand_a ^ operand_b;
      default: alu_result = 32'h0;
    endcase
  end

endmodule
