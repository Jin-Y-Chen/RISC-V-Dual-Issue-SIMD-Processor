`timescale 1ns / 1ps

// Branch state buffer — registered storage with same-cycle WB read bypass.
// 8192 entries over 32 KiB I$ (PC[14:2]); 512 sets x 16 ways.
// Miss (valid=0) => DEFAULT_STATE (weakly taken). Bank trains on negedge clk.
import rv_dis_pkg::*;
import cache_pkg::*;

module state_buffer #(
  parameter integer INDEX_W = PC_INDEX_AW,
  parameter integer DATA_W  = 2,
  parameter integer WAYS    = 16,
  parameter [1:0] DEFAULT_STATE = 2'b10
) (
  // external controls
  input  logic        clk,
  input  logic        rst_n,

  // input data
  input  word_t       i0_pc,
  input  word_t       i1_pc,
  input  logic        i0_brch_en,
  input  logic        i1_brch_en,

  // writeback controls
  input  logic        i0_valid_wb,
  input  logic        i1_valid_wb,

  // writeback data
  input  word_t       i0_brch_pc_wb,
  input  word_t       i1_brch_pc_wb,
  input  br_state_t   i0_brch_state_wb,
  input  br_state_t   i1_brch_state_wb,

  // output data
  output br_state_t   i0_brch_state,
  output br_state_t   i1_brch_state
);

  localparam integer WAY_AW = (WAYS <= 1) ? 0 : $clog2(WAYS);
  localparam integer SET_AW = INDEX_W - WAY_AW;
  localparam integer SETS   = (1 << INDEX_W) / WAYS;

  reg [32:0] bank [0:SETS-1][0:WAYS-1];

  wire [15:0] i0_lookup_set;
  wire [15:0] i0_lookup_way;
  wire [15:0] i1_lookup_set;
  wire [15:0] i1_lookup_way;
  wire [15:0] wb0_set;
  wire [15:0] wb0_way;
  wire [15:0] wb1_set;
  wire [15:0] wb1_way;

  wire [32:0] wb0_entry;
  wire [32:0] wb1_entry;
  logic [32:0] i0_entry_fwd;
  logic [32:0] i1_entry_fwd;

  wire [31:0] raw_word0;
  wire [31:0] raw_word1;

  assign i0_lookup_set = pc_set(i0_pc, WAY_AW, SET_AW);
  assign i0_lookup_way = pc_way(i0_pc, WAY_AW);
  assign i1_lookup_set = pc_set(i1_pc, WAY_AW, SET_AW);
  assign i1_lookup_way = pc_way(i1_pc, WAY_AW);
  assign wb0_set       = pc_set(i0_brch_pc_wb, WAY_AW, SET_AW);
  assign wb0_way       = pc_way(i0_brch_pc_wb, WAY_AW);
  assign wb1_set       = pc_set(i1_brch_pc_wb, WAY_AW, SET_AW);
  assign wb1_way       = pc_way(i1_brch_pc_wb, WAY_AW);
  assign wb0_entry     = cache_set_write(1'b1, {30'd0, i0_brch_state_wb}, DATA_W);
  assign wb1_entry     = cache_set_write(1'b1, {30'd0, i1_brch_state_wb}, DATA_W);

  // always_comb (not assign+function): XSim must see bank + WB sensitivity.
  always_comb begin
    i0_entry_fwd = bank[i0_lookup_set][i0_lookup_way];
    if (i0_valid_wb && (wb0_set == i0_lookup_set) && (wb0_way == i0_lookup_way))
      i0_entry_fwd = wb0_entry;
    else if (i1_valid_wb && (wb1_set == i0_lookup_set) && (wb1_way == i0_lookup_way))
      i0_entry_fwd = wb1_entry;

    i1_entry_fwd = bank[i1_lookup_set][i1_lookup_way];
    if (i0_valid_wb && (wb0_set == i1_lookup_set) && (wb0_way == i1_lookup_way))
      i1_entry_fwd = wb0_entry;
    else if (i1_valid_wb && (wb1_set == i1_lookup_set) && (wb1_way == i1_lookup_way))
      i1_entry_fwd = wb1_entry;
  end

  assign raw_word0 = cache_way_read(i0_entry_fwd, {30'd0, DEFAULT_STATE}, DATA_W);
  assign raw_word1 = cache_way_read(i1_entry_fwd, {30'd0, DEFAULT_STATE}, DATA_W);

  always_comb begin
    i0_brch_state = i0_brch_en ? raw_word0[1:0] : DEFAULT_STATE;
    i1_brch_state = i1_brch_en ? raw_word1[1:0] : DEFAULT_STATE;
  end

  integer s;
  integer w;
  always @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (s = 0; s < SETS; s = s + 1) begin
        for (w = 0; w < WAYS; w = w + 1) begin
          bank[s][w] <= 33'd0;
        end
      end
    end else begin
      if (i0_valid_wb)
        bank[wb0_set][wb0_way] <= wb0_entry;
      if (i1_valid_wb)
        bank[wb1_set][wb1_way] <= wb1_entry;
    end
  end

endmodule
