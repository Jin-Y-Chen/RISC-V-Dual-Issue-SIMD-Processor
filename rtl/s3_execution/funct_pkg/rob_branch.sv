`timescale 1ns / 1ps

// Branch speculation bookkeeping for the ROB.
package rob_branch_pkg;

  import rv_dis_pkg::*;
  import rob_pkg::*;

function automatic logic rob_is_branch(input opcode_t opcode);
  return (opcode == OPC_BRANCH);
endfunction

function automatic logic rob_spec_i0(input rob_ptr_t br_inflight);
  return (br_inflight != 0);
endfunction

function automatic logic rob_spec_i1(
  input rob_ptr_t br_inflight,
  input logic     i0_valid,
  input logic     i0_is_br
);
  return (br_inflight != 0) || (i0_valid && i0_is_br);
endfunction

function automatic rob_ptr_t rob_alloc_branches(
  input logic alloc_ok,
  input logic i0_valid,
  input logic i0_is_br,
  input logic i1_valid,
  input logic i1_is_br
);
  if (!alloc_ok)
    return '0;
  return {{ROB_AW{1'b0}}, (i0_valid && i0_is_br)} +
         {{ROB_AW{1'b0}}, (i1_valid && i1_is_br)};
endfunction

function automatic rob_ptr_t rob_commit_branches(
  input logic       commit_en,
  input logic [1:0] commit_count,
  input logic       cmt0_is_br,
  input logic       cmt1_is_br
);
  logic cmt0_br;
  logic cmt1_br;
  cmt0_br = commit_en && (commit_count >= 2'd1) && cmt0_is_br;
  cmt1_br = commit_en && (commit_count >= 2'd2) && cmt1_is_br;
  return {{ROB_AW{1'b0}}, cmt0_br} + {{ROB_AW{1'b0}}, cmt1_br};
endfunction

endpackage
