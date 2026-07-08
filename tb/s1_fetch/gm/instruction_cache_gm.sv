`timescale 1ns / 1ps

import rv_dis_pkg::*;
import cache_pkg::*;

// Golden model for rtl/s1_fetch/core_mod/instruction_cache.sv
// Combinational dual read; miss => 32'h0. Preload via preload_en for TB.

module instruction_cache_gm #(
  parameter integer INDEX_W = PC_INDEX_AW,
  parameter integer DATA_W  = ILEN,
  parameter integer WAYS    = 4
) (
  input  logic   clk,
  input  logic   rst_n,
  input  logic   preload_en,
  input  word_t  preload_pc,
  input  instr_t preload_data,
  input  word_t  pc0,
  input  word_t  pc1,
  output instr_t instr0,
  output instr_t instr1
);

  localparam integer WAY_AW   = (WAYS <= 1) ? 0 : $clog2(WAYS);
  localparam integer SET_AW   = INDEX_W - WAY_AW;
  localparam integer SETS     = (1 << INDEX_W) / WAYS;
  localparam [31:0]  MISS_DATA = 32'h0000_0000;

  logic [32:0] bank [0:SETS-1][0:WAYS-1];

  wire [15:0] i0_lookup_set = pc_set(pc0, WAY_AW, SET_AW);
  wire [15:0] i0_lookup_way = pc_way(pc0, WAY_AW);
  wire [15:0] i1_lookup_set = pc_set(pc1, WAY_AW, SET_AW);
  wire [15:0] i1_lookup_way = pc_way(pc1, WAY_AW);

  wire [32:0] i0_entry = bank[i0_lookup_set][i0_lookup_way];
  wire [32:0] i1_entry = bank[i1_lookup_set][i1_lookup_way];

  assign instr0 = cache_way_read(i0_entry, MISS_DATA, DATA_W);
  assign instr1 = cache_way_read(i1_entry, MISS_DATA, DATA_W);

  always @(posedge preload_en) begin
    bank[pc_set(preload_pc, WAY_AW, SET_AW)][pc_way(preload_pc, WAY_AW)] =
      cache_set_write(1'b1, preload_data[31:0], DATA_W);
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int s = 0; s < SETS; s++) begin
        for (int w = 0; w < WAYS; w++) begin
          bank[s][w] <= 33'd0;
        end
      end
    end
  end

endmodule
