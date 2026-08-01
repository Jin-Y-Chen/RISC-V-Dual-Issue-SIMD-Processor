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

  // input data (dual-issue slot pair)
  input  word_t       pc            [2],
  input  logic        brch_en       [2],

  // writeback controls
  input  logic        valid_wb      [2],

  // writeback data
  input  word_t       brch_pc_wb    [2],
  input  br_state_t   brch_state_wb [2],

  // output data
  output br_state_t   brch_state  [2],
  // output controls — bank entry valid (1=trained/hit, 0=miss → DEFAULT_STATE)
  output logic        state_valid [2]
);

  localparam integer WAY_AW = (WAYS <= 1) ? 0 : $clog2(WAYS);
  localparam integer SET_AW = INDEX_W - WAY_AW;
  localparam integer SETS   = (1 << INDEX_W) / WAYS;

  reg [32:0] bank [0:SETS-1][0:WAYS-1];

  logic [15:0] lookup_set [2];
  logic [15:0] lookup_way [2];
  logic [15:0] wb_set     [2];
  logic [15:0] wb_way     [2];
  logic [32:0] wb_entry   [2];
  logic [32:0] entry_fwd  [2];
  logic [31:0] raw_word   [2];

  // always_comb (not assign+function): XSim must see bank + WB sensitivity.
  always_comb begin
    for (int i = 0; i < N_DUAL; i++) begin
      lookup_set[i] = pc_set(pc[i], WAY_AW, SET_AW);
      lookup_way[i] = pc_way(pc[i], WAY_AW);
      wb_set[i]     = pc_set(brch_pc_wb[i], WAY_AW, SET_AW);
      wb_way[i]     = pc_way(brch_pc_wb[i], WAY_AW);
      wb_entry[i]   = cache_set_write(1'b1, {30'd0, brch_state_wb[i]}, DATA_W);
    end

    for (int i = 0; i < N_DUAL; i++) begin
      entry_fwd[i] = bank[lookup_set[i]][lookup_way[i]];
      if (valid_wb[0] && (wb_set[0] == lookup_set[i]) && (wb_way[0] == lookup_way[i]))
        entry_fwd[i] = wb_entry[0];
      else if (valid_wb[1] && (wb_set[1] == lookup_set[i]) && (wb_way[1] == lookup_way[i]))
        entry_fwd[i] = wb_entry[1];

      raw_word[i]     = cache_way_read(entry_fwd[i], {30'd0, DEFAULT_STATE}, DATA_W);
      state_valid[i]  = entry_fwd[i][DATA_W];
      brch_state[i]   = brch_en[i] ? raw_word[i][1:0] : DEFAULT_STATE;
    end
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
      if (valid_wb[0])
        bank[wb_set[0]][wb_way[0]] <= wb_entry[0];
      if (valid_wb[1])
        bank[wb_set[1]][wb_way[1]] <= wb_entry[1];
    end
  end

endmodule
