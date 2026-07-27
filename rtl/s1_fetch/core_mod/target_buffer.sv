`timescale 1ns / 1ps
import rv_dis_pkg::*;
import cache_pkg::*;

// Branch target buffer — combinational dual lookup with same-cycle WB forwarding;
// bank trains on negedge clk. 8192 entries over 32 KiB I$ (PC[14:2]); 512 sets x 16 ways.
// Miss / invalid entry => valid=0 and pc_target=32'h0; ports independent.
module target_buffer #(
  parameter integer INDEX_W = 13,
  parameter integer DATA_W  = 32,
  parameter integer WAYS    = 16
) (
  //external controls
  input  wire        clk,
  input  wire        rst_n,

  //internal controls
  input  logic       valid_wb     [2],

  //input data (dual-issue slot pair)
  input  word_t      pc           [2],
  input  word_t      pc_wb        [2],
  input  word_t      pc_target_wb [2],

  //output data
  output logic       valid        [2],
  output word_t      pc_target    [2]
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

  // -------------------------------------------------------------------------
  // 1. Combinational dual read with forwarding
  // -------------------------------------------------------------------------
  // always_comb (not assign+function): XSim must see full WB sensitivity.
  always_comb begin
    for (int i = 0; i < N_DUAL; i++) begin
      lookup_set[i] = pc_set(pc[i], WAY_AW, SET_AW);
      lookup_way[i] = pc_way(pc[i], WAY_AW);
      wb_set[i]     = pc_set(pc_wb[i], WAY_AW, SET_AW);
      wb_way[i]     = pc_way(pc_wb[i], WAY_AW);
      wb_entry[i]   = cache_set_write(1'b1, imm_align4(pc_target_wb[i]), DATA_W);
    end

    // Per-port hit: bank miss or stored valid=0 => valid=0 and target=0.
    for (int i = 0; i < N_DUAL; i++) begin
      entry_fwd[i] = bank[lookup_set[i]][lookup_way[i]];
      if (valid_wb[0] && (wb_set[0] == lookup_set[i]) && (wb_way[0] == lookup_way[i]))
        entry_fwd[i] = wb_entry[0];
      else if (valid_wb[1] && (wb_set[1] == lookup_set[i]) && (wb_way[1] == lookup_way[i]))
        entry_fwd[i] = wb_entry[1];

      valid[i]     = entry_fwd[i][DATA_W];
      pc_target[i] = cache_way_read(entry_fwd[i], 32'h0, DATA_W);
    end
  end

  // -------------------------------------------------------------------------
  // 2. Sequential falling-edge dual writeback
  // -------------------------------------------------------------------------
  // Training commits on negedge clk. Dual WB can update two slots; same set/way
  // => both NBAs fire and lane 1 is the final value. Forwarding above exposes the
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
      if (valid_wb[0])
        bank[wb_set[0]][wb_way[0]] <= wb_entry[0];
      if (valid_wb[1])
        bank[wb_set[1]][wb_way[1]] <= wb_entry[1];
    end
  end

endmodule
