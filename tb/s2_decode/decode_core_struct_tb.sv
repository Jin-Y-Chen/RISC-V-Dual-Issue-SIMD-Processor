`timescale 1ns / 1ps

// Smoke elaborate of s2_decode_struct (port / child wiring check).
import rv_dis_pkg::*;

module decode_core_struct_tb;
  logic        clk;
  logic        rst_n;
  logic        i0_valid_id, i1_valid_id, spec0_en, spec1_en;
  instr_t      i0_instr, i1_instr;
  word_t       i0_pc, i1_pc, i0_pc_target, i1_pc_target;
  logic        i0_wen, i1_wen;
  gpr_addr_t   i0_rd, i1_rd;
  word_t       i0_wdata, i1_wdata;
  logic        i0_br_valid_wb, i1_br_valid_wb;
  word_t       i0_br_pc_wb, i1_br_pc_wb;
  br_state_t   i0_target_state_wb, i1_target_state_wb;

  logic        i0_lane_sel, i1_lane_sel;
  opcode_t     i0_opcode, i1_opcode;
  funct3_t     i0_funct3, i1_funct3;
  funct7_t     i0_funct7, i1_funct7;
  gpr_addr_t   i0_rd_addr, i0_rs1_addr, i0_rs2_addr;
  gpr_addr_t   i1_rd_addr, i1_rs1_addr, i1_rs2_addr;
  word_t       i0_imm, i0_rs1_data, i0_rs2_data;
  word_t       i1_imm, i1_rs1_data, i1_rs2_data;
  logic        i0_valid, i0_brch_en, i0_jump_en, i0_rs1_use, i0_rs2_use, i0_reg_write;
  logic        i1_valid, i1_brch_en, i1_jump_en, i1_rs1_use, i1_rs2_use, i1_reg_write;
  br_state_t   i0_target_state, i1_target_state;
  word_t       i0_pc_predict, i1_pc_predict;
  logic        i0_predict_taken, i1_predict_taken;
  logic        i0_tp_wb_valid, i1_tp_wb_valid;
  logic        i0_spec_stall, i1_spec_stall;

  s2_decode_struct dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 0;
    i0_valid_id = 0; i1_valid_id = 0;
    spec0_en = 0; spec1_en = 0;
    i0_instr = '0; i1_instr = '0;
    i0_pc = '0; i1_pc = '0;
    i0_pc_target = '0; i1_pc_target = '0;
    i0_wen = 0; i1_wen = 0;
    i0_rd = '0; i1_rd = '0;
    i0_wdata = '0; i1_wdata = '0;
    i0_br_valid_wb = 0; i1_br_valid_wb = 0;
    i0_br_pc_wb = '0; i1_br_pc_wb = '0;
    i0_target_state_wb = '0; i1_target_state_wb = '0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    $display("OK decode_core_struct_tb elaborate/smoke");
    $finish;
  end
endmodule
