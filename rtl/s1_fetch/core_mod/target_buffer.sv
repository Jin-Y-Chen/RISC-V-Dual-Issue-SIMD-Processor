`timescale 1ns / 1ps
import rv_dis_pkg::*;
import cache_pkg::*;

// Branch target buffer — combinational dual lookup with same-cycle WB forwarding;
// bank trains on negedge clk. 8192 entries over 32 KiB I$ (PC[14:2]); 512 sets x 16 ways.
// Miss / invalid entry => i*_valid=0 and i*_pc_target=32'h0; ports independent.
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
  output wire        i0_valid,
  output wire        i1_valid,
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
  logic [32:0] i0_entry_fwd;
  logic [32:0] i1_entry_fwd;

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
  // always_comb (not assign+function): XSim must see full WB sensitivity.
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

  // Per-port hit: bank miss or stored valid=0 => valid=0 and target=0.
  assign i0_valid     = i0_entry_fwd[DATA_W];
  assign i1_valid     = i1_entry_fwd[DATA_W];
  assign i0_pc_target = cache_way_read(i0_entry_fwd, 32'h0, DATA_W);
  assign i1_pc_target = cache_way_read(i1_entry_fwd, 32'h0, DATA_W);

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
