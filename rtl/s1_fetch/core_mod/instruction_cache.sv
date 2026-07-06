`timescale 1ns / 1ps
import rv_dis_pkg::*;
import cache_pkg::*;

// Instruction memory — dual combinational fetch (RV32I, ILEN=32 per slot).
// 32 KiB I$: 8192 entries (PC[14:2]), 2048 sets × 4 ways; byte-addressed map (8 B/addr).
// Miss (valid=0) => 32'h0; each slot holds one little-endian instruction word.
module instruction_cache #(
  parameter int INDEX_W = PC_INDEX_AW,  // 13 => 2^13 insn slots × 4 B = 32 KiB
  parameter int DATA_W  = ILEN,         // 32-bit instruction per entry
  parameter int WAYS    = 4             // 4-way set-associative
) (
  // input data
  input  word_t   pc0,
  input  word_t   pc1,

  // output data
  output instr_t  instr0,
  output instr_t  instr1
);

  localparam cache_struct_t CACHE = cache_struct_build(DATA_W, INDEX_W, WAYS);
  localparam int ENTRY_COUNT = (1 << INDEX_W);
  localparam int SETS        = ENTRY_COUNT / WAYS;

  logic [32:0] bank [SETS][CACHE_WAYS_MAX];

  function automatic logic [31:0] insn_default(input word_t pc);
    return 32'h0000_0000;
  endfunction

  assign instr0 = instr_t'(cache_set_read(
    bank[pc_set(pc0, CACHE)],
    pc_way(pc0, CACHE),
    insn_default(pc0),
    CACHE.ways,
    DATA_W
  ));

  assign instr1 = instr_t'(cache_set_read(
    bank[pc_set(pc1, CACHE)],
    pc_way(pc1, CACHE),
    insn_default(pc1),
    CACHE.ways,
    DATA_W
  ));

  initial begin
    for (int s = 0; s < SETS; s++) begin
      for (int w = 0; w < CACHE.ways; w++) begin
        bank[s][w] = '0;
      end
    end
  end

endmodule
