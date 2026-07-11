`timescale 1ns / 1ps

import rv_dis_pkg::*;

// Golden model for rtl/s1_fetch/core_mod/target_buffer.sv
// PC-keyed lookup table (not a set/way bank replica).
// Same-cycle WB overlays the table; miss => valid=0, target=0.
// Trains on negedge clk (matches DUT commit edge).

module target_buffer_gm #(
  parameter integer INDEX_W = 13,  // unused — kept for TB port compatibility
  parameter integer DATA_W  = 32,  // unused
  parameter integer WAYS    = 16,  // unused
  parameter integer CAP     = 64
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
  output logic  i0_valid,
  output logic  i1_valid,
  output word_t i0_pc_target,
  output word_t i1_pc_target
);

  typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] target;
  } gm_row_t;

  gm_row_t rows [0:CAP-1];
  int      n_rows;

  function automatic logic [31:0] gm_align(input logic [31:0] addr);
    return {addr[31:2], 2'b00};
  endfunction

  // Table lookup by word-aligned PC (linear scan — independent of DUT indexing).
  function automatic void gm_table_get(
    input  logic [31:0] pc,
    output logic        hit,
    output logic [31:0] tgt
  );
    logic [31:0] key;
    key = gm_align(pc);
    hit = 1'b0;
    tgt = 32'h0;
    for (int i = 0; i < n_rows; i++) begin
      if (rows[i].valid && (rows[i].pc == key)) begin
        hit = 1'b1;
        tgt = rows[i].target;
        return;
      end
    end
  endfunction

  // Upsert one trained (pc -> target) row.
  function automatic void gm_table_put(
    input logic [31:0] pc,
    input logic [31:0] tgt
  );
    logic [31:0] key;
    logic [31:0] val;
    key = gm_align(pc);
    val = gm_align(tgt);
    for (int i = 0; i < n_rows; i++) begin
      if (rows[i].valid && (rows[i].pc == key)) begin
        rows[i].target = val;
        return;
      end
    end
    if (n_rows < CAP) begin
      rows[n_rows].valid  = 1'b1;
      rows[n_rows].pc     = key;
      rows[n_rows].target = val;
      n_rows++;
    end
  endfunction

  // Port read: same-cycle WB wins over table (I0 WB before I1 WB).
  function automatic void gm_port_read(
    input  logic [31:0] pc,
    output logic        hit,
    output logic [31:0] tgt
  );
    logic [31:0] key;
    key = gm_align(pc);
    if (i0_valid_wb && (gm_align(i0_pc_wb) == key)) begin
      hit = 1'b1;
      tgt = gm_align(i0_pc_target_wb);
      return;
    end
    if (i1_valid_wb && (gm_align(i1_pc_wb) == key)) begin
      hit = 1'b1;
      tgt = gm_align(i1_pc_target_wb);
      return;
    end
    gm_table_get(pc, hit, tgt);
  endfunction

  always_comb begin
    gm_port_read(i0_pc, i0_valid, i0_pc_target);
    gm_port_read(i1_pc, i1_valid, i1_pc_target);
  end

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_rows <= 0;
      for (int i = 0; i < CAP; i++)
        rows[i] <= '0;
    end else begin
      if (i0_valid_wb)
        gm_table_put(i0_pc_wb, i0_pc_target_wb);
      if (i1_valid_wb)
        gm_table_put(i1_pc_wb, i1_pc_target_wb);
    end
  end

endmodule
