`timescale 1ns / 1ps

import rv_dis_pkg::*;
import cache_pkg::*;

// Golden model for rtl/s1_fetch/core_mod/target_buffer.sv
// Combinational dual read with WB forwarding; miss => fallthrough(pc+4);
// bank trains on negedge clk.

module target_buffer_gm #(
  parameter integer INDEX_W = 13,
  parameter integer DATA_W  = 32,
  parameter integer WAYS    = 16
) (
  input  logic  clk,
  input  logic  rst_n,
  input  word_t i0_pc,
  input  word_t i1_pc,
  input  logic  i0_valid_wb,
  input  logic  i1_valid_wb,
  input  word_t i0_pc_wb,
  input  word_t i1_pc_wb,
  input  word_t i0_pc_target_wb,
  input  word_t i1_pc_target_wb,
  output word_t i0_pc_target,
  output word_t i1_pc_target
);

  localparam integer WAY_AW = (WAYS <= 1) ? 0 : $clog2(WAYS);
  localparam integer SET_AW = INDEX_W - WAY_AW;
  localparam integer SETS   = (1 << INDEX_W) / WAYS;

  logic [32:0] bank [0:SETS-1][0:WAYS-1];

  wire [15:0] i0_lookup_set = pc_set(i0_pc, WAY_AW, SET_AW);
  wire [15:0] i0_lookup_way = pc_way(i0_pc, WAY_AW);
  wire [15:0] i1_lookup_set = pc_set(i1_pc, WAY_AW, SET_AW);
  wire [15:0] i1_lookup_way = pc_way(i1_pc, WAY_AW);
  wire [15:0] wb0_set       = pc_set(i0_pc_wb, WAY_AW, SET_AW);
  wire [15:0] wb0_way       = pc_way(i0_pc_wb, WAY_AW);
  wire [15:0] wb1_set       = pc_set(i1_pc_wb, WAY_AW, SET_AW);
  wire [15:0] wb1_way       = pc_way(i1_pc_wb, WAY_AW);
  wire [32:0] wb0_entry     = cache_set_write(1'b1, imm_align4(i0_pc_target_wb), DATA_W);
  wire [32:0] wb1_entry     = cache_set_write(1'b1, imm_align4(i1_pc_target_wb), DATA_W);
  wire [31:0] i0_fallthrough = i0_pc + 32'd4;
  wire [31:0] i1_fallthrough = i1_pc + 32'd4;

  function automatic [32:0] way_with_forward(
    input [15:0] set_i,
    input [15:0] way_i
  );
    logic [32:0] stored;
    stored = bank[set_i][way_i];
    way_with_forward = stored;
    if (i0_valid_wb && (wb0_set == set_i) && (wb0_way == way_i))
      way_with_forward = wb0_entry;
    else if (i1_valid_wb && (wb1_set == set_i) && (wb1_way == way_i))
      way_with_forward = wb1_entry;
  endfunction

  wire [32:0] i0_entry_fwd = way_with_forward(i0_lookup_set, i0_lookup_way);
  wire [32:0] i1_entry_fwd = way_with_forward(i1_lookup_set, i1_lookup_way);

  assign i0_pc_target = cache_way_read(i0_entry_fwd, i0_fallthrough, DATA_W);
  assign i1_pc_target = cache_way_read(i1_entry_fwd, i1_fallthrough, DATA_W);

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int s = 0; s < SETS; s++) begin
        for (int w = 0; w < WAYS; w++) begin
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
