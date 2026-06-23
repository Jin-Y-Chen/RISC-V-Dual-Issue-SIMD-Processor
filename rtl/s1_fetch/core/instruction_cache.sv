`timescale 1ns / 1ps

// Instruction memory — dual combinational fetch (RV32I, one 32-bit word per slot).
// 8192 entries over 32 KiB I$ (PC[14:2]); 512 sets × 16 ways via cache_pkg.
// Miss (valid=0) => 32'h0; each slot holds one little-endian instruction word.
module instruction_cache
  import rv_dis_pkg::*;
  import cache_pkg::*;
#(
  parameter int INDEX_W = PC_INDEX_AW,
  parameter int DATA_W  = ILEN
) (
  // retained for s1_fetch_struct port compatibility; fetch read is combinational
  input  logic        clk,
  input  logic        rst_n,

  // input data
  input  pc_t         pc0,
  input  pc_t         pc1,

  // output data
  output instr_t      instr0,
  output instr_t      instr1
);

  localparam cache_struct_t CACHE = cache_struct_build#(.DATA_W(DATA_W), .INDEX_W(INDEX_W))();

  logic [DATA_W:0] bank [CACHE.sets][CACHE.ways];

  function automatic logic [DATA_W-1:0] insn_default(input pc_t pc);
    return {DATA_W{1'b0}};
  endfunction

  assign instr0 = instr_t'(cache_set_read#(DATA_W)(
    bank[pc_set(pc0, CACHE)],
    pc_way(pc0, CACHE),
    insn_default(pc0)
  ));

  assign instr1 = instr_t'(cache_set_read#(DATA_W)(
    bank[pc_set(pc1, CACHE)],
    pc_way(pc1, CACHE),
    insn_default(pc1)
  ));

  initial begin
    for (int s = 0; s < CACHE.sets; s++) begin
      for (int w = 0; w < CACHE.ways; w++) begin
        bank[s][w] = '0;
      end
    end
  end

endmodule
