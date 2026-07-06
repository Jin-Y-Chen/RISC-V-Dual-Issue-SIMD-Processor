`timescale 1ns / 1ps

// Branch state buffer — combinational storage (mirrors target_buffer style).
// 8192 entries over 32 KiB I$ (PC[14:2]); 512 sets × 16 ways via cache_pkg.
// Lookup and WB update in the same cycle; miss (valid=0) => DEFAULT_STATE (weakly not taken).
import rv_dis_pkg::*;
import cache_pkg::*;

module state_buffer #(
  parameter int INDEX_W = PC_INDEX_AW,
  parameter int DATA_W  = 2,
  parameter br_state_t DEFAULT_STATE = 2'b01
) (
  // input data — decode lookup
  input  word_t         i0_pc,
  input  word_t         i1_pc,
  input  logic        i0_brch_en,
  input  logic        i1_brch_en,

  // input data — decode writeback (resolved next state)
  input  logic        i0_valid_wb,
  input  logic        i1_valid_wb,
  input  word_t         i0_pc_wb,
  input  word_t         i1_pc_wb,
  input  br_state_t   i0_target_state_wb,
  input  br_state_t   i1_target_state_wb,

  // output data — decode lookup
  output br_state_t   i0_target_state,
  output br_state_t   i1_target_state
);

  localparam cache_struct_t CACHE = cache_struct_build(DATA_W, INDEX_W, 16);

  logic [32:0] bank [CACHE.sets][CACHE_WAYS_MAX];

  br_state_t raw_state0;
  br_state_t raw_state1;

  assign raw_state0 = br_state_t'(cache_set_read(
    bank[bank_set_idx(i0_pc, CACHE)],
    bank_way_idx(i0_pc, CACHE),
    DEFAULT_STATE,
    CACHE.ways,
    DATA_W
  ));

  assign raw_state1 = br_state_t'(cache_set_read(
    bank[bank_set_idx(i1_pc, CACHE)],
    bank_way_idx(i1_pc, CACHE),
    DEFAULT_STATE,
    CACHE.ways,
    DATA_W
  ));

  assign i0_target_state = i0_brch_en ? raw_state0 : DEFAULT_STATE;
  assign i1_target_state = i1_brch_en ? raw_state1 : DEFAULT_STATE;

  initial begin
    for (int s = 0; s < CACHE.sets; s++) begin
      for (int w = 0; w < CACHE.ways; w++) begin
        bank[s][w] = '0;
      end
    end
  end

  always_comb begin
    if (i0_valid_wb) begin
      bank[bank_set_idx(i0_pc_wb, CACHE)][bank_way_idx(i0_pc_wb, CACHE)] =
        cache_set_write(1'b1, i0_target_state_wb, DATA_W);
    end
    if (i1_valid_wb) begin
      bank[bank_set_idx(i1_pc_wb, CACHE)][bank_way_idx(i1_pc_wb, CACHE)] =
        cache_set_write(1'b1, i1_target_state_wb, DATA_W);
    end
  end

endmodule
