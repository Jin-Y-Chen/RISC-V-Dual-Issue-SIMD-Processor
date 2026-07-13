`timescale 1ns / 1ps

// Scalar memory address unit: effective address, store data, byte enables (LW/SW only).
import rv_dis_pkg::*;

module memory_address_unit (
  // internal controls
  input  logic        is_store,

  // input data
  input  opcode_t     opcode,
  input  funct3_t     funct3,
  input  word_t       operand_a,
  input  word_t       operand_b,
  input  word_t       imm,

  // output data
  output word_t       mem_addr,
  output word_t       mem_wdata,
  output mem_besel_t  mem_besel
);

  logic [1:0] addr_lsb;

  // LOAD/STORE only: base + offset; store data is rs2, load wdata unused.
  assign mem_addr  = operand_a + imm;
  assign addr_lsb  = mem_addr[1:0];
  assign mem_wdata = (opcode == OPC_STORE) ? operand_b : imm;

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
