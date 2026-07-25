`timescale 1ns/1ps
`include "uvm_macros.svh"

module rename_tb_top;
  import uvm_pkg::*;
  import rv_dis_pkg::*;
  import rob_pkg::*;
  import rename_uvm_pkg::*;

  logic clk = 0;
  rename_if vif(clk);

  always #5ns clk = ~clk;

  rename_core_struct dut (
    .clk(clk),
    .rst_n(vif.rst_n),
    .flush(vif.flush),
    .stall_rn(1'b0),
    .enable(1'b1),
    .spec0_en_rn(vif.spec0_en_rn),
    .spec1_en_rn(vif.spec1_en_rn),
    .i0_valid_rn(vif.i0_valid_rn),
    .i1_valid_rn(vif.i1_valid_rn),
    .i0_lane_sel_rn(vif.i0_lane_sel_rn),
    .i1_lane_sel_rn(vif.i1_lane_sel_rn),
    .i0_reg_write_rn(vif.i0_reg_write_rn),
    .i1_reg_write_rn(vif.i1_reg_write_rn),
    .i0_store_en_rn(vif.i0_store_en_rn),
    .i1_store_en_rn(vif.i1_store_en_rn),
    .i0_rs1_use_rn(vif.i0_rs1_use_rn),
    .i0_rs2_use_rn(vif.i0_rs2_use_rn),
    .i1_rs1_use_rn(vif.i1_rs1_use_rn),
    .i1_rs2_use_rn(vif.i1_rs2_use_rn),
    .i0_opcode_rn(vif.i0_opcode_rn),
    .i1_opcode_rn(vif.i1_opcode_rn),
    .i0_funct3_rn(vif.i0_funct3_rn),
    .i1_funct3_rn(vif.i1_funct3_rn),
    .i0_funct7_rn(vif.i0_funct7_rn),
    .i1_funct7_rn(vif.i1_funct7_rn),
    .i0_rd_addr_rn(vif.i0_rd_addr_rn),
    .i0_rs1_addr_rn(vif.i0_rs1_addr_rn),
    .i0_rs2_addr_rn(vif.i0_rs2_addr_rn),
    .i1_rd_addr_rn(vif.i1_rd_addr_rn),
    .i1_rs1_addr_rn(vif.i1_rs1_addr_rn),
    .i1_rs2_addr_rn(vif.i1_rs2_addr_rn),
    .i0_imm_rn(vif.i0_imm_rn),
    .i0_pc_rn(vif.i0_pc_rn),
    .i1_imm_rn(vif.i1_imm_rn),
    .i1_pc_rn(vif.i1_pc_rn),
    .wback0_en(vif.wback0_en),
    .wback1_en(vif.wback1_en),
    .i0_rob_idx_wb(vif.i0_rob_idx_wb),
    .i1_rob_idx_wb(vif.i1_rob_idx_wb),
    .i0_brch_taken_wb(vif.i0_brch_taken_wb),
    .i1_brch_taken_wb(vif.i1_brch_taken_wb),
    .resolve_en(vif.resolve_en),
    .resolve_mispred(vif.resolve_mispred),
    .stall_id(vif.stall_id),
    .i0_valid_disp(vif.i0_valid_disp),
    .i1_valid_disp(vif.i1_valid_disp),
    .i0_lane_sel_disp(vif.i0_lane_sel_disp),
    .i1_lane_sel_disp(vif.i1_lane_sel_disp),
    .i0_reg_write_disp(vif.i0_reg_write_disp),
    .i1_reg_write_disp(vif.i1_reg_write_disp),
    .i0_opcode_disp(vif.i0_opcode_disp),
    .i1_opcode_disp(vif.i1_opcode_disp),
    .i0_funct3_disp(vif.i0_funct3_disp),
    .i1_funct3_disp(vif.i1_funct3_disp),
    .i0_funct7_disp(vif.i0_funct7_disp),
    .i1_funct7_disp(vif.i1_funct7_disp),
    .i0_rd_addr_disp(vif.i0_rd_addr_disp),
    .i1_rd_addr_disp(vif.i1_rd_addr_disp),
    .i0_ps1_disp(vif.i0_ps1_disp),
    .i0_ps2_disp(vif.i0_ps2_disp),
    .i0_prd_disp(vif.i0_prd_disp),
    .i1_ps1_disp(vif.i1_ps1_disp),
    .i1_ps2_disp(vif.i1_ps2_disp),
    .i1_prd_disp(vif.i1_prd_disp),
    .i0_rob_idx_disp(vif.i0_rob_idx_disp),
    .i1_rob_idx_disp(vif.i1_rob_idx_disp),
    .i0_imm_disp(vif.i0_imm_disp),
    .i1_imm_disp(vif.i1_imm_disp),
    .i0_pc_disp(vif.i0_pc_disp),
    .i1_pc_disp(vif.i1_pc_disp),
    .retire0_en(vif.retire0_en),
    .retire1_en(vif.retire1_en),
    .rrat0_en(vif.rrat0_en),
    .rrat1_en(vif.rrat1_en),
    .i0_rd_addr_cmt(vif.i0_rd_addr_cmt),
    .i1_rd_addr_cmt(vif.i1_rd_addr_cmt),
    .i0_rob_idx_cmt(vif.i0_rob_idx_cmt),
    .i1_rob_idx_cmt(vif.i1_rob_idx_cmt),
    .stb0_en(vif.stb0_en),
    .stb1_en(vif.stb1_en)
  );

  initial begin
    vif.rst_n = 0;
    vif.flush = 0;
    vif.spec0_en_rn = 0;
    vif.spec1_en_rn = 0;
    vif.i0_valid_rn = 0;
    vif.i1_valid_rn = 0;
    vif.i0_lane_sel_rn = 0;
    vif.i1_lane_sel_rn = 0;
    vif.i0_reg_write_rn = 0;
    vif.i1_reg_write_rn = 0;
    vif.i0_store_en_rn = 0;
    vif.i1_store_en_rn = 0;
    vif.i0_rs1_use_rn = 0;
    vif.i0_rs2_use_rn = 0;
    vif.i1_rs1_use_rn = 0;
    vif.i1_rs2_use_rn = 0;
    vif.i0_opcode_rn = '0;
    vif.i1_opcode_rn = '0;
    vif.i0_funct3_rn = '0;
    vif.i1_funct3_rn = '0;
    vif.i0_funct7_rn = '0;
    vif.i1_funct7_rn = '0;
    vif.i0_rd_addr_rn = '0;
    vif.i0_rs1_addr_rn = '0;
    vif.i0_rs2_addr_rn = '0;
    vif.i1_rd_addr_rn = '0;
    vif.i1_rs1_addr_rn = '0;
    vif.i1_rs2_addr_rn = '0;
    vif.i0_imm_rn = '0;
    vif.i0_pc_rn = '0;
    vif.i1_imm_rn = '0;
    vif.i1_pc_rn = '0;
    vif.wback0_en = 0;
    vif.wback1_en = 0;
    vif.i0_rob_idx_wb = '0;
    vif.i1_rob_idx_wb = '0;
    vif.i0_brch_taken_wb = 0;
    vif.i1_brch_taken_wb = 0;
    vif.resolve_en = 0;
    vif.resolve_mispred = 0;
    repeat (4) @(posedge clk);
    vif.rst_n = 1;
  end

  initial begin
    string testname;
    uvm_config_db#(virtual rename_if)::set(null, "uvm_test_top", "vif", vif);
    if (!$value$plusargs("UVM_TESTNAME=%s", testname))
      testname = "rename_smoke_test";
    run_test(testname);
  end

  initial begin
    #1ms;
    `uvm_fatal("TIMEOUT", "rename UVM test exceeded 1 ms")
  end
endmodule
