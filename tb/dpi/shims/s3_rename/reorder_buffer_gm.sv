`timescale 1ns / 1ps

// DPI shim — model/s3_rename/rob_gm.cpp (same C++ as rob_tb).
// Keeps reorder_buffer_tb pin-compatible with the old SV LUT GM.
import rv_dis_pkg::*;
import rob_pkg::*;
import dpi_pkg::*;
import tb_pkg::*;

module reorder_buffer_gm (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
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
  output logic        stall,
  input  logic        wback0_en,
  input  logic        wback1_en,
  input  prf_addr_t   i0_rob_idx_wb,
  input  prf_addr_t   i1_rob_idx_wb,
  input  logic        i0_brch_taken_wb,
  input  logic        i1_brch_taken_wb,
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
  output logic        stb1_en
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
    s.alloc0_en        = alloc0_en;
    s.alloc1_en        = alloc1_en;
    s.i0_reg_write     = i0_reg_write;
    s.i1_reg_write     = i1_reg_write;
    s.i0_is_brnch      = i0_is_brnch;
    s.i1_is_brnch      = i1_is_brnch;
    s.i0_is_store      = i0_is_store;
    s.i1_is_store      = i1_is_store;
    s.i0_spec_en       = i0_spec_en;
    s.i1_spec_en       = i1_spec_en;
    s.i0_rd_addr       = i0_rd_addr;
    s.i1_rd_addr       = i1_rd_addr;
    s.wback0_en        = wback0_en;
    s.wback1_en        = wback1_en;
    s.i0_rob_idx_wb    = i0_rob_idx_wb;
    s.i1_rob_idx_wb    = i1_rob_idx_wb;
    s.i0_brch_taken_wb = i0_brch_taken_wb;
    s.i1_brch_taken_wb = i1_brch_taken_wb;
    s.retire0_en       = retire0_en;
    s.retire1_en       = retire1_en;
    o = rob_gm_eval(h, s);
    i0_rob_idx     = o.i0_rob_idx;
    i1_rob_idx     = o.i1_rob_idx;
    stall          = o.stall;
    i0_can_retire  = o.i0_can_retire;
    i1_can_retire  = o.i1_can_retire;
    rrat0_en       = o.rrat0_en;
    rrat1_en       = o.rrat1_en;
    i0_rd_addr_cmt = o.i0_rd_addr_cmt;
    i1_rd_addr_cmt = o.i1_rd_addr_cmt;
    i0_rob_idx_cmt = o.i0_rob_idx_cmt;
    i1_rob_idx_cmt = o.i1_rob_idx_cmt;
    rat0_en        = o.rat0_en;
    rat1_en        = o.rat1_en;
    i0_path_sel    = o.i0_path_sel;
    i1_path_sel    = o.i1_path_sel;
    stb0_en        = o.stb0_en;
    stb1_en        = o.stb1_en;
  end

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
      rob_dpi_reset(h);
    else
      rob_gm_commit(h, s);
  end

endmodule
