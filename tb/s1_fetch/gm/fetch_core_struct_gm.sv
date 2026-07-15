`timescale 1ns / 1ps

import rv_dis_pkg::*;

// Golden model for rtl/s1_fetch/fetch_core_struct.sv
// Composes pc_gm + pc_selector_gm + instruction_cache_gm + target_buffer_gm.

module fetch_core_struct_gm #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  input  logic  clk,
  input  logic  rst_n,
  input  logic  enable,
  input  logic  dispatch_stall,
  input  logic  spec0_stall,
  input  logic  spec1_stall,
  input  logic  i0_pred_taken,
  input  logic  i1_pred_taken,
  input  logic  i0_brch_recover,
  input  logic  i1_brch_recover,
  input  word_t i0_pc_execute,
  input  word_t i1_pc_execute,
  input  logic  i0_valid_wb,
  input  logic  i1_valid_wb,
  input  word_t i0_pc_wb,
  input  word_t i1_pc_wb,
  input  word_t i0_pc_target_wb,
  input  word_t i1_pc_target_wb,
  output word_t pc0,
  output word_t pc1,
  output word_t i0_pc_target,
  output word_t i1_pc_target,
  output instr_t instr0,
  output instr_t instr1,
  output br_map_t branch_map
);

  br_map_t branch_map_q;
  br_map_t branch_map_next;
  logic    i0_btb_valid;
  logic    i1_btb_valid;
  word_t   pc0_next;
  word_t   pc1_next;

  assign branch_map = branch_map_next;

  pc_gm #(
    .RESET_PC(RESET_PC)
  ) u_pc_gm (
    .clk            (clk),
    .rst_n          (rst_n),
    .enable         (enable),
    .dispatch_stall (dispatch_stall),
    .spec0_stall    (spec0_stall),
    .spec1_stall    (spec1_stall),
    .branch_map_in  (branch_map_next),
    .pc0_in         (pc0_next),
    .pc1_in         (pc1_next),
    .pc0_out        (pc0),
    .pc1_out        (pc1),
    .branch_map_out (branch_map_q)
  );

  instruction_cache_gm u_icache_gm (
    .pc0    (pc0),
    .pc1    (pc1),
    .instr0 (instr0),
    .instr1 (instr1)
  );

  target_buffer_gm u_target_gm (
    .clk             (clk),
    .rst_n           (rst_n),
    .i0_pc           (pc0),
    .i1_pc           (pc1),
    .i0_valid_wb     (i0_valid_wb),
    .i1_valid_wb     (i1_valid_wb),
    .i0_pc_wb        (i0_pc_wb),
    .i1_pc_wb        (i1_pc_wb),
    .i0_pc_target_wb (i0_pc_target_wb),
    .i1_pc_target_wb (i1_pc_target_wb),
    .i0_valid        (i0_btb_valid),
    .i1_valid        (i1_btb_valid),
    .i0_pc_target    (i0_pc_target),
    .i1_pc_target    (i1_pc_target)
  );

  pc_selector_gm u_pc_sel_gm (
    .branch_map_in   (branch_map_q),
    .i0_pred_taken   (i0_pred_taken),
    .i1_pred_taken   (i1_pred_taken),
    .i0_brch_recover (i0_brch_recover),
    .i1_brch_recover (i1_brch_recover),
    .pc0_in          (pc0),
    .pc1_in          (pc1),
    .i0_pc_target    (i0_pc_target),
    .i1_pc_target    (i1_pc_target),
    .i0_pc_execute   (i0_pc_execute),
    .i1_pc_execute   (i1_pc_execute),
    .branch_map_out  (branch_map_next),
    .pc0_out         (pc0_next),
    .pc1_out         (pc1_next)
  );

endmodule
