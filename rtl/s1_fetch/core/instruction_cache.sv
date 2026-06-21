`timescale 1ns / 1ps

// Instruction memory — byte-addressed dual read (RV32I LE word assembly).
// pc0 / pc1: older and younger fetch PCs (pc1 = pc0 + 4)
// instr0 / instr1: 32-bit words read combinational from cache[]
module instruction_cache
  import rv_dis_pkg::*;
#(
  parameter int BYTE_COUNT = I_SIZE / 8
) (
  // external controls
  input  logic        clk,
  input  logic        rst_n,

  // input data
  input  logic [31:0] pc0,
  input  logic [31:0] pc1,

  // output data
  output instr_t      instr0,
  output instr_t      instr1
);

  localparam int BYTE_AW = $clog2(BYTE_COUNT);

  logic [7:0] cache [0:BYTE_COUNT-1];

  integer i;

  function automatic logic [BYTE_AW-1:0] word_base(input logic [31:0] byte_pc);
    return byte_pc[BYTE_AW-1:2] << 2;
  endfunction

  function automatic instr_t read_le_word(input logic [BYTE_AW-1:0] base);
    read_le_word = {
      cache[base + 3],
      cache[base + 2],
      cache[base + 1],
      cache[base + 0]
    };
  endfunction

  assign instr0 = read_le_word(word_base(pc0));
  assign instr1 = read_le_word(word_base(pc1));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      for (i = 0; i < BYTE_COUNT; i++)
        cache[i] <= 8'd0;
  end

endmodule
