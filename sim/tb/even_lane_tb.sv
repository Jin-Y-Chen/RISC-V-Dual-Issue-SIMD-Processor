`timescale 1ns / 1ps

// Unit testbench for even_lane scalar ALU (RV32I OP / OP-IMM).
// Combinational: sample outputs while valid=1 (before deassert).
module even_lane_tb;

  import spu_lite_pkg::*;

  `include "tb_console.svh"

  logic        valid;
  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [4:0]  rd;
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;
  logic [31:0] imm;
  logic [31:0] pc;

  logic        reg_write;
  logic [4:0]  rd_out;
  logic [31:0] alu_result;
  logic [31:0] wb_data;

  int pass_cnt;
  int fail_cnt;

  even_lane dut (.*);

  task automatic check(
    input string       name,
    input string       detail,
    input logic        exp_reg_write,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_result
  );
    string got_detail;
    if (valid !== 1'b1) begin
      tb_fail_detail(name, "valid=0 during check");
      fail_cnt++;
      return;
    end
    if (reg_write !== exp_reg_write) begin
      got_detail = $sformatf("%s, reg_write=%0d expected %0d", detail, reg_write, exp_reg_write);
      tb_fail_detail(name, got_detail);
      fail_cnt++;
    end else if (rd_out !== exp_rd) begin
      got_detail = $sformatf("%s, rd=x%0d expected x%0d", detail, rd_out, exp_rd);
      tb_fail_detail(name, got_detail);
      fail_cnt++;
    end else if (alu_result !== exp_result) begin
      got_detail = $sformatf("%s, result=%h expected %h", detail, alu_result, exp_result);
      tb_fail_detail(name, got_detail);
      fail_cnt++;
    end else if (wb_data !== exp_result) begin
      got_detail = $sformatf("%s, wb_data=%h expected %h", detail, wb_data, exp_result);
      tb_fail_detail(name, got_detail);
      fail_cnt++;
    end else begin
      tb_pass_detail(name, detail);
      pass_cnt++;
    end
  endtask

  task automatic idle_cycle;
    valid = 1'b0;
    #1;
  endtask

  task automatic exec_r_type(
    input string       name,
    input string       op_name,
    input logic [2:0]  f3,
    input logic [6:0]  f7,
    input logic [4:0]  rd_i,
    input logic [31:0] rs1,
    input logic [31:0] rs2,
    input logic        exp_reg_write,
    input logic [31:0] exp_result
  );
    string detail;
    valid    = 1'b1;
    opcode   = OPC_OP;
    funct3   = f3;
    funct7   = f7;
    rd       = rd_i;
    rs1_data = rs1;
    rs2_data = rs2;
    imm      = 32'h0;
    #1;
    detail = $sformatf("%s, rs1=%h, rs2=%h, result=%h (rd=x%0d)",
      op_name, rs1, rs2, exp_result, rd_i);
    check(name, detail, exp_reg_write, rd_i, exp_result);
    idle_cycle();
  endtask

  task automatic exec_i_type(
    input string       name,
    input string       op_name,
    input logic [2:0]  f3,
    input logic [4:0]  rd_i,
    input logic [31:0] rs1,
    input logic [31:0] imm_i,
    input logic        exp_reg_write,
    input logic [31:0] exp_result,
    input logic [6:0]  f7 = 7'b0
  );
    string detail;
    valid    = 1'b1;
    opcode   = OPC_OP_IMM;
    funct3   = f3;
    funct7   = f7;
    rd       = rd_i;
    rs1_data = rs1;
    rs2_data = 32'h0;
    imm      = imm_i;
    #1;
    detail = $sformatf("%s, rs1=%h, imm=%h, result=%h (rd=x%0d)",
      op_name, rs1, imm_i, exp_result, rd_i);
    check(name, detail, exp_reg_write, rd_i, exp_result);
    idle_cycle();
  endtask

  initial begin
    string detail;
    valid = 0;
    pc    = 32'h8000_0000;
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("even_lane_tb - scalar ALU");
    tb_info_msg("PASS line format: <test> | <op>, operands, result (rd)");

    exec_r_type("add", "ADD",  F3_ADD_SUB, 7'b0,     5'd5,  32'd10,        32'd32, 1'b1, 32'd42);
    exec_r_type("sub", "SUB",  F3_ADD_SUB, F7_SUB,   5'd6,  32'd50,        32'd8,  1'b1, 32'd42);
    exec_r_type("and", "AND",  F3_AND,     7'b0,     5'd7,  32'hFF00_00FF, 32'h0F0F_0F0F, 1'b1, 32'h0F00_000F);
    exec_r_type("or",  "OR",   F3_OR,      7'b0,     5'd8,  32'hF000_F000, 32'h0F0F_0F0F, 1'b1, 32'hFF0F_FF0F);
    exec_r_type("xor", "XOR",  F3_XOR,     7'b0,     5'd9,  32'hAAAA_AAAA, 32'h5555_5555, 1'b1, 32'hFFFF_FFFF);
    exec_r_type("sll", "SLL",  F3_SLL,     7'b0,     5'd14, 32'd1,         32'd4,         1'b1, 32'd16);
    exec_r_type("srl", "SRL",  F3_SRL_SRA, 7'b0,     5'd15, 32'd16,        32'd2,         1'b1, 32'd4);
    exec_r_type("sra", "SRA",  F3_SRL_SRA, F7_SRA,   5'd16, 32'h8000_0008, 32'd3,         1'b1, 32'hF000_0001);
    exec_r_type("slt", "SLT",  F3_SLT,     7'b0,     5'd17, 32'hFFFF_FFFF, 32'd1,         1'b1, 32'd1);
    exec_r_type("add_x0", "ADD", F3_ADD_SUB, 7'b0, 5'd0, 32'd1, 32'd2, 1'b0, 32'd3);

    exec_i_type("addi", "ADDI", F3_ADD_SUB, 5'd10, 32'd100,       32'd23,         1'b1, 32'd123);
    exec_i_type("andi", "ANDI", F3_AND,     5'd11, 32'hFFFF_0000, 32'h0000_00FF, 1'b1, 32'h0000_0000);
    exec_i_type("ori",  "ORI",  F3_OR,      5'd12, 32'h0000_F000, 32'h0000_0F0F, 1'b1, 32'h0000_FF0F);
    exec_i_type("xori", "XORI", F3_XOR,     5'd13, 32'hFFFF_0000, 32'h0000_FFFF, 1'b1, 32'hFFFF_FFFF);
    exec_i_type("slli", "SLLI", F3_SLL,     5'd18, 32'd1,         32'd3,         1'b1, 32'd8);
    exec_i_type("srli", "SRLI", F3_SRL_SRA, 5'd19, 32'h8000_0000, 32'd4,         1'b1, 32'h0800_0000);
    exec_i_type("srai", "SRAI", F3_SRL_SRA, 5'd20, 32'h8000_0000, 32'd4,         1'b1, 32'hF800_0000, F7_SRA);

    valid    = 1'b1;
    opcode   = OPC_LOAD;
    funct3   = F3_LW;
    funct7   = 7'b0;
    rd       = 5'd3;
    rs1_data = 32'd0;
    rs2_data = 32'd0;
    imm      = 32'd4;
    #1;
    detail = "LOAD on even lane (wrong opcode), expect no reg_write";
    check("load_reject", detail, 1'b0, 5'd3, alu_result);
    idle_cycle();

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "even_lane_tb failed");
    $finish;
  end

endmodule
