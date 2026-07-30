`timescale 1ns / 1ps

// S4 issue / dispatch glue — four peer cores:
//   p_register_file | reservation_station | bypass_unit | selector_unit
// Bypass and selector are not submodules of the reservation station.
// Directed TBs: bypass_tb, selector_tb, reservation_station_tb
//   (see tb/s4_dispatch/README.md)
import rv_dis_pkg::*;
import rs_pkg::*;

module issue_core_struct (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush_rs,
  input  logic        path_en,
  input  logic        path_sel,

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

  rs_disp_pair_t      disp;
  rs_wb_pair_t        wb;
  rs_pick_t           pick;
  rs_iss_pair_t       iss;
  rs_prf_rd_pair_t    prf;

  rs_entry_t          bank_q [RS_SETS][RS_WAYS];
  logic [NUM_PRF-1:0] prf_ready_q;
  logic [31:0]        age_q;

  logic               byp_ready [2];
  logic [31:0]        byp_age   [2];

  prf_addr_t          ps1_prf [2];
  prf_addr_t          ps2_prf [2];

  always_comb begin
    disp.i0 = '{
      valid: rob_valid_dp[0], lane_sel: lane_sel_dp[0],
      reg_write: (rob_tag_dp[0] != '0), spec_en: path_use_dp[0],
      opcode: opcode_dp[0], funct3: funct3_dp[0], funct7: funct7_dp[0],
      ps1: ps1_tag_dp[0], ps2: ps2_tag_dp[0], prd: rob_tag_dp[0],
      imm: imm_dp[0], pc: pc_dp[0]
    };
    disp.i1 = '{
      valid: rob_valid_dp[1], lane_sel: lane_sel_dp[1],
      reg_write: (rob_tag_dp[1] != '0), spec_en: path_use_dp[1],
      opcode: opcode_dp[1], funct3: funct3_dp[1], funct7: funct7_dp[1],
      ps1: ps1_tag_dp[1], ps2: ps2_tag_dp[1], prd: rob_tag_dp[1],
      imm: imm_dp[1], pc: pc_dp[1]
    };
    wb.wb0 = '{en: wb_en[0], prd: rob_tag_wb[0]};
    wb.wb1 = '{en: wb_en[1], prd: rob_tag_wb[1]};
  end

  assign lane_sel[0] = iss.i0.lane_sel;
  assign opcode[0]   = iss.i0.opcode;
  assign funct3[0]   = iss.i0.funct3;
  assign funct7[0]   = iss.i0.funct7;
  assign rob_tag[0]  = iss.i0.prd;
  assign imm[0]      = iss.i0.imm;
  assign pc[0]       = iss.i0.pc;
  assign ps1_prf[0]  = prf.i0.ps1;
  assign ps2_prf[0]  = prf.i0.ps2;

  assign lane_sel[1] = iss.i1.lane_sel;
  assign opcode[1]   = iss.i1.opcode;
  assign funct3[1]   = iss.i1.funct3;
  assign funct7[1]   = iss.i1.funct7;
  assign rob_tag[1]  = iss.i1.prd;
  assign imm[1]      = iss.i1.imm;
  assign pc[1]       = iss.i1.pc;
  assign ps1_prf[1]  = prf.i1.ps1;
  assign ps2_prf[1]  = prf.i1.ps2;

  reservation_station u_rs (
    .clk, .rst_n, .enable,
    .flush(flush_rs),
    .path_en, .path_sel,
    .stall_dp,
    .disp, .wb, .pick,
    .bank_q, .prf_ready_q, .age_q
  );

  bypass_unit u_bypass (
    .disp,
    .prf_ready(prf_ready_q),
    .wb,
    .age_q,
    .ready(byp_ready),
    .age(byp_age)
  );

  selector_unit u_select (
    .enable,
    .flush(flush_rs),
    .bank_q, .wb, .disp,
    .byp_ready, .byp_age,
    .pick, .stall_dp,
    .prf, .iss
  );

  p_register_file u_prf (
    .clk, .rst_n,
    .rs1_addr(ps1_prf),
    .rs2_addr(ps2_prf),
    .wb_en, .rob_tag_wb, .wb_data,
    .rs1_data, .rs2_data
  );

endmodule
