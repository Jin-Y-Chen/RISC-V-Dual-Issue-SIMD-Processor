`timescale 1ns / 1ps

// ROB / rename commit interface (RRAT, STB, branch path).
interface commit_if (input logic clk, input logic rst_n);
  import rv_dis_pkg::*;

  logic      rrat0_en, rrat1_en;
  logic      stb0_en, stb1_en;
  logic      rat0_en, rat1_en;
  logic      i0_path_sel, i1_path_sel;
  gpr_addr_t i0_rd_addr_cmt, i1_rd_addr_cmt;
  prf_addr_t i0_rob_tag_cmt, i1_rob_tag_cmt;
  logic      i0_can_retire, i1_can_retire;
  logic      retire0_en, retire1_en;

  modport mon (input clk, rst_n,
               input rrat0_en, rrat1_en, stb0_en, stb1_en, rat0_en, rat1_en,
               input i0_path_sel, i1_path_sel,
               input i0_rd_addr_cmt, i1_rd_addr_cmt,
               input i0_rob_tag_cmt, i1_rob_tag_cmt,
               input i0_can_retire, i1_can_retire);
  modport drv (input clk, rst_n, i0_can_retire, i1_can_retire,
               output retire0_en, retire1_en);
endinterface
