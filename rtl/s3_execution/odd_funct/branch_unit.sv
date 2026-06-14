`timescale 1ns / 1ps

// Branch condition evaluation for the odd execution lane.
module branch_unit
  import rv_dis_pkg::*;
(
  input  logic [2:0]  funct3,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  output logic        brch_taken
);

  always_comb begin
    brch_taken = 1'b0;

    unique case (funct3)
      F3_BEQ:  brch_taken = (rs1_data == rs2_data);
      F3_BNE:  brch_taken = (rs1_data != rs2_data);
      F3_BLT:  brch_taken = ($signed(rs1_data) < $signed(rs2_data));
      F3_BGE:  brch_taken = ($signed(rs1_data) >= $signed(rs2_data));
      //F3_BLTU: brch_taken = (rs1_data < rs2_data);
      //F3_BGEU: brch_taken = (rs1_data >= rs2_data);
      default: brch_taken = 1'b0;
    endcase
  end

endmodule
