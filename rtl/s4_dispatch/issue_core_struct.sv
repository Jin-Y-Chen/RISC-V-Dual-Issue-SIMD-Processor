`timescale 1ns / 1ps

// S4 issue: reservation station + PRF.
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
// RS issues tags/controls; PRF supplies operand data; top-level owns dp_ex.
// rob_tag is the ROB-owned dest tag (same as ROB index).
import rv_dis_pkg::*;

module issue_core_struct (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush_rs,
  input  logic        path_resolve_en,
  input  logic        winning_path_use,

  input  logic        rob_valid_dp  [2],
  input  logic        path_use_dp   [2],
  input  logic        lane_sel_dp   [2],
  input  opcode_t     opcode_dp     [2],
  input  funct3_t     funct3_dp     [2],
  input  funct7_t     funct7_dp     [2],
  input  prf_addr_t   ps1_tag_dp    [2],
  input  prf_addr_t   ps2_tag_dp    [2],
  input  prf_addr_t   rob_tag_dp    [2],
  input  word_t       imm_dp        [2],
  input  word_t       pc_dp         [2],

  input  logic        wb_en         [2],
  input  prf_addr_t   rob_tag_wb    [2],
  input  word_t       wb_data       [2],

  output logic        stall_dp,
  output logic        lane_sel      [2],
  output opcode_t     opcode        [2],
  output funct3_t     funct3        [2],
  output funct7_t     funct7        [2],
  output prf_addr_t   rob_tag       [2],
  output word_t       imm           [2],
  output word_t       pc            [2],
  output word_t       rs1_data      [2],
  output word_t       rs2_data      [2]
);

  prf_addr_t ps1_prf [2];
  prf_addr_t ps2_prf [2];

  reservation_station u_rs (
    .clk, .rst_n, .enable,
    .flush(flush_rs),
    .path_resolve_en, .winning_path_use,
    .rob_valid_dp, .path_use_dp, .lane_sel_dp,
    .opcode_dp, .funct3_dp, .funct7_dp,
    .ps1_tag_dp, .ps2_tag_dp, .rob_tag_dp,
    .imm_dp, .pc_dp,
    .wb_en, .rob_tag_wb,
    .stall_dp,
    .ps1_prf, .ps2_prf,
    .lane_sel,
    .opcode, .funct3, .funct7,
    .rob_tag, .imm, .pc
  );

  p_register_file u_prf (
    .clk, .rst_n,
    .rs1_addr (ps1_prf),
    .rs2_addr (ps2_prf),
    .wb_en, .rob_tag_wb, .wb_data,
    .rs1_data, .rs2_data
  );

endmodule
