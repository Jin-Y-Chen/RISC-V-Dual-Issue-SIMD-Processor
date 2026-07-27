`timescale 1ns / 1ps

// ROB allocate unit — tail side (structurally parallel with rob_retire).
// Pure combinational: indices / payloads / tail_n / wr_*.
// Parent applies wr_* into the shared ROB bank on negedge.
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
import rv_dis_pkg::*;
import rob_pkg::*;

module rob_alloc (
  input  rob_ptr_t    tail_q,

  input  logic        alloc_en      [2],
  input  logic        reg_write     [2],
  input  logic        is_brnch      [2],
  input  logic        is_store      [2],
  input  logic        spec_en       [2],
  input  logic        state_valid   [2],
  input  br_state_t   brch_state    [2],
  input  gpr_addr_t   rd_addr       [2],

  output prf_addr_t   rob_idx       [2],
  output logic        idx_valid     [2],
  output rob_ptr_t    tail_n,

  // allocation write data (parent applies on negedge into shared bank)
  output logic         wr_en        [2],
  output rob_set_t     wr_row       [2],
  output rob_way_t     wr_col       [2],
  output rob_payload_t wr_data      [2]
);

  logic [1:0] n_alloc;
  rob_flat_t  alloc_base, flat [2];

  assign n_alloc = {1'b0, alloc_en[0]} + {1'b0, alloc_en[1]};

  // Pack allocates contiguously at tail (single or dual)
  assign alloc_base = tail_q[ROB_INDEX_W-1:0];
  assign flat[0]    = alloc_base;
  assign flat[1]    = rob_flat_t'(alloc_base + (alloc_en[0] ? 1'b1 : 1'b0));

  for (genvar i = 0; i < 2; i++) begin : g_lane
    assign rob_idx[i]   = rob_to_prf(flat[i]);
    assign idx_valid[i] = alloc_en[i];
    assign wr_en[i]     = alloc_en[i];
    assign wr_row[i]  = rob_row(flat[i]);
    assign wr_col[i]  = rob_col(flat[i]);
    assign wr_data[i] = rob_entry(
        reg_write[i], is_brnch[i], is_store[i], spec_en[i],
        state_valid[i], brch_state[i], rd_addr[i]);
  end

  assign tail_n = (n_alloc != 2'b00)
                ? (tail_q + rob_ptr_t'(n_alloc))
                : tail_q;

endmodule
