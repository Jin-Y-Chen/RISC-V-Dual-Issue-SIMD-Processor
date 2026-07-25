`timescale 1ns / 1ps

// ROB retire unit — head side (structurally parallel with rob_alloc).
// Pure combinational: eligibility / commit buses / head_n / cmt*.
// Parent owns the ROB bank; passes head valid/payload only (no rob_q port).
// Pipeline: Execute → WB (negedge complete) → Retire (next cycle).
import rv_dis_pkg::*;
import rob_pkg::*;

module rob_retire (
  input  rob_ptr_t    head_q,
  input  logic        active_spec_q,

  // head entries (probed by parent from ROB view)
  input  logic        v0,
  input  logic        v1,
  input  rob_payload_t p0,
  input  rob_payload_t p1,

  input  logic        retire0_en,
  input  logic        retire1_en,

  output logic        i0_can_retire,
  output logic        i1_can_retire,

  output logic        rrat0_en,
  output logic        rrat1_en,
  output gpr_addr_t   i0_rd_addr_cmt,
  output gpr_addr_t   i1_rd_addr_cmt,
  output prf_addr_t   i0_rob_idx_cmt,
  output prf_addr_t   i1_rob_idx_cmt,

  output logic        rat0_en,
  output logic        rat1_en,
  output logic        i0_path_sel,
  output logic        i1_path_sel,

  output logic        stb0_en,
  output logic        stb1_en,

  output rob_ptr_t    head_n,
  output logic        active_spec_n,

  // valid-clear enables + indices (parent applies on negedge into shared bank)
  output logic        cmt0,
  output logic        cmt1,
  output rob_set_t    clr0_row,
  output rob_set_t    clr1_row,
  output rob_way_t    clr0_col,
  output rob_way_t    clr1_col
);

  rob_flat_t h0, h1;
  logic      on_path0, on_path1;
  logic      ready0, ready1;
  logic      br0_ready, br1_ready;
  logic      spec_after0, spec_after1;

  assign h0 = head_q[ROB_INDEX_W-1:0];
  assign h1 = rob_flat_t'(h0 + 1'b1);

  assign clr0_row = rob_row(h0);
  assign clr0_col = rob_col(h0);
  assign clr1_row = rob_row(h1);
  assign clr1_col = rob_col(h1);

  // ---- eligibility from registered complete (no WB bypass) ----
  assign ready0 = v0 && p0.complete;
  assign ready1 = ready0 && v1 && p1.complete;

  assign on_path0    = !v0 || rob_on_path(p0.spec_en, active_spec_q);
  assign br0_ready   = ready0 && on_path0 && p0.is_branch;
  assign spec_after0 = br0_ready ? p0.br_taken : active_spec_q;

  assign on_path1    = !v1 || rob_on_path(p1.spec_en, spec_after0);
  assign br1_ready   = ready1 && on_path1 && p1.is_branch;
  assign spec_after1 = br1_ready ? p1.br_taken : spec_after0;

  assign i0_can_retire = ready0;
  assign i1_can_retire = ready1;

  assign cmt0 = retire0_en && ready0 && on_path0;
  assign cmt1 = retire1_en && ready1 && on_path1;

  // ---- commit buses (payload only valid while committing) ----
  assign rrat0_en       = cmt0 && p0.reg_write;
  assign rrat1_en       = cmt1 && p1.reg_write;
  assign i0_rd_addr_cmt = cmt0 ? p0.rd : '0;
  assign i1_rd_addr_cmt = cmt1 ? p1.rd : '0;
  assign i0_rob_idx_cmt = rob_to_prf(h0);
  assign i1_rob_idx_cmt = rob_to_prf(h1);

  assign stb0_en = cmt0 && p0.is_store;
  assign stb1_en = cmt1 && p1.is_store;

  assign rat0_en     = cmt0 && p0.is_branch;
  assign rat1_en     = cmt1 && p1.is_branch;
  assign i0_path_sel = cmt0 ? p0.br_taken : 1'b0;
  assign i1_path_sel = cmt1 ? p1.br_taken : 1'b0;

  // ---- next head / speculative path ----
  always_comb begin
    head_n        = head_q;
    active_spec_n = active_spec_q;

    unique case ({cmt1, cmt0})
      2'b11: begin
        active_spec_n = spec_after1;
        head_n        = head_q + 2'd2;
      end
      2'b01: begin
        active_spec_n = spec_after0;
        head_n        = head_q + 1'b1;
      end
      default: ;
    endcase
  end

endmodule
