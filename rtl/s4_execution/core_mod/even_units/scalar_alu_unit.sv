`timescale 1ns / 1ps

// Scalar integer ALU for the even execution lane (RV32I OP / OP-IMM subset).
module scalar_alu_unit
  import rv_dis_pkg::*;
(
  // input data
  input  opcode_t     opcode,
  input  funct3_t     funct3,
  input  funct7_t     funct7,
  input  reg_t        operand_a,
  input  reg_t        operand_b,

  // output data
  output reg_t        alu_result
);

  logic [4:0] shamt;

  assign shamt = operand_b[4:0];

  always_comb begin
    unique case (opcode)
      OPC_OP, OPC_OP_IMM: begin
        unique case (funct3)
          F3_ADD_SUB: alu_result = (opcode == OPC_OP && funct7 == F7_SUB) ?
                                   (operand_a - operand_b) :
                                   (operand_a + operand_b);
          F3_SLL:     alu_result = operand_a << shamt;
          F3_SLT:     alu_result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
          F3_XOR:     alu_result = operand_a ^ operand_b;
          // Split branches so the signed operand stays self-determined; a ternary
          // would make the whole expression unsigned and turn >>> into a logical shift.
          F3_SRL_SRA: begin
            if (funct7 == F7_SRA)
              alu_result = $signed(operand_a) >>> shamt;
            else
              alu_result = operand_a >> shamt;
          end
          F3_OR:      alu_result = operand_a | operand_b;
          F3_AND:     alu_result = operand_a & operand_b;
          default:    alu_result = operand_a + operand_b;
        endcase
      end
      default: alu_result = 32'h0;
    endcase
  end

endmodule
