`timescale 1ns / 1ps

// Smoke: dual issue → lane_sel demux onto ev0/ev1/od0/od1; PRF data buffered.
import rv_dis_pkg::*;

module dp_ex_tb;
  logic clk, rst_n, enable, flush, stall;

  logic        i0_valid_iss, i1_valid_iss;
  logic        i0_lane_sel_iss, i1_lane_sel_iss;
  logic        i0_reg_write_iss, i1_reg_write_iss;
  opcode_t     i0_opcode_iss, i1_opcode_iss;
  funct3_t     i0_funct3_iss, i1_funct3_iss;
  funct7_t     i0_funct7_iss, i1_funct7_iss;
  prf_addr_t   i0_prd_iss, i1_prd_iss;
  word_t       i0_imm_iss, i0_pc_iss, i1_imm_iss, i1_pc_iss;
  word_t       i0_rs1_data, i0_rs2_data, i1_rs1_data, i1_rs2_data;

  logic        ev0_enable_ex, ev1_enable_ex, od0_enable_ex, od1_enable_ex;
  logic        ev0_reg_write_ex, ev1_reg_write_ex, od0_reg_write_ex, od1_reg_write_ex;
  opcode_t     ev0_opcode_ex, ev1_opcode_ex, od0_opcode_ex, od1_opcode_ex;
  funct3_t     ev0_funct3_ex, ev1_funct3_ex, od0_funct3_ex, od1_funct3_ex;
  funct7_t     ev0_funct7_ex, ev1_funct7_ex;
  prf_addr_t   ev0_prd_ex, ev1_prd_ex, od0_prd_ex, od1_prd_ex;
  word_t       ev0_imm_ex, ev1_imm_ex, od0_imm_ex, od1_imm_ex;
  word_t       ev0_pc_ex, ev1_pc_ex, od0_pc_ex, od1_pc_ex;
  word_t       ev0_rs1_data_ex, ev0_rs2_data_ex;
  word_t       ev1_rs1_data_ex, ev1_rs2_data_ex;
  word_t       od0_rs1_data_ex, od0_rs2_data_ex;
  word_t       od1_rs1_data_ex, od1_rs2_data_ex;

  dp_ex dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  task automatic clear_iss;
    i0_valid_iss = 0; i1_valid_iss = 0;
    i0_lane_sel_iss = 0; i1_lane_sel_iss = 0;
    i0_reg_write_iss = 0; i1_reg_write_iss = 0;
    i0_opcode_iss = '0; i1_opcode_iss = '0;
    i0_funct3_iss = '0; i1_funct3_iss = '0;
    i0_funct7_iss = '0; i1_funct7_iss = '0;
    i0_prd_iss = '0; i1_prd_iss = '0;
    i0_imm_iss = '0; i1_imm_iss = '0;
    i0_pc_iss = '0; i1_pc_iss = '0;
    i0_rs1_data = '0; i0_rs2_data = '0;
    i1_rs1_data = '0; i1_rs2_data = '0;
  endtask

  initial begin
    rst_n = 0; enable = 1; flush = 0; stall = 0;
    clear_iss();
    repeat (2) @(posedge clk);
    rst_n = 1;

    @(negedge clk);
    i0_valid_iss = 1; i0_lane_sel_iss = 0; i0_reg_write_iss = 1;
    i0_opcode_iss = OPC_OP; i0_prd_iss = 6'd32;
    i0_rs1_data = 32'hA000_0001; i0_rs2_data = 32'hA000_0002;
    i1_valid_iss = 1; i1_lane_sel_iss = 0; i1_reg_write_iss = 1;
    i1_opcode_iss = OPC_OP; i1_prd_iss = 6'd33;
    i1_rs1_data = 32'hB000_0001; i1_rs2_data = 32'hB000_0002;
    @(posedge clk);
    #1;
    if (!ev0_enable_ex || !ev1_enable_ex || od0_enable_ex || od1_enable_ex)
      $error("dual even routing failed");
    if (ev0_prd_ex != 6'd32 || ev1_prd_ex != 6'd33)
      $error("even port packing order wrong");
    if (ev0_rs1_data_ex != 32'hA000_0001 || ev1_rs2_data_ex != 32'hB000_0002)
      $error("PRF data not buffered on even ports");

    @(negedge clk);
    clear_iss();
    i0_valid_iss = 1; i0_lane_sel_iss = 0; i0_prd_iss = 6'd40;
    i0_rs1_data = 32'h1;
    i1_valid_iss = 1; i1_lane_sel_iss = 1; i1_prd_iss = 6'd41;
    i1_opcode_iss = OPC_LOAD; i1_rs1_data = 32'h2;
    @(posedge clk);
    #1;
    if (!ev0_enable_ex || ev1_enable_ex || !od0_enable_ex || od1_enable_ex)
      $error("mixed even/odd routing failed");
    if (ev0_prd_ex != 6'd40 || od0_prd_ex != 6'd41)
      $error("mixed port tags wrong");

    @(negedge clk);
    clear_iss();
    i0_valid_iss = 1; i0_lane_sel_iss = 1; i0_prd_iss = 6'd50;
    i1_valid_iss = 1; i1_lane_sel_iss = 1; i1_prd_iss = 6'd51;
    @(posedge clk);
    #1;
    if (ev0_enable_ex || ev1_enable_ex || !od0_enable_ex || !od1_enable_ex)
      $error("dual odd routing failed");
    if (od0_prd_ex != 6'd50 || od1_prd_ex != 6'd51)
      $error("odd port packing order wrong");

    $display("OK dp_ex_tb");
    $finish;
  end
endmodule
