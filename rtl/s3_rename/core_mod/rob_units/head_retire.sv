`timescale 1ns / 1ps

// ROB retire unit — head side (structurally parallel with rob_alloc).
// Pure combinational: eligibility / commit buses / head_n / cmt*.
// Parent owns the ROB bank; passes head valid/payload only (no rob_q port).
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
// Pipeline: Execute → WB (negedge complete) → Retire (next cycle).
import rv_dis_pkg::*;
import rob_pkg::*;

module rob_retire (
  input  rob_ptr_t    head_q,
  input  logic        active_spec_q,

  // head entries (probed by parent from ROB view)
  input  logic         valid        [2],
  input  rob_payload_t payload      [2],

  input  logic        retire_en     [2],

  output logic        rrat_en       [2],
  output gpr_addr_t   rd_addr_cmt   [2],
  output prf_addr_t   rob_idx_cmt   [2],

  output logic        rat_en        [2],
  output logic        path_sel      [2],

  output logic        stb_en        [2],

  output rob_ptr_t    head_n,
  output logic        active_spec_n,

  // valid-clear enables + indices (parent applies on negedge into shared bank)
  output logic        cmt           [2],
  output rob_set_t    clr_row       [2],
  output rob_way_t    clr_col       [2]
);

  rob_flat_t h [2];
  logic      on_path [2];
  logic      ready   [2];
  logic      br_ready [2];
  logic      spec_after [2];

  assign h[0] = head_q[ROB_INDEX_W-1:0];
  assign h[1] = rob_flat_t'(h[0] + 1'b1);

  assign clr_row[0] = rob_row(h[0]);
  assign clr_col[0] = rob_col(h[0]);
  assign clr_row[1] = rob_row(h[1]);
  assign clr_col[1] = rob_col(h[1]);

  // ---- eligibility from registered complete (no WB bypass) ----
  assign ready[0] = valid[0] && payload[0].complete;
  assign ready[1] = ready[0] && valid[1] && payload[1].complete;

  assign on_path[0]    = !valid[0] || rob_on_path(payload[0].spec_en, active_spec_q);
  assign br_ready[0]   = ready[0] && on_path[0] && payload[0].is_branch;
  assign spec_after[0] = br_ready[0] ? payload[0].br_taken : active_spec_q;

  assign on_path[1]    = !valid[1] || rob_on_path(payload[1].spec_en, spec_after[0]);
  assign br_ready[1]   = ready[1] && on_path[1] && payload[1].is_branch;
  assign spec_after[1] = br_ready[1] ? payload[1].br_taken : spec_after[0];

  assign cmt[0] = retire_en[0] && ready[0] && on_path[0];
  assign cmt[1] = retire_en[1] && ready[1] && on_path[1];

  // ---- commit buses (payload only valid while committing) ----
  assign rrat_en[0]     = cmt[0] && payload[0].reg_write;
  assign rrat_en[1]     = cmt[1] && payload[1].reg_write;
  assign rd_addr_cmt[0] = cmt[0] ? payload[0].rd : '0;
  assign rd_addr_cmt[1] = cmt[1] ? payload[1].rd : '0;
  assign rob_idx_cmt[0] = rob_to_prf(h[0]);
  assign rob_idx_cmt[1] = rob_to_prf(h[1]);

  assign stb_en[0] = cmt[0] && payload[0].is_store;
  assign stb_en[1] = cmt[1] && payload[1].is_store;

  assign rat_en[0]   = cmt[0] && payload[0].is_branch;
  assign rat_en[1]   = cmt[1] && payload[1].is_branch;
  assign path_sel[0] = cmt[0] ? payload[0].br_taken : 1'b0;
  assign path_sel[1] = cmt[1] ? payload[1].br_taken : 1'b0;

  // ---- next head / speculative path ----
  always_comb begin
    head_n        = head_q;
    active_spec_n = active_spec_q;

    unique case ({cmt[1], cmt[0]})
      2'b11: begin
        active_spec_n = spec_after[1];
        head_n        = head_q + 2'd2;
      end
      2'b01: begin
        active_spec_n = spec_after[0];
        head_n        = head_q + 1'b1;
      end
      default: ;
    endcase
  end

endmodule
