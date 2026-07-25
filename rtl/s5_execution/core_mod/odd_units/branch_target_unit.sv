`timescale 1ns / 1ps

// Branch condition evaluation for the odd execution lane.
import rv_dis_pkg::*;

module branch_target_unit (
  // input data
  input  funct3_t     funct3,
  input  word_t       operand_a,
  input  word_t       operand_b,

  // output controls
  output logic        brch_taken
);

  // Branches (only opcode routed here) always compare rs1 vs rs2.
  always_comb begin
    brch_taken = 1'b0;

    case (funct3)
      F3_BEQ:  brch_taken = (operand_a == operand_b);
      F3_BNE:  brch_taken = (operand_a != operand_b);
      F3_BLT:  brch_taken = ($signed(operand_a) < $signed(operand_b));
      F3_BGE:  brch_taken = ($signed(operand_a) >= $signed(operand_b));
      default: brch_taken = 1'b0;
    endcase
  end

endmodule
