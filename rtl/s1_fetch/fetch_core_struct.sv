`timescale 1ns / 1ps

import rv_dis_pkg::*;

// S1 fetch structure — PC + instruction cache + branch target buffer (dual-issue pair).
module s1_fetch_struct #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  // internal controls
  input  logic        dispatch_stall,
  input  logic        i0_pred_taken,
  input  logic        i1_pred_taken,
  input  logic        i0_brch_recover,
  input  logic        i1_brch_recover,

  // input data
  input  word_t         i0_pc_execute,
  input  word_t         i1_pc_execute,
  input  logic          i0_valid_wb,
  input  logic          i1_valid_wb,
  input  word_t         i0_pc_wb,
  input  word_t         i1_pc_wb,
  input  word_t         i0_pc_target_wb,
  input  word_t         i1_pc_target_wb,

  // output data
  output word_t         pc0,
  output word_t         pc1,
  output word_t         i0_pc_target,
  output word_t         i1_pc_target,
  output instr_t        instr0,
  output instr_t        instr1
);

  logic  is_spec;
  logic  fetch_stall;
  logic  mode;
  logic  spec0_en;
  word_t pc0_next;
  word_t pc1_next;

  pc #(
    .RESET_PC(RESET_PC)
  ) u_pc (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    .fetch_stall     (fetch_stall),
    .dispatch_stall  (dispatch_stall),
    .mode            (mode),
    .spec0_en        (spec0_en),
    .pc0_in          (pc0_next),
    .pc1_in          (pc1_next),
    .is_spec         (is_spec),
    .pc0_out         (pc0),
    .pc1_out         (pc1)
  );

  instruction_cache u_icache (
    .pc0    (pc0),
    .pc1    (pc1),
    .instr0 (instr0),
    .instr1 (instr1)
  );

  target_buffer u_target (
    .i0_pc           (pc0),
    .i1_pc           (pc1),
    .i0_valid_wb     (i0_valid_wb),
    .i1_valid_wb     (i1_valid_wb),
    .i0_pc_wb        (i0_pc_wb),
    .i1_pc_wb        (i1_pc_wb),
    .i0_pc_target_wb (i0_pc_target_wb),
    .i1_pc_target_wb (i1_pc_target_wb),
    .i0_pc_target    (i0_pc_target),
    .i1_pc_target    (i1_pc_target)
  );

  pc_selector u_pc_sel (
    .is_spec         (is_spec),
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
    .stall           (fetch_stall),
    .mode            (mode),
    .spec0_en        (spec0_en),
    .pc0_out         (pc0_next),
    .pc1_out         (pc1_next)
  );

endmodule
