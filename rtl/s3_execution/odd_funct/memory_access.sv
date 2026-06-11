`timescale 1ns / 1ps

// Scalar memory access: effective address, store data, byte enables (LW/SW only).
module memory_access
  import rv_dis_pkg::*;
(
  input  logic [2:0]  funct3,
  input  logic        is_store,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [31:0] imm,
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  output logic [3:0]  mem_besel
);

  logic [1:0] addr_lsb;

  assign mem_addr  = rs1_data + imm;
  assign addr_lsb  = mem_addr[1:0];
  assign mem_wdata = rs2_data;

  always_comb begin
    mem_besel = 4'b0000;

    if (!is_store) begin
      unique case (funct3)
        // F3_LB, F3_LBU: mem_besel = 4'b0001 << addr_lsb;
        // F3_LH, F3_LHU: mem_besel = (addr_lsb[0] == 1'b0) ? 4'b0011 : 4'b0000;
        F3_LW:   mem_besel = (addr_lsb == 2'b00) ? 4'b1111 : 4'b0000;
        default: mem_besel = 4'b0000;
      endcase
    end else begin
      unique case (funct3)
        // F3_SB: mem_besel = 4'b0001 << addr_lsb;
        // F3_SH: mem_besel = (addr_lsb[0] == 1'b0) ? 4'b0011 : 4'b0000;
        F3_SW: mem_besel = (addr_lsb == 2'b00) ? 4'b1111 : 4'b0000;
        default: mem_besel = 4'b0000;
      endcase
    end
  end

endmodule
