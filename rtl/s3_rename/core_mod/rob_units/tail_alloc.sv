`timescale 1ns / 1ps

// ROB allocate unit — tail side (structurally parallel with rob_retire).
// Pure combinational: indices / payloads / tail_n / wr_*.
// Parent applies wr_* into the shared ROB bank on negedge.
import rv_dis_pkg::*;
import rob_pkg::*;

module rob_alloc (
  input  rob_ptr_t    tail_q,

  input  logic        alloc0_en,
  input  logic        alloc1_en,
  input  logic        i0_reg_write,
  input  logic        i1_reg_write,
  input  logic        i0_is_brnch,
  input  logic        i1_is_brnch,
  input  logic        i0_is_store,
  input  logic        i1_is_store,
  input  logic        i0_spec_en,
  input  logic        i1_spec_en,
  input  gpr_addr_t   i0_rd_addr,
  input  gpr_addr_t   i1_rd_addr,

  output prf_addr_t   i0_rob_idx,
  output prf_addr_t   i1_rob_idx,
  output rob_ptr_t    tail_n,

  // allocation write data (parent applies on negedge into shared bank)
  output logic         wr0_en,
  output logic         wr1_en,
  output rob_set_t     wr0_row,
  output rob_set_t     wr1_row,
  output rob_way_t     wr0_col,
  output rob_way_t     wr1_col,
  output rob_payload_t wr0_data,
  output rob_payload_t wr1_data
);

  logic [1:0] n_alloc;
  rob_flat_t  alloc_base, a0_flat, a1_flat;

  assign n_alloc = {1'b0, alloc0_en} + {1'b0, alloc1_en};

  // Pack allocates contiguously at tail (single or dual)
  assign alloc_base = tail_q[ROB_INDEX_W-1:0];
  assign a0_flat    = alloc_base;
  assign a1_flat    = rob_flat_t'(alloc_base + (alloc0_en ? 1'b1 : 1'b0));
  assign i0_rob_idx = rob_to_prf(a0_flat);
  assign i1_rob_idx = rob_to_prf(a1_flat);

  assign wr0_en   = alloc0_en;
  assign wr1_en   = alloc1_en;
  assign wr0_row  = rob_row(a0_flat);
  assign wr0_col  = rob_col(a0_flat);
  assign wr1_row  = rob_row(a1_flat);
  assign wr1_col  = rob_col(a1_flat);
  assign wr0_data = rob_entry(
      i0_reg_write, i0_is_brnch, i0_is_store, i0_spec_en, i0_rd_addr);
  assign wr1_data = rob_entry(
      i1_reg_write, i1_is_brnch, i1_is_store, i1_spec_en, i1_rd_addr);

  assign tail_n = (n_alloc != 2'b00)
                ? (tail_q + rob_ptr_t'(n_alloc))
                : tail_q;

endmodule
