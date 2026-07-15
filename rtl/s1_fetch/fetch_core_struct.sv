`timescale 1ns / 1ps

// S1 fetch structure — PC + instruction cache + branch target buffer (dual-issue pair).
// Speculation: registered branch_map loops through pc <-> pc_selector.
// Nested-speculation freeze comes from decode target_predict (spec*_stall).
import rv_dis_pkg::*;

module s1_fetch_struct #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls
  input  logic        dispatch_stall,
  input  logic        spec0_stall,
  input  logic        spec1_stall,
  input  logic        i0_pred_taken,
  input  logic        i1_pred_taken,
  input  logic        i0_brch_recover,
  input  logic        i1_brch_recover,
  input  logic        i0_valid_wb,
  input  logic        i1_valid_wb,

  // input data
  input  word_t         i0_pc_execute,
  input  word_t         i1_pc_execute,
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
  output instr_t        instr1,

  // output controls
  output br_map_t       branch_map,
  output logic          i0_valid,
  output logic          i1_valid
);

  br_map_t branch_map_q;
  br_map_t branch_map_next;
  word_t   pc0_next;
  word_t   pc1_next;

  assign branch_map = branch_map_next;

  pc #(
    .RESET_PC(RESET_PC)
  ) u_pc (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    .dispatch_stall  (dispatch_stall),
    .spec0_stall     (spec0_stall),
    .spec1_stall     (spec1_stall),
    .branch_map_in   (branch_map_next),
    .pc0_in          (pc0_next),
    .pc1_in          (pc1_next),
    .pc0_out         (pc0),
    .pc1_out         (pc1),
    .branch_map_out  (branch_map_q)
  );

  instruction_cache u_icache (
    .clk    (clk),
    .rst_n  (rst_n),
    .pc0    (pc0),
    .pc1    (pc1),
    .instr0 (instr0),
    .instr1 (instr1)
  );

  target_buffer u_target (
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
    .i0_valid        (i0_valid),
    .i1_valid        (i1_valid),
    .i0_pc_target    (i0_pc_target),
    .i1_pc_target    (i1_pc_target)
  );

  pc_selector u_pc_sel (
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
