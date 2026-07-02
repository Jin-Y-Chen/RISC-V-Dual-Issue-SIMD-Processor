`timescale 1ns / 1ps

// Branch speculation — tracks unresolved branches and selects NEW vs SPEC_NEW on allocate.
module branch_speculate
  import rv_dis_pkg::*;
  import rob_pkg::*;
  import rob_branch_pkg::*;

(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,

  // Decode-side branch detect (allocate)
  input  logic        add_en,
  input  logic        i0_valid,
  input  opcode_t     i0_opcode,
  input  logic        i1_valid,
  input  opcode_t     i1_opcode,

  // Commit-side branch detect (retire)
  input  logic        clear_en,
  input  logic [1:0]  clear_count,
  input  opcode_t     cmt0_opcode,
  input  opcode_t     cmt1_opcode,

  output logic        spec_i0,
  output logic        spec_i1,
  output rob_ptr_t    br_inflight
);

  rob_ptr_t br_inflight_q;

  wire i0_is_br = rob_is_branch(i0_opcode);
  wire i1_is_br = rob_is_branch(i1_opcode);
  wire cmt0_is_br = rob_is_branch(cmt0_opcode);
  wire cmt1_is_br = rob_is_branch(cmt1_opcode);

  wire rob_ptr_t alloc_branches = rob_alloc_branches(
    add_en, i0_valid, i0_is_br, i1_valid, i1_is_br
  );
  wire rob_ptr_t cmt_branches = rob_commit_branches(
    clear_en, clear_count, cmt0_is_br, cmt1_is_br
  );

  assign spec_i0     = rob_spec_i0(br_inflight_q);
  assign spec_i1     = rob_spec_i1(br_inflight_q, i0_valid, i0_is_br);
  assign br_inflight = br_inflight_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush)
      br_inflight_q <= '0;
    else if (enable)
      br_inflight_q <= br_inflight_q + alloc_branches - cmt_branches;
  end

endmodule
