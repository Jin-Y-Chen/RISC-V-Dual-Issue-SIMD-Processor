`timescale 1ns / 1ps

// RS top — single-cycle wakeup-select-issue with dispatch bypass.
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
// Packs shared disp/wb; issue + alloc share pick (bypass vs allocate).
// Negedge bank update (aligned with ROB WB / PRF). No operand storage.
import rv_dis_pkg::*;
import rs_pkg::*;

module reservation_station (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,

  // Dual dispatch (tags + controls)
  input  logic        valid_dp      [2],
  input  logic        lane_sel_dp   [2],
  input  logic        reg_write_dp  [2],
  input  logic        spec_en_dp    [2],   // 0=path0, 1=path1
  input  opcode_t     opcode_dp     [2],
  input  funct3_t     funct3_dp     [2],
  input  funct7_t     funct7_dp     [2],
  input  prf_addr_t   ps1_dp        [2],
  input  prf_addr_t   ps2_dp        [2],
  input  logic        tag1_valid_dp [2],
  input  logic        tag2_valid_dp [2],
  input  prf_addr_t   prd_dp        [2],
  input  word_t       imm_dp        [2],
  input  word_t       pc_dp         [2],

  // Dual writeback tags
  input  logic        wb_en         [2],
  input  prf_addr_t   wb_prd        [2],

  input  logic        issue_en,        // downstream accept (EX / dp_ex)
  output logic        stall_dp,

  // Dual issue → PRF read ports
  output logic        rs1_use_prf   [2],
  output logic        rs2_use_prf   [2],
  output prf_addr_t   ps1_prf       [2],
  output prf_addr_t   ps2_prf       [2],

  // Dual issue → dp_ex
  output logic        valid_iss     [2],
  output logic        lane_sel_iss  [2],
  output logic        reg_write_iss [2],
  output opcode_t     opcode_iss    [2],
  output funct3_t     funct3_iss    [2],
  output funct7_t     funct7_iss    [2],
  output prf_addr_t   ps1_iss       [2],
  output prf_addr_t   ps2_iss       [2],
  output prf_addr_t   prd_iss       [2],
  output word_t       imm_iss       [2],
  output word_t       pc_iss        [2]
);

  rs_entry_t          bank_q [RS_SETS][RS_WAYS], bank_n [RS_SETS][RS_WAYS];
  logic [NUM_PRF-1:0] prf_ready_q, prf_ready_n;
  logic [31:0]        age_q, age_n;

  rs_disp_pair_t   disp;
  rs_wb_pair_t     wb;
  rs_pick_t        pick;
  rs_iss_pair_t    iss;
  rs_prf_rd_pair_t prf;

  // Shared bundles for issue + alloc (single pack site).
  always_comb begin
    disp.i0 = '{
      valid: valid_dp[0], lane_sel: lane_sel_dp[0],
      reg_write: reg_write_dp[0], spec_en: spec_en_dp[0],
      tag1_valid: tag1_valid_dp[0], tag2_valid: tag2_valid_dp[0],
      opcode: opcode_dp[0], funct3: funct3_dp[0], funct7: funct7_dp[0],
      ps1: ps1_dp[0], ps2: ps2_dp[0], prd: prd_dp[0],
      imm: imm_dp[0], pc: pc_dp[0]
    };
    disp.i1 = '{
      valid: valid_dp[1], lane_sel: lane_sel_dp[1],
      reg_write: reg_write_dp[1], spec_en: spec_en_dp[1],
      tag1_valid: tag1_valid_dp[1], tag2_valid: tag2_valid_dp[1],
      opcode: opcode_dp[1], funct3: funct3_dp[1], funct7: funct7_dp[1],
      ps1: ps1_dp[1], ps2: ps2_dp[1], prd: prd_dp[1],
      imm: imm_dp[1], pc: pc_dp[1]
    };
    wb.wb0 = '{en: wb_en[0], prd: wb_prd[0]};
    wb.wb1 = '{en: wb_en[1], prd: wb_prd[1]};
  end

  // Unpack issue / PRF to [2] ports.
  assign valid_iss[0]     = iss.i0.valid;
  assign lane_sel_iss[0]  = iss.i0.lane_sel;
  assign reg_write_iss[0] = iss.i0.reg_write;
  assign opcode_iss[0]    = iss.i0.opcode;
  assign funct3_iss[0]    = iss.i0.funct3;
  assign funct7_iss[0]    = iss.i0.funct7;
  assign ps1_iss[0]       = iss.i0.ps1;
  assign ps2_iss[0]       = iss.i0.ps2;
  assign prd_iss[0]       = iss.i0.prd;
  assign imm_iss[0]       = iss.i0.imm;
  assign pc_iss[0]        = iss.i0.pc;
  assign ps1_prf[0]       = prf.i0.ps1;
  assign ps2_prf[0]       = prf.i0.ps2;
  assign rs1_use_prf[0]   = prf.i0.rs1_use;
  assign rs2_use_prf[0]   = prf.i0.rs2_use;

  assign valid_iss[1]     = iss.i1.valid;
  assign lane_sel_iss[1]  = iss.i1.lane_sel;
  assign reg_write_iss[1] = iss.i1.reg_write;
  assign opcode_iss[1]    = iss.i1.opcode;
  assign funct3_iss[1]    = iss.i1.funct3;
  assign funct7_iss[1]    = iss.i1.funct7;
  assign ps1_iss[1]       = iss.i1.ps1;
  assign ps2_iss[1]       = iss.i1.ps2;
  assign prd_iss[1]       = iss.i1.prd;
  assign imm_iss[1]       = iss.i1.imm;
  assign pc_iss[1]        = iss.i1.pc;
  assign ps1_prf[1]       = prf.i1.ps1;
  assign ps2_prf[1]       = prf.i1.ps2;
  assign rs1_use_prf[1]   = prf.i1.rs1_use;
  assign rs2_use_prf[1]   = prf.i1.rs2_use;

  rs_issue u_issue (
    .enable, .flush,
    .bank_q,
    .prf_ready_q,
    .age_q,
    .wb,
    .disp,
    .issue_en,
    .pick,
    .stall_dp,
    .prf,
    .iss
  );

  rs_alloc u_alloc (
    .enable, .flush, .stall_dp,
    .bank_q, .prf_ready_q, .age_q,
    .wb,
    .pick,
    .disp,
    .bank_n, .prf_ready_n, .age_n
  );

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      bank_q      <= '{default: '0};
      prf_ready_q <= '1;
      age_q       <= '0;
    end else begin
      bank_q      <= bank_n;
      prf_ready_q <= prf_ready_n;
      age_q       <= age_n;
    end
  end

endmodule
