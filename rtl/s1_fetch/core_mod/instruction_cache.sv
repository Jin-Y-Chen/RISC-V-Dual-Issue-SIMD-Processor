`timescale 1ns / 1ps
import rv_dis_pkg::*;
import cache_pkg::*;

// Instruction cache — dual combinational fetch (see project_outline.txt I$).
// 0) 32 KiB byte-addressed space; each entry = valid + ILEN=32 LE word (33b).
// 1) 2-way set-assoc over PC[14:2]: INDEX_W=13, 4096 sets × 2 ways (4 B/entry).
// 2) Combinational dual read; miss (valid=0) => 32'h0.
// 3) Sequential miss/refill — not implemented.
module instruction_cache #(
  parameter integer INDEX_W = PC_INDEX_AW,
  parameter integer DATA_W  = ILEN,
  parameter integer WAYS    = 2
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

  // -------------------------------------------------------------------------
  // 1. 2-way set-associative geometry (4-byte instruction word per entry)
  // -------------------------------------------------------------------------
  localparam integer WAY_AW    = (WAYS <= 1) ? 0 : $clog2(WAYS);
  localparam integer SET_AW    = INDEX_W - WAY_AW;
  localparam integer SETS      = (1 << INDEX_W) / WAYS;
  localparam [31:0]  MISS_DATA = 32'h0000_0000;

  // bank[set][way] = {valid, instr[31:0]} — one RV32I word per cell
  reg [DATA_W:0] bank [0:SETS-1][0:WAYS-1];

  wire [15:0] i0_lookup_set;
  wire [15:0] i0_lookup_way;
  wire [15:0] i1_lookup_set;
  wire [15:0] i1_lookup_way;
  wire [DATA_W:0] i0_entry;
  wire [DATA_W:0] i1_entry;

  assign i0_lookup_set = pc_set(pc0, WAY_AW, SET_AW);
  assign i0_lookup_way = pc_way(pc0, WAY_AW);
  assign i1_lookup_set = pc_set(pc1, WAY_AW, SET_AW);
  assign i1_lookup_way = pc_way(pc1, WAY_AW);

  // -------------------------------------------------------------------------
  // 2. Combinational dual instruction address read
  // -------------------------------------------------------------------------
  // Independent same-cycle lookups. valid=1 => stored word; valid=0 => MISS_DATA.
  assign i0_entry = bank[i0_lookup_set][i0_lookup_way];
  assign i1_entry = bank[i1_lookup_set][i1_lookup_way];

  assign instr0 = cache_way_read(i0_entry, MISS_DATA, DATA_W);
  assign instr1 = cache_way_read(i1_entry, MISS_DATA, DATA_W);

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
