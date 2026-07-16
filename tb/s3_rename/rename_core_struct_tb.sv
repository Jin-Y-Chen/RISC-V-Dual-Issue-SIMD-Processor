`timescale 1ns / 1ps

// Smoke elaborate of rename_core_struct (Free List + RAT + ROB wiring).
import rv_dis_pkg::*;
import rob_pkg::*;

module rename_core_struct_tb;
  logic        clk, rst_n, flush;
  br_map_t     br_map;
  logic        i0_lane_sel_rn, i1_lane_sel_rn;
  logic        i0_reg_write_rn, i1_reg_write_rn;
  logic        i0_rs1_use_rn, i0_rs2_use_rn, i1_rs1_use_rn, i1_rs2_use_rn;
  opcode_t     i0_opcode_rn, i1_opcode_rn;
  funct3_t     i0_funct3_rn, i1_funct3_rn;
  funct7_t     i0_funct7_rn, i1_funct7_rn;
  gpr_addr_t   i0_rd_addr_rn, i0_rs1_addr_rn, i0_rs2_addr_rn;
  gpr_addr_t   i1_rd_addr_rn, i1_rs1_addr_rn, i1_rs2_addr_rn;
  word_t       i0_imm_rn, i0_pc_rn, i1_imm_rn, i1_pc_rn;
  logic        complete0_en, complete1_en;
  logic [ROB_AW-1:0] complete0_idx, complete1_idx;
  word_t       complete0_result, complete1_result;
  logic        resolve_en, resolve_mispred, resolve_win_path;
  logic        stall_id;

  logic        i0_valid_disp, i1_valid_disp;
  logic        i0_lane_sel_disp, i1_lane_sel_disp;
  logic        i0_reg_write_disp, i1_reg_write_disp;
  opcode_t     i0_opcode_disp, i1_opcode_disp;
  funct3_t     i0_funct3_disp, i1_funct3_disp;
  funct7_t     i0_funct7_disp, i1_funct7_disp;
  gpr_addr_t   i0_rd_addr_disp, i1_rd_addr_disp;
  prf_addr_t   i0_ps1_disp, i0_ps2_disp, i0_prd_disp;
  prf_addr_t   i1_ps1_disp, i1_ps2_disp, i1_prd_disp;
  logic [ROB_AW-1:0] i0_rob_idx_disp, i1_rob_idx_disp;
  word_t       i0_imm_disp, i1_imm_disp, i0_pc_disp, i1_pc_disp;
  logic        commit0_en, commit1_en, commit0_reg_write, commit1_reg_write;
  gpr_addr_t   commit0_rd_addr, commit1_rd_addr;
  prf_addr_t   commit0_prd, commit1_prd;
  word_t       commit0_result, commit1_result;

  rename_core_struct dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 0;
    flush = 0;
    br_map = BR_MAP_NONE;
    i0_lane_sel_rn = 0; i1_lane_sel_rn = 0;
    i0_reg_write_rn = 0; i1_reg_write_rn = 0;
    i0_rs1_use_rn = 0; i0_rs2_use_rn = 0;
    i1_rs1_use_rn = 0; i1_rs2_use_rn = 0;
    i0_opcode_rn = '0; i1_opcode_rn = '0;
    i0_funct3_rn = '0; i1_funct3_rn = '0;
    i0_funct7_rn = '0; i1_funct7_rn = '0;
    i0_rd_addr_rn = '0; i0_rs1_addr_rn = '0; i0_rs2_addr_rn = '0;
    i1_rd_addr_rn = '0; i1_rs1_addr_rn = '0; i1_rs2_addr_rn = '0;
    i0_imm_rn = '0; i0_pc_rn = '0; i1_imm_rn = '0; i1_pc_rn = '0;
    complete0_en = 0; complete1_en = 0;
    complete0_idx = '0; complete1_idx = '0;
    complete0_result = '0; complete1_result = '0;
    resolve_en = 0; resolve_mispred = 0; resolve_win_path = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    // Dual ADD renaming — both lanes write arch dests.
    br_map = BR_MAP_NONE;
    i0_reg_write_rn = 1; i1_reg_write_rn = 1;
    i0_rs1_use_rn = 1; i0_rs2_use_rn = 1;
    i1_rs1_use_rn = 1; i1_rs2_use_rn = 1;
    i0_opcode_rn = OPC_OP; i1_opcode_rn = OPC_OP;
    i0_rd_addr_rn = 5'd1; i0_rs1_addr_rn = 5'd2; i0_rs2_addr_rn = 5'd3;
    i1_rd_addr_rn = 5'd4; i1_rs1_addr_rn = 5'd1; i1_rs2_addr_rn = 5'd5; // I1 reads I0 rd
    i0_pc_rn = 32'h100; i1_pc_rn = 32'h104;
    @(posedge clk);
    if (stall_id) $error("unexpected stall");
    if (!i0_valid_disp || !i1_valid_disp) $error("rename did not fire");
    if (i0_prd_disp != prf_addr_t'(32)) $error("i0 prd expect p32 got %0d", i0_prd_disp);
    if (i1_prd_disp != prf_addr_t'(33)) $error("i1 prd expect p33 got %0d", i1_prd_disp);
    if (i1_ps1_disp != i0_prd_disp) $error("I1 rs1 should bypass I0 prd");

    complete0_en = 1; complete0_idx = i0_rob_idx_disp; complete0_result = 32'hA;
    complete1_en = 1; complete1_idx = i1_rob_idx_disp; complete1_result = 32'hB;
    i0_reg_write_rn = 0; i1_reg_write_rn = 0;
    @(posedge clk);
    complete0_en = 0; complete1_en = 0;
    @(posedge clk);
    if (!commit0_en || !commit1_en) $error("expected dual commit");

    $display("OK rename_core_struct_tb");
    $finish;
  end
endmodule
