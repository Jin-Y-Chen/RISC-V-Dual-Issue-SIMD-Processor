`timescale 1ns / 1ps

// Scalar memory address unit: effective address, store data, byte enables (LW/SW only).
module memory_address_unit
  import rv_dis_pkg::*;
(
  // internal controls
  input  logic        is_store,

  // input data
  input  funct3_t     funct3,
  input  logic        rs1_use,    // decode: rs1 is a real GPR read (address base)
  input  logic        rs2_use,    // decode: rs2 is a real GPR read (store data)
  input  reg_t        rs1_data,
  input  reg_t        rs2_data,
  input  imm_t        imm,

  // output data
  output pc_t         mem_addr,
  output reg_t        mem_wdata,
  output mem_besel_t  mem_besel
);

  logic [1:0] addr_lsb;

  // Base address is rs1 when it is a real source; with no base register the
  // effective address is the immediate alone (base 0 + imm). Store data is rs2
  // when used, otherwise the immediate stands in.
  assign mem_addr  = (rs1_use ? rs1_data : reg_t'(32'd0)) + imm;
  assign addr_lsb  = mem_addr[1:0];
  assign mem_wdata = rs2_use ? rs2_data : imm;

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
