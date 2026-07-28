`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;

// Global ROB observation monitor. Dual-issue ports are [2] arrays.
module rob_monitor (
  input  prf_addr_t rob_tag       [2],
  input  logic      stall,
  input  logic      rrat_en       [2],
  input  gpr_addr_t rd_addr_cmt   [2],
  input  prf_addr_t rob_tag_cmt   [2],
  input  logic      rat_en        [2],
  input  logic      path_sel      [2],
  input  logic      stb_en        [2],
  input  logic [5:0] head_q,
  input  logic [5:0] tail_q,
  input  logic [5:0] occ,
  input  logic       active_spec_q
);

  function automatic rob_obs_t sample();
    rob_obs_t o;
    o.i0_rob_tag     = rob_tag[0];
    o.i1_rob_tag     = rob_tag[1];
    o.stall          = stall;
    o.i0_can_retire  = 1'b0;
    o.i1_can_retire  = 1'b0;
    o.rrat0_en       = rrat_en[0];
    o.rrat1_en       = rrat_en[1];
    o.i0_rd_addr_cmt = rd_addr_cmt[0];
    o.i1_rd_addr_cmt = rd_addr_cmt[1];
    o.i0_rob_tag_cmt = rob_tag_cmt[0];
    o.i1_rob_tag_cmt = rob_tag_cmt[1];
    o.rat0_en        = rat_en[0];
    o.rat1_en        = rat_en[1];
    o.i0_path_sel    = path_sel[0];
    o.i1_path_sel    = path_sel[1];
    o.stb0_en        = stb_en[0];
    o.stb1_en        = stb_en[1];
    o.head           = head_q;
    o.tail           = tail_q;
    o.occ            = occ;
    o.active_spec    = active_spec_q;
    return o;
  endfunction

endmodule
