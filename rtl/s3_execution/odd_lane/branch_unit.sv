// Branch condition evaluation for the odd execution lane.
module branch_unit
  import spu_lite_pkg::*;
(
  input  logic [2:0]  funct3,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  output logic        branch_taken
);

  always_comb begin
    branch_taken = 1'b0;

    unique case (funct3)
      F3_BEQ:  branch_taken = (rs1_data == rs2_data);
      F3_BNE:  branch_taken = (rs1_data != rs2_data);
      F3_BLT:  branch_taken = ($signed(rs1_data) < $signed(rs2_data));
      F3_BGE:  branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
      F3_BLTU: branch_taken = (rs1_data < rs2_data);
      F3_BGEU: branch_taken = (rs1_data >= rs2_data);
      default: branch_taken = 1'b0;
    endcase
  end

endmodule
