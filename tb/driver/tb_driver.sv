`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;

// Global ROB stimulus driver (hold values through DUT negedge sample).
module tb_driver (
  output logic        flush,
  output logic        alloc0_en,
  output logic        alloc1_en,
  output logic        i0_reg_write,
  output logic        i1_reg_write,
  output logic        i0_is_brnch,
  output logic        i1_is_brnch,
  output logic        i0_is_store,
  output logic        i1_is_store,
  output logic        i0_spec_en,
  output logic        i1_spec_en,
  output gpr_addr_t   i0_rd_addr,
  output gpr_addr_t   i1_rd_addr,
  output logic        wback0_en,
  output logic        wback1_en,
  output prf_addr_t   i0_rob_idx_wb,
  output prf_addr_t   i1_rob_idx_wb,
  output logic        i0_brch_taken_wb,
  output logic        i1_brch_taken_wb,
  output logic        retire0_en,
  output logic        retire1_en
);

  task automatic drive(input rob_stim_t s);
    flush            = s.flush;
    alloc0_en        = s.alloc0_en;
    alloc1_en        = s.alloc1_en;
    i0_reg_write     = s.i0_reg_write;
    i1_reg_write     = s.i1_reg_write;
    i0_is_brnch      = s.i0_is_brnch;
    i1_is_brnch      = s.i1_is_brnch;
    i0_is_store      = s.i0_is_store;
    i1_is_store      = s.i1_is_store;
    i0_spec_en       = s.i0_spec_en;
    i1_spec_en       = s.i1_spec_en;
    i0_rd_addr       = s.i0_rd_addr;
    i1_rd_addr       = s.i1_rd_addr;
    wback0_en        = s.wback0_en;
    wback1_en        = s.wback1_en;
    i0_rob_idx_wb    = s.i0_rob_idx_wb;
    i1_rob_idx_wb    = s.i1_rob_idx_wb;
    i0_brch_taken_wb = s.i0_brch_taken_wb;
    i1_brch_taken_wb = s.i1_brch_taken_wb;
    retire0_en       = s.retire0_en;
    retire1_en       = s.retire1_en;
  endtask

  task automatic clear();
    drive(stim_clear());
  endtask

  initial clear();

endmodule
