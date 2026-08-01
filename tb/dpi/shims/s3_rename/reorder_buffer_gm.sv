`timescale 1ns / 1ps

// DPI shim - model/s3_rename/rob_gm.cpp
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
import rv_dis_pkg::*;
import rob_pkg::*;
import dpi_pkg::*;
import tb_pkg::*;

module reorder_buffer_gm (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        alloc_en      [2],
  input  logic        reg_write     [2],
  input  logic        is_brnch      [2],
  input  logic        is_store      [2],
  input  logic        spec_en       [2],
  input  logic        state_valid   [2],
  input  br_state_t   brch_state    [2],
  input  gpr_addr_t   rd_addr       [2],
  output prf_addr_t   rob_tag       [2],
  output logic        stall,
  input  logic        wback_en      [2],
  input  prf_addr_t   rob_tag_wb    [2],
  input  logic        brch_taken_wb [2],
  input  logic        retire_en     [2],
  output logic        can_retire    [2],
  output logic        rrat_en       [2],
  output gpr_addr_t   rd_addr_cmt   [2],
  output prf_addr_t   rob_tag_cmt   [2],
  output logic        rat_en        [2],
  output logic        path_sel      [2],
  output logic        stb_en        [2]
);

  chandle h;
  rob_stim_t s;
  rob_obs_t  o;

  initial begin
    h = rob_dpi_create();
    if (h == null) $fatal(1, "rob_dpi_create failed");
  end
  final rob_dpi_destroy(h);

  always @(*) begin
    s = stim_clear();
    s.flush            = flush;
    s.alloc0_en        = alloc_en[0];
    s.alloc1_en        = alloc_en[1];
    s.i0_reg_write     = reg_write[0];
    s.i1_reg_write     = reg_write[1];
    s.i0_is_brnch      = is_brnch[0];
    s.i1_is_brnch      = is_brnch[1];
    s.i0_is_store      = is_store[0];
    s.i1_is_store      = is_store[1];
    s.i0_spec_en       = spec_en[0];
    s.i1_spec_en       = spec_en[1];
    s.i0_state_valid   = state_valid[0];
    s.i1_state_valid   = state_valid[1];
    s.i0_brch_state    = brch_state[0];
    s.i1_brch_state    = brch_state[1];
    s.i0_rd_addr       = rd_addr[0];
    s.i1_rd_addr       = rd_addr[1];
    s.wback0_en        = wback_en[0];
    s.wback1_en        = wback_en[1];
    s.i0_rob_tag_wb    = rob_tag_wb[0];
    s.i1_rob_tag_wb    = rob_tag_wb[1];
    s.i0_brch_taken_wb = brch_taken_wb[0];
    s.i1_brch_taken_wb = brch_taken_wb[1];
    s.retire0_en       = retire_en[0];
    s.retire1_en       = retire_en[1];
    o = rob_gm_eval(h, s);
    rob_tag[0]     = o.i0_rob_tag;
    rob_tag[1]     = o.i1_rob_tag;
    stall          = o.stall;
    can_retire[0]  = o.i0_can_retire;
    can_retire[1]  = o.i1_can_retire;
    rrat_en[0]     = o.rrat0_en;
    rrat_en[1]     = o.rrat1_en;
    rd_addr_cmt[0] = o.i0_rd_addr_cmt;
    rd_addr_cmt[1] = o.i1_rd_addr_cmt;
    rob_tag_cmt[0] = o.i0_rob_tag_cmt;
    rob_tag_cmt[1] = o.i1_rob_tag_cmt;
    rat_en[0]      = o.rat0_en;
    rat_en[1]      = o.rat1_en;
    path_sel[0]    = o.i0_path_sel;
    path_sel[1]    = o.i1_path_sel;
    stb_en[0]      = o.stb0_en;
    stb_en[1]      = o.stb1_en;
  end

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
      rob_dpi_reset(h);
    else
      rob_gm_commit(h, s);
  end

endmodule
