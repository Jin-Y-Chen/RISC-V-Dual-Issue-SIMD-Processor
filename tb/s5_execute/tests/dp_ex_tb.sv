`timescale 1ns / 1ps

// Smoke: dual issue -> lane_sel demux onto ev[2]/od[2]; PRF data buffered.
import rv_dis_pkg::*;

module dp_ex_tb;
  logic clk, rst_n, enable, flush, stall;

  logic        rob_valid [2];
  logic        lane_sel  [2];
  opcode_t     opcode    [2];
  funct3_t     funct3    [2];
  funct7_t     funct7    [2];
  prf_addr_t   rob_tag   [2];
  word_t       imm       [2];
  word_t       pc        [2];
  word_t       rs1_data  [2];
  word_t       rs2_data  [2];

  logic        ev_enable_ex    [2];
  logic        ev_reg_write_ex [2];
  opcode_t     ev_opcode_ex    [2];
  funct3_t     ev_funct3_ex    [2];
  funct7_t     ev_funct7_ex    [2];
  prf_addr_t   ev_prd_ex       [2];
  word_t       ev_imm_ex       [2];
  word_t       ev_pc_ex        [2];
  word_t       ev_rs1_data_ex  [2];
  word_t       ev_rs2_data_ex  [2];

  logic        od_enable_ex    [2];
  logic        od_reg_write_ex [2];
  opcode_t     od_opcode_ex    [2];
  funct3_t     od_funct3_ex    [2];
  prf_addr_t   od_prd_ex       [2];
  word_t       od_imm_ex       [2];
  word_t       od_pc_ex        [2];
  word_t       od_rs1_data_ex  [2];
  word_t       od_rs2_data_ex  [2];

  dp_ex dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  task automatic clear_iss;
    for (int i = 0; i < N_DUAL; i++) begin
      rob_valid[i] = 0;
      lane_sel[i]  = 0;
      opcode[i]    = '0;
      funct3[i]    = '0;
      funct7[i]    = '0;
      rob_tag[i]   = '0;
      imm[i]       = '0;
      pc[i]        = '0;
      rs1_data[i]  = '0;
      rs2_data[i]  = '0;
    end
  endtask

  initial begin
    rst_n = 0; enable = 1; flush = 0; stall = 0;
    clear_iss();
    repeat (2) @(posedge clk);
    rst_n = 1;

    @(negedge clk);
    rob_valid[0] = 1; lane_sel[0] = 0;
    opcode[0] = OPC_OP; rob_tag[0] = 6'd32;
    rs1_data[0] = 32'hA000_0001; rs2_data[0] = 32'hA000_0002;
    rob_valid[1] = 1; lane_sel[1] = 0;
    opcode[1] = OPC_OP; rob_tag[1] = 6'd33;
    rs1_data[1] = 32'hB000_0001; rs2_data[1] = 32'hB000_0002;
    @(posedge clk);
    #1;
    if (!ev_enable_ex[0] || !ev_enable_ex[1] || od_enable_ex[0] || od_enable_ex[1])
      $error("dual even routing failed");
    if (ev_prd_ex[0] != 6'd32 || ev_prd_ex[1] != 6'd33)
      $error("even port packing order wrong");
    if (ev_rs1_data_ex[0] != 32'hA000_0001 || ev_rs2_data_ex[1] != 32'hB000_0002)
      $error("PRF data not buffered on even ports");

    @(negedge clk);
    clear_iss();
    rob_valid[0] = 1; lane_sel[0] = 0; rob_tag[0] = 6'd40;
    rs1_data[0] = 32'h1;
    rob_valid[1] = 1; lane_sel[1] = 1; rob_tag[1] = 6'd41;
    opcode[1] = OPC_LOAD; rs1_data[1] = 32'h2;
    @(posedge clk);
    #1;
    if (!ev_enable_ex[0] || ev_enable_ex[1] || !od_enable_ex[0] || od_enable_ex[1])
      $error("mixed even/odd routing failed");
    if (ev_prd_ex[0] != 6'd40 || od_prd_ex[0] != 6'd41)
      $error("mixed port tags wrong");

    @(negedge clk);
    clear_iss();
    rob_valid[0] = 1; lane_sel[0] = 1; rob_tag[0] = 6'd50;
    rob_valid[1] = 1; lane_sel[1] = 1; rob_tag[1] = 6'd51;
    @(posedge clk);
    #1;
    if (ev_enable_ex[0] || ev_enable_ex[1] || !od_enable_ex[0] || !od_enable_ex[1])
      $error("dual odd routing failed");
    if (od_prd_ex[0] != 6'd50 || od_prd_ex[1] != 6'd51)
      $error("odd port packing order wrong");

    $display("OK dp_ex_tb");
    $finish;
  end
endmodule
