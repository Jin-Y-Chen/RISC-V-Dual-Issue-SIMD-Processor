`timescale 1ns / 1ps

// S4 issue: reservation station + PRF + dp_ex demux.
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
// RS issues tags/controls; PRF supplies operand data; dp_ex buffers data and
// routes the dual issue pair onto ev[2]/od[2] by lane_sel.
// rob_tag is the ROB-owned dest tag (same as ROB index).
import rv_dis_pkg::*;

module issue_core_struct (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall_ex,

  input  logic        rob_valid_dp  [2],
  input  logic        lane_sel_dp   [2],
  input  logic        spec_en_dp    [2],
  input  opcode_t     opcode_dp     [2],
  input  funct3_t     funct3_dp     [2],
  input  funct7_t     funct7_dp     [2],
  input  prf_addr_t   ps1_tag_dp    [2],
  input  prf_addr_t   ps2_tag_dp    [2],
  input  logic        tag1_valid_dp [2],
  input  logic        tag2_valid_dp [2],
  input  prf_addr_t   rob_tag_dp    [2],
  input  word_t       imm_dp        [2],
  input  word_t       pc_dp         [2],

  input  logic        wb_en         [2],
  input  prf_addr_t   rob_tag_wb    [2],
  input  word_t       wb_data       [2],

  output logic        stall_dp,

  output logic        ev_enable_ex    [2],
  output logic        ev_reg_write_ex [2],
  output opcode_t     ev_opcode_ex    [2],
  output funct3_t     ev_funct3_ex    [2],
  output funct7_t     ev_funct7_ex    [2],
  output prf_addr_t   ev_prd_ex       [2],
  output word_t       ev_imm_ex       [2],
  output word_t       ev_pc_ex        [2],
  output word_t       ev_rs1_data_ex  [2],
  output word_t       ev_rs2_data_ex  [2],

  output logic        od_enable_ex    [2],
  output logic        od_reg_write_ex [2],
  output opcode_t     od_opcode_ex    [2],
  output funct3_t     od_funct3_ex    [2],
  output prf_addr_t   od_prd_ex       [2],
  output word_t       od_imm_ex       [2],
  output word_t       od_pc_ex        [2],
  output word_t       od_rs1_data_ex  [2],
  output word_t       od_rs2_data_ex  [2]
);

  prf_addr_t ps1_prf [2];
  prf_addr_t ps2_prf [2];

  logic      rob_valid [2];
  logic      lane_sel  [2];
  opcode_t   opcode    [2];
  funct3_t   funct3    [2];
  funct7_t   funct7    [2];
  prf_addr_t rob_tag   [2];
  word_t     imm       [2];
  word_t     pc        [2];

  word_t     rs1_data [2], rs2_data [2];

  logic issue_en;
  assign issue_en = !stall_ex;

  reservation_station u_rs (
    .clk, .rst_n, .enable, .flush,
    .rob_valid_dp, .lane_sel_dp, .spec_en_dp,
    .opcode_dp, .funct3_dp, .funct7_dp,
    .ps1_tag_dp, .ps2_tag_dp, .tag1_valid_dp, .tag2_valid_dp, .rob_tag_dp,
    .imm_dp, .pc_dp,
    .wb_en, .rob_tag_wb,
    .issue_en,
    .stall_dp,
    .ps1_prf, .ps2_prf,
    .rob_valid, .lane_sel,
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

  dp_ex u_dp_ex (
    .clk, .rst_n, .enable, .flush,
    .stall(stall_ex),
    .rob_valid, .lane_sel,
    .opcode, .funct3, .funct7,
    .rob_tag, .imm, .pc,
    .rs1_data, .rs2_data,
    .ev_enable_ex, .ev_reg_write_ex,
    .ev_opcode_ex, .ev_funct3_ex, .ev_funct7_ex,
    .ev_prd_ex, .ev_imm_ex, .ev_pc_ex,
    .ev_rs1_data_ex, .ev_rs2_data_ex,
    .od_enable_ex, .od_reg_write_ex,
    .od_opcode_ex, .od_funct3_ex,
    .od_prd_ex, .od_imm_ex, .od_pc_ex,
    .od_rs1_data_ex, .od_rs2_data_ex
  );

endmodule
