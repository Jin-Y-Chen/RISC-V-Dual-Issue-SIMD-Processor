`timescale 1ns / 1ps

// Branch condition evaluation for the odd execution lane.
module branch_unit
  import rv_dis_pkg::*;
(
  // input data
  input  funct3_t     funct3,
  input  logic        rs1_use,    // decode: rs1 is a real GPR read
  input  logic        rs2_use,    // decode: rs2 is a real GPR read
  input  word_t        rs1_data,
  input  word_t        rs2_data,

  // output controls
  output logic        brch_taken
);

  // Branches read both GPRs; rs*_use masks any operand the decoder did not mark
  // as a real source so a stale forwarded value cannot affect the comparison.
  word_t cmp_a;
  word_t cmp_b;

  assign cmp_a = rs1_use ? rs1_data : word_t'(32'd0);
  assign cmp_b = rs2_use ? rs2_data : word_t'(32'd0);

  always_comb begin
    brch_taken = 1'b0;

    unique case (funct3)
      F3_BEQ:  brch_taken = (cmp_a == cmp_b);
      F3_BNE:  brch_taken = (cmp_a != cmp_b);
      F3_BLT:  brch_taken = ($signed(cmp_a) < $signed(cmp_b));
      F3_BGE:  brch_taken = ($signed(cmp_a) >= $signed(cmp_b));
      //F3_BLTU: brch_taken = (cmp_a < cmp_b);
      //F3_BGEU: brch_taken = (cmp_a >= cmp_b);
      default: brch_taken = 1'b0;
    endcase
  end

endmodule
