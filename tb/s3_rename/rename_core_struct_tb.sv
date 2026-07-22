`timescale 1ns / 1ps

// Smoke: rename_core_struct (RAT + ROB-owned PRF p32..p63).
import rv_dis_pkg::*;
import rob_pkg::*;

module rename_core_struct_tb;
  logic        clk, rst_n, flush, stall_rn, enable;
  logic        spec0_en_rn, spec1_en_rn;
  logic        i0_lane_sel_rn, i1_lane_sel_rn;
  logic        i0_valid_rn, i1_valid_rn;
  logic        i0_reg_write_rn, i1_reg_write_rn;
  logic        i0_store_en_rn, i1_store_en_rn;
  logic        i0_rs1_use_rn, i0_rs2_use_rn, i1_rs1_use_rn, i1_rs2_use_rn;
  opcode_t     i0_opcode_rn, i1_opcode_rn;
  funct3_t     i0_funct3_rn, i1_funct3_rn;
  funct7_t     i0_funct7_rn, i1_funct7_rn;
  gpr_addr_t   i0_rd_addr_rn, i0_rs1_addr_rn, i0_rs2_addr_rn;
  gpr_addr_t   i1_rd_addr_rn, i1_rs1_addr_rn, i1_rs2_addr_rn;
  word_t       i0_imm_rn, i0_pc_rn, i1_imm_rn, i1_pc_rn;
  logic        wback0_en, wback1_en;
  prf_addr_t   i0_rob_idx_wb, i1_rob_idx_wb;
  logic        i0_brch_taken_wb, i1_brch_taken_wb;
  logic        resolve_en, resolve_mispred;
  logic        stall_id;

  logic        i0_valid_disp, i1_valid_disp;
  logic        i0_lane_sel_disp, i1_lane_sel_disp;
  logic        i0_reg_write_disp, i1_reg_write_disp;
  logic        i0_rs1_use_disp, i0_rs2_use_disp;
  logic        i1_rs1_use_disp, i1_rs2_use_disp;
  opcode_t     i0_opcode_disp, i1_opcode_disp;
  funct3_t     i0_funct3_disp, i1_funct3_disp;
  funct7_t     i0_funct7_disp, i1_funct7_disp;
  gpr_addr_t   i0_rd_addr_disp, i1_rd_addr_disp;
  prf_addr_t   i0_ps1_disp, i0_ps2_disp, i0_prd_disp;
  prf_addr_t   i1_ps1_disp, i1_ps2_disp, i1_prd_disp;
  prf_addr_t   i0_rob_idx_disp, i1_rob_idx_disp;
  word_t       i0_imm_disp, i1_imm_disp, i0_pc_disp, i1_pc_disp;
  logic        retire0_en, retire1_en;
  logic        rrat0_en, rrat1_en;
  gpr_addr_t   i0_rd_addr_cmt, i1_rd_addr_cmt;
  prf_addr_t   i0_rob_idx_cmt, i1_rob_idx_cmt;
  logic        stb0_en, stb1_en;

  rename_core_struct dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 0;
    flush = 0;
    stall_rn = 0;
    enable = 1;
    spec0_en_rn = 0; spec1_en_rn = 0;
    i0_lane_sel_rn = 0; i1_lane_sel_rn = 0;
    i0_valid_rn = 0; i1_valid_rn = 0;
    i0_reg_write_rn = 0; i1_reg_write_rn = 0;
    i0_store_en_rn = 0; i1_store_en_rn = 0;
    i0_rs1_use_rn = 0; i0_rs2_use_rn = 0;
    i1_rs1_use_rn = 0; i1_rs2_use_rn = 0;
    i0_opcode_rn = '0; i1_opcode_rn = '0;
    i0_funct3_rn = '0; i1_funct3_rn = '0;
    i0_funct7_rn = '0; i1_funct7_rn = '0;
    i0_rd_addr_rn = '0; i0_rs1_addr_rn = '0; i0_rs2_addr_rn = '0;
    i1_rd_addr_rn = '0; i1_rs1_addr_rn = '0; i1_rs2_addr_rn = '0;
    i0_imm_rn = '0; i0_pc_rn = '0; i1_imm_rn = '0; i1_pc_rn = '0;
    wback0_en = 0; wback1_en = 0;
    i0_rob_idx_wb = '0; i1_rob_idx_wb = '0;
    i0_brch_taken_wb = 0; i1_brch_taken_wb = 0;
    resolve_en = 0; resolve_mispred = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    spec0_en_rn = 0; spec1_en_rn = 0;
    i0_valid_rn = 1; i1_valid_rn = 1;
    i0_reg_write_rn = 1; i1_reg_write_rn = 1;
    i0_rs1_use_rn = 1; i0_rs2_use_rn = 1;
    i1_rs1_use_rn = 1; i1_rs2_use_rn = 1;
    i0_opcode_rn = OPC_OP; i1_opcode_rn = OPC_OP;
    i0_rd_addr_rn = 5'd1; i0_rs1_addr_rn = 5'd2; i0_rs2_addr_rn = 5'd3;
    i1_rd_addr_rn = 5'd4; i1_rs1_addr_rn = 5'd1; i1_rs2_addr_rn = 5'd5;
    i0_pc_rn = 32'h100; i1_pc_rn = 32'h104;
    @(posedge clk);
    if (stall_id) $error("unexpected stall");
    if (!i0_valid_disp || !i1_valid_disp) $error("rename did not fire");
    if (i0_rob_idx_disp != rob_to_prf(5'd0) || i1_rob_idx_disp != rob_to_prf(5'd1))
      $error("expect rob p32/p33 got %0d/%0d", i0_rob_idx_disp, i1_rob_idx_disp);
    if (i0_prd_disp != i0_rob_idx_disp)
      $error("i0 prd expect p%0d got %0d", i0_rob_idx_disp, i0_prd_disp);
    if (i1_prd_disp != i1_rob_idx_disp)
      $error("i1 prd expect p%0d got %0d", i1_rob_idx_disp, i1_prd_disp);
    if (i1_ps1_disp != i0_prd_disp) $error("I1 rs1 should bypass I0 prd");

    wback0_en = 1; i0_rob_idx_wb = i0_rob_idx_disp; i0_brch_taken_wb = 0;
    wback1_en = 1; i1_rob_idx_wb = i1_rob_idx_disp; i1_brch_taken_wb = 0;
    i0_reg_write_rn = 0; i1_reg_write_rn = 0;
    i0_valid_rn = 0; i1_valid_rn = 0;
    @(posedge clk);
    wback0_en = 0; wback1_en = 0;
    @(posedge clk);
    if (!rrat0_en || !rrat1_en) $error("expected dual RRAT commit");
    if (i0_rob_idx_cmt != rob_to_prf(5'd0) || i1_rob_idx_cmt != rob_to_prf(5'd1))
      $error("RRAT rob_idx expect p32/p33 got %0d/%0d", i0_rob_idx_cmt, i1_rob_idx_cmt);

    $display("OK rename_core_struct_tb");
    $finish;
  end
endmodule
