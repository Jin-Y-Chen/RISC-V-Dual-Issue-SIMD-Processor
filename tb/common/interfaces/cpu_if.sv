`timescale 1ns / 1ps

// Dual-issue fetch / control interface (CPU front-end stimulus + observe).
interface cpu_if (input logic clk, input logic rst_n);
  import rv_dis_pkg::*;

  logic  enable;
  logic  flush;
  logic  dispatch_stall;
  logic  spec0_stall, spec1_stall;
  logic  i0_pred_taken, i1_pred_taken;
  logic  i0_brch_recover, i1_brch_recover;
  word_t i0_pc_execute, i1_pc_execute;

  word_t  pc0, pc1;
  word_t  i0_pc_target, i1_pc_target;
  instr_t instr0, instr1;
  logic   spec0_en, spec1_en;
  logic   i0_valid, i1_valid;
  logic   i0_target_valid, i1_target_valid;
  logic   stall_id;

  modport drv (input clk, rst_n,
               output enable, flush, dispatch_stall, spec0_stall, spec1_stall,
               output i0_pred_taken, i1_pred_taken, i0_brch_recover, i1_brch_recover,
               output i0_pc_execute, i1_pc_execute);
  modport mon (input clk, rst_n, enable, flush,
               input pc0, pc1, instr0, instr1, i0_valid, i1_valid, stall_id);
  modport dut (input  enable, flush, dispatch_stall, spec0_stall, spec1_stall,
               input  i0_pred_taken, i1_pred_taken, i0_brch_recover, i1_brch_recover,
               input  i0_pc_execute, i1_pc_execute,
               output pc0, pc1, i0_pc_target, i1_pc_target, instr0, instr1,
               output spec0_en, spec1_en, i0_valid, i1_valid,
               output i0_target_valid, i1_target_valid, stall_id);
endinterface
