`timescale 1ns / 1ps
import rv_dis_pkg::*;
import cache_pkg::*;

// Instruction cache — dual combinational fetch (see project_outline.txt I$).
// 0) 32 KiB byte-addressed space; each entry = valid + ILEN=32 LE word (33b).
// 1) 2-way set-assoc over PC[14:2]: INDEX_W=13, 4096 sets × 2 ways (4 B/entry).
// 2) Combinational dual read; miss => instr=32'h0 and valid=0.
// 3) Sequential miss/refill — not implemented.
module instruction_cache #(
  parameter integer INDEX_W = PC_INDEX_AW,
  parameter integer DATA_W  = ILEN,
  parameter integer WAYS    = 2
) (
  //external controls
  input  wire     clk,
  input  wire     rst_n,

  //input data (dual-issue slot pair)
  input  word_t   pc    [2],

  //output data
  output instr_t  instr [2],
  output logic    valid [2]
);

  // -------------------------------------------------------------------------
  // 1. 2-way set-associative geometry (4-byte instruction word per entry)
  // -------------------------------------------------------------------------
  localparam integer WAY_AW    = (WAYS <= 1) ? 0 : $clog2(WAYS);
  localparam integer SET_AW    = INDEX_W - WAY_AW;
  localparam integer SETS      = (1 << INDEX_W) / WAYS;
  localparam [31:0]  MISS_DATA = 32'h0000_0000;

  // bank[set][way] = {valid, instr[31:0]} — one RV32I word per cell
  reg [DATA_W:0] bank [0:SETS-1][0:WAYS-1];

  logic [15:0]   lookup_set [2];
  logic [15:0]   lookup_way [2];
  logic [DATA_W:0] entry    [2];

  // -------------------------------------------------------------------------
  // 2. Combinational dual instruction address read
  // -------------------------------------------------------------------------
  // Independent same-cycle lookups. valid=1 => stored word; valid=0 => MISS_DATA.
  always_comb begin
    for (int i = 0; i < N_DUAL; i++) begin
      lookup_set[i] = pc_set(pc[i], WAY_AW, SET_AW);
      lookup_way[i] = pc_way(pc[i], WAY_AW);
      entry[i]      = bank[lookup_set[i]][lookup_way[i]];
      instr[i]      = cache_way_read(entry[i], MISS_DATA, DATA_W);
      valid[i]      = entry[i][DATA_W];
    end
  end

  // Bank clear on reset; TB/external preload until section 3 miss/refill exists.
  integer s;
  integer w;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (s = 0; s < SETS; s = s + 1) begin
        for (w = 0; w < WAYS; w = w + 1) begin
          bank[s][w] <= {(DATA_W+1){1'b0}};
        end
      end
    end
  end

endmodule
