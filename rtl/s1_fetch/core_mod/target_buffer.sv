`timescale 1ns / 1ps
import rv_dis_pkg::*;
import cache_pkg::*;

// Branch target buffer — combinational storage (mirrors state_buffer style).
// 8192 entries over 32 KiB I$ (PC[14:2]); 512 sets × 16 ways via cache_pkg.
// Lookup and WB update in the same cycle; miss (valid=0) => fallthrough(pc) = pc+4.
module target_buffer #(
  parameter int INDEX_W = 13,
  parameter int DATA_W  = 32
) (
  input  word_t  i0_pc,
  input  word_t  i1_pc,

  input  logic   i0_valid_wb,
  input  logic   i1_valid_wb,
  input  word_t  i0_pc_wb,
  input  word_t  i1_pc_wb,
  input  word_t  i0_pc_target_wb,
  input  word_t  i1_pc_target_wb,

  output word_t  i0_pc_target,
  output word_t  i1_pc_target
);

  localparam cache_struct_t CACHE = cache_struct_build(DATA_W, INDEX_W, 16);

  logic [32:0] bank [CACHE.sets][CACHE_WAYS_MAX];

  function automatic word_t fallthrough(input word_t pc);
    return pc + word_t'(32'd4);
  endfunction

  assign i0_pc_target = word_t'(cache_set_read(
    bank[pc_set(i0_pc, CACHE)],
    pc_way(i0_pc, CACHE),
    fallthrough(i0_pc),
    CACHE.ways,
    DATA_W
  ));

  assign i1_pc_target = word_t'(cache_set_read(
    bank[pc_set(i1_pc, CACHE)],
    pc_way(i1_pc, CACHE),
    fallthrough(i1_pc),
    CACHE.ways,
    DATA_W
  ));

  initial begin
    for (int s = 0; s < CACHE.sets; s++) begin
      for (int w = 0; w < CACHE.ways; w++) begin
        bank[s][w] = '0;
      end
    end
  end

  always_comb begin
    if (i0_valid_wb) begin
      bank[pc_set(i0_pc_wb, CACHE)][pc_way(i0_pc_wb, CACHE)] =
        cache_set_write(1'b1, imm_align4(i0_pc_target_wb), DATA_W);
    end
    if (i1_valid_wb) begin
      bank[pc_set(i1_pc_wb, CACHE)][pc_way(i1_pc_wb, CACHE)] =
        cache_set_write(1'b1, imm_align4(i1_pc_target_wb), DATA_W);
    end
  end

endmodule
