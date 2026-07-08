`timescale 1ns / 1ps
import rv_dis_pkg::*;
import cache_pkg::*;

// Branch target buffer — combinational dual lookup with same-cycle WB forwarding;
// bank trains on negedge clk. 8192 entries over 32 KiB I$ (PC[14:2]); 512 sets x 16 ways.
// Miss (valid=0) => fallthrough(pc) = pc+4.
module target_buffer #(
  parameter integer INDEX_W = 13,
  parameter integer DATA_W  = 32,
  parameter integer WAYS    = 16
) (
  //external controls
  input  wire        clk,
  input  wire        rst_n,

  //internal controls
  input  wire        i0_valid_wb,
  input  wire        i1_valid_wb,

  //input data
  input  word_t      i0_pc,
  input  word_t      i1_pc,
  input  word_t      i0_pc_wb,
  input  word_t      i1_pc_wb,
  input  word_t      i0_pc_target_wb,
  input  word_t      i1_pc_target_wb,

  //output data
  output wire [31:0] i0_pc_target,
  output wire [31:0] i1_pc_target
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
  wire [32:0] i0_entry_fwd;
  wire [32:0] i1_entry_fwd;

  wire [31:0] i0_fallthrough;
  wire [31:0] i1_fallthrough;

  assign i0_fallthrough = i0_pc + 32'd4;
  assign i1_fallthrough = i1_pc + 32'd4;

  assign i0_lookup_set = pc_set(i0_pc, WAY_AW, SET_AW);
  assign i0_lookup_way = pc_way(i0_pc, WAY_AW);
  assign i1_lookup_set = pc_set(i1_pc, WAY_AW, SET_AW);
  assign i1_lookup_way = pc_way(i1_pc, WAY_AW);
  assign wb0_set       = pc_set(i0_pc_wb, WAY_AW, SET_AW);
  assign wb0_way       = pc_way(i0_pc_wb, WAY_AW);
  assign wb1_set       = pc_set(i1_pc_wb, WAY_AW, SET_AW);
  assign wb1_way       = pc_way(i1_pc_wb, WAY_AW);
  assign wb0_entry     = cache_set_write(1'b1, imm_align4(i0_pc_target_wb), DATA_W);
  assign wb1_entry     = cache_set_write(1'b1, imm_align4(i1_pc_target_wb), DATA_W);

  // -------------------------------------------------------------------------
  // 1. Combinational dual read with forwarding
  // -------------------------------------------------------------------------
  // Each port reads bank[set][way] unless a valid WB in the same cycle targets
  // that slot — then the incoming WB entry wins (I0 WB checked before I1 WB).
  function [32:0] way_with_forward;
    input [15:0] set_i;
    input [15:0] way_i;
    reg [32:0] stored;
    begin
      stored = bank[set_i][way_i];
      way_with_forward = stored;
      if (i0_valid_wb && (wb0_set == set_i) && (wb0_way == way_i))
        way_with_forward = wb0_entry;
      else if (i1_valid_wb && (wb1_set == set_i) && (wb1_way == way_i))
        way_with_forward = wb1_entry;
    end
  endfunction

  assign i0_entry_fwd = way_with_forward(i0_lookup_set, i0_lookup_way);
  assign i1_entry_fwd = way_with_forward(i1_lookup_set, i1_lookup_way);

  assign i0_pc_target = cache_way_read(i0_entry_fwd, i0_fallthrough, DATA_W);
  assign i1_pc_target = cache_way_read(i1_entry_fwd, i1_fallthrough, DATA_W);

  // -------------------------------------------------------------------------
  // 2. Sequential falling-edge dual writeback
  // -------------------------------------------------------------------------
  // Training commits on negedge clk. Dual WB can update two slots; same set/way
  // => both NBAs fire and I1 is the final value. Forwarding above exposes the
  // new target on outputs in the train cycle before the bank register updates.
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
