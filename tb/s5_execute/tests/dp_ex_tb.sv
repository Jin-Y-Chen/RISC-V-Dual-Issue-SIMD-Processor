`timescale 1ns / 1ps

// Smoke: dual issue → lane_sel demux onto ev0/ev1/od0/od1; PRF data buffered.
import rv_dis_pkg::*;

module dp_ex_tb;
  logic clk, rst_n, enable, flush, stall;

  logic        valid_iss     [2];
  logic        lane_sel_iss  [2];
  logic        reg_write_iss [2];
  opcode_t     opcode_iss    [2];
  funct3_t     funct3_iss    [2];
  funct7_t     funct7_iss    [2];
  prf_addr_t   prd_iss       [2];
  word_t       imm_iss       [2];
  word_t       pc_iss        [2];
  word_t       rs1_data      [2];
  word_t       rs2_data      [2];

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
    for (int i = 0; i < N_DUAL; i++) begin
      valid_iss[i]     = 0;
      lane_sel_iss[i]  = 0;
      reg_write_iss[i] = 0;
      opcode_iss[i]    = '0;
      funct3_iss[i]    = '0;
      funct7_iss[i]    = '0;
      prd_iss[i]       = '0;
      imm_iss[i]       = '0;
      pc_iss[i]        = '0;
      rs1_data[i]      = '0;
      rs2_data[i]      = '0;
    end
  endtask

  initial begin
    rst_n = 0; enable = 1; flush = 0; stall = 0;
    clear_iss();
    repeat (2) @(posedge clk);
    rst_n = 1;

    @(negedge clk);
    valid_iss[0] = 1; lane_sel_iss[0] = 0; reg_write_iss[0] = 1;
    opcode_iss[0] = OPC_OP; prd_iss[0] = 6'd32;
    rs1_data[0] = 32'hA000_0001; rs2_data[0] = 32'hA000_0002;
    valid_iss[1] = 1; lane_sel_iss[1] = 0; reg_write_iss[1] = 1;
    opcode_iss[1] = OPC_OP; prd_iss[1] = 6'd33;
    rs1_data[1] = 32'hB000_0001; rs2_data[1] = 32'hB000_0002;
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
    valid_iss[0] = 1; lane_sel_iss[0] = 0; prd_iss[0] = 6'd40;
    rs1_data[0] = 32'h1;
    valid_iss[1] = 1; lane_sel_iss[1] = 1; prd_iss[1] = 6'd41;
    opcode_iss[1] = OPC_LOAD; rs1_data[1] = 32'h2;
    @(posedge clk);
    #1;
    if (!ev0_enable_ex || ev1_enable_ex || !od0_enable_ex || od1_enable_ex)
      $error("mixed even/odd routing failed");
    if (ev0_prd_ex != 6'd40 || od0_prd_ex != 6'd41)
      $error("mixed port tags wrong");

    @(negedge clk);
    clear_iss();
    valid_iss[0] = 1; lane_sel_iss[0] = 1; prd_iss[0] = 6'd50;
    valid_iss[1] = 1; lane_sel_iss[1] = 1; prd_iss[1] = 6'd51;
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
