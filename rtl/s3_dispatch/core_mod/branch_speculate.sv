`timescale 1ns / 1ps

import rv_dis_pkg::*;
import rob_pkg::*;
import rob_branch_pkg::*;

// Branch speculation — purely combinational NEW vs SPEC_NEW and br_inflight next.
// Parent holds br_inflight (registered); no clk/rst_n/enable/flush on this block.
module branch_speculate (
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

  // Registered inflight count from parent
  input  rob_ptr_t    br_inflight,

  output logic        spec_i0,
  output logic        spec_i1,
  output rob_ptr_t    br_inflight_next
);

  wire i0_is_br   = rob_is_branch(i0_opcode);
  wire i1_is_br   = rob_is_branch(i1_opcode);
  wire cmt0_is_br = rob_is_branch(cmt0_opcode);
  wire cmt1_is_br = rob_is_branch(cmt1_opcode);

  wire rob_ptr_t alloc_branches = rob_alloc_branches(
    add_en, i0_valid, i0_is_br, i1_valid, i1_is_br
  );
  wire rob_ptr_t cmt_branches = rob_commit_branches(
    clear_en, clear_count, cmt0_is_br, cmt1_is_br
  );

  assign spec_i0          = rob_spec_i0(br_inflight);
  assign spec_i1          = rob_spec_i1(br_inflight, i0_valid, i0_is_br);
  assign br_inflight_next = br_inflight + alloc_branches - cmt_branches;

endmodule
