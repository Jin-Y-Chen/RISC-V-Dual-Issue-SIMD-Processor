`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;

// Global ROB stimulus driver (hold values through DUT negedge sample).
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
module rob_driver (
  output logic        flush,
  output logic        alloc_en      [2],
  output logic        reg_write     [2],
  output logic        is_brnch      [2],
  output logic        is_store      [2],
  output logic        spec_en       [2],
  output logic        state_valid   [2],
  output br_state_t   brch_state    [2],
  output gpr_addr_t   rd_addr       [2],
  output logic        wback_en      [2],
  output prf_addr_t   rob_tag_wb    [2],
  output logic        brch_taken_wb [2],
  output logic        retire_en     [2]
);

  task automatic drive(input rob_stim_t s);
    flush            = s.flush;
    alloc_en[0]      = s.alloc0_en;
    alloc_en[1]      = s.alloc1_en;
    reg_write[0]     = s.i0_reg_write;
    reg_write[1]     = s.i1_reg_write;
    is_brnch[0]      = s.i0_is_brnch;
    is_brnch[1]      = s.i1_is_brnch;
    is_store[0]      = s.i0_is_store;
    is_store[1]      = s.i1_is_store;
    spec_en[0]       = s.i0_spec_en;
    spec_en[1]       = s.i1_spec_en;
    state_valid[0]   = s.i0_state_valid;
    state_valid[1]   = s.i1_state_valid;
    brch_state[0]    = s.i0_brch_state;
    brch_state[1]    = s.i1_brch_state;
    rd_addr[0]       = s.i0_rd_addr;
    rd_addr[1]       = s.i1_rd_addr;
    wback_en[0]      = s.wback0_en;
    wback_en[1]      = s.wback1_en;
    rob_tag_wb[0]    = s.i0_rob_tag_wb;
    rob_tag_wb[1]    = s.i1_rob_tag_wb;
    brch_taken_wb[0] = s.i0_brch_taken_wb;
    brch_taken_wb[1] = s.i1_brch_taken_wb;
    retire_en[0]     = s.retire0_en;
    retire_en[1]     = s.retire1_en;
  endtask

  task automatic clear();
    drive(stim_clear());
  endtask

  initial clear();

endmodule
