`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;

// Global ROB observation monitor.
module tb_monitor (
  input  prf_addr_t i0_rob_idx,
  input  prf_addr_t i1_rob_idx,
  input  logic      stall,
  input  logic      i0_can_retire,
  input  logic      i1_can_retire,
  input  logic      rrat0_en,
  input  logic      rrat1_en,
  input  gpr_addr_t i0_rd_addr_cmt,
  input  gpr_addr_t i1_rd_addr_cmt,
  input  prf_addr_t i0_rob_idx_cmt,
  input  prf_addr_t i1_rob_idx_cmt,
  input  logic      rat0_en,
  input  logic      rat1_en,
  input  logic      i0_path_sel,
  input  logic      i1_path_sel,
  input  logic      stb0_en,
  input  logic      stb1_en,
  input  logic [5:0] head_q,
  input  logic [5:0] tail_q,
  input  logic [5:0] occ,
  input  logic       active_spec_q
);

  function automatic rob_obs_t sample();
    rob_obs_t o;
    o.i0_rob_idx     = i0_rob_idx;
    o.i1_rob_idx     = i1_rob_idx;
    o.stall          = stall;
    o.i0_can_retire  = i0_can_retire;
    o.i1_can_retire  = i1_can_retire;
    o.rrat0_en       = rrat0_en;
    o.rrat1_en       = rrat1_en;
    o.i0_rd_addr_cmt = i0_rd_addr_cmt;
    o.i1_rd_addr_cmt = i1_rd_addr_cmt;
    o.i0_rob_idx_cmt = i0_rob_idx_cmt;
    o.i1_rob_idx_cmt = i1_rob_idx_cmt;
    o.rat0_en        = rat0_en;
    o.rat1_en        = rat1_en;
    o.i0_path_sel    = i0_path_sel;
    o.i1_path_sel    = i1_path_sel;
    o.stb0_en        = stb0_en;
    o.stb1_en        = stb1_en;
    o.head           = head_q;
    o.tail           = tail_q;
    o.occ            = occ;
    o.active_spec    = active_spec_q;
    return o;
  endfunction

endmodule
