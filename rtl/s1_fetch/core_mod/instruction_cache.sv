`timescale 1ns / 1ps
import rv_dis_pkg::*;
import cache_pkg::*;

// Instruction memory — dual combinational fetch (RV32I, ILEN=32 per slot).
// 32 KiB I$: 8192 entries (PC[14:2]), 2048 sets x 4 ways; byte-addressed map (8 B/addr).
// Miss (valid=0) => 32'h0; each slot holds one little-endian instruction word.
// Section 2 (sequential miss/refill) — not implemented; see project_outline.txt.
module instruction_cache #(
  parameter integer INDEX_W = PC_INDEX_AW,
  parameter integer DATA_W  = ILEN,
  parameter integer WAYS    = 4
) (
  //external controls
  input  wire     clk,
  input  wire     rst_n,

  //input data
  input  word_t   pc0,
  input  word_t   pc1,

  //output data
  output instr_t  instr0,
  output instr_t  instr1

);

  localparam integer WAY_AW   = (WAYS <= 1) ? 0 : $clog2(WAYS);
  localparam integer SET_AW   = INDEX_W - WAY_AW;
  localparam integer SETS     = (1 << INDEX_W) / WAYS;
  localparam [31:0]  MISS_DATA = 32'h0000_0000;

  reg [32:0] bank [0:SETS-1][0:WAYS-1];

  wire [15:0] i0_lookup_set;
  wire [15:0] i0_lookup_way;
  wire [15:0] i1_lookup_set;
  wire [15:0] i1_lookup_way;
  wire [32:0] i0_entry;
  wire [32:0] i1_entry;

  assign i0_lookup_set = pc_set(pc0, WAY_AW, SET_AW);
  assign i0_lookup_way = pc_way(pc0, WAY_AW);
  assign i1_lookup_set = pc_set(pc1, WAY_AW, SET_AW);
  assign i1_lookup_way = pc_way(pc1, WAY_AW);

  // -------------------------------------------------------------------------
  // 1. Combinational dual instruction address read
  // -------------------------------------------------------------------------
  // Both ports read bank[set][way] independently in the same cycle. valid=1 =>
  // stored word; valid=0 (cold miss) => MISS_DATA (32'h0). No PC fall-through.
  assign i0_entry = bank[i0_lookup_set][i0_lookup_way];
  assign i1_entry = bank[i1_lookup_set][i1_lookup_way];

  assign instr0 = cache_way_read(i0_entry, MISS_DATA, DATA_W);
  assign instr1 = cache_way_read(i1_entry, MISS_DATA, DATA_W);

  // Bank clear on reset; preload via simulation/TB until section 2 is implemented.
  integer s;
  integer w;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (s = 0; s < SETS; s = s + 1) begin
        for (w = 0; w < WAYS; w = w + 1) begin
          bank[s][w] <= 33'd0;
        end
      end
    end
  end

endmodule
