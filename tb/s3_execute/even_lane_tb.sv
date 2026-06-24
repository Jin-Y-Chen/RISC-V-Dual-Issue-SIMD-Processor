`timescale 1ns / 1ps

// even_lane_tb — DUT vs hand-written expected ALU results (decoder_tb-style stimulus).
module even_lane_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  logic        enable;
  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;
  logic [31:0] imm;

  logic        reg_write;
  logic [31:0] alu_result;

  int pass_cnt;
  int fail_cnt;

  even_lane dut (.*);

  task automatic run_insn(
    input logic        enable_i,
    input logic [6:0]  opcode_i,
    input logic [2:0]  funct3_i,
    input logic [6:0]  funct7_i,
    input logic [31:0] rs1_i,
    input logic [31:0] rs2_i,
    input logic [31:0] imm_i
  );
    enable   = enable_i;
    opcode   = opcode_i;
    funct3   = funct3_i;
    funct7   = funct7_i;
    rs1_data = rs1_i;
    rs2_data = rs2_i;
    imm      = imm_i;
    #1;
  endtask

  task automatic check_expect(
    input string       name,
    input string       detail,
    input logic        exp_reg_write,
    input logic [31:0] exp_alu_result
  );
    bit pass;
    if (enable !== 1'b1) begin
      tb_fail_field_bit(name, detail, "enable", enable, 1'b1);
      fail_cnt++;
      return;
    end
    pass = (reg_write === exp_reg_write && alu_result === exp_alu_result);
    tb_report_open(pass, name, detail);
    tb_field_bit("reg_write", reg_write, exp_reg_write);
    tb_field_u32("alu_result", alu_result, exp_alu_result);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic run_idle;
    enable = 1'b0;
    #1;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("even_lane_tb - scalar ALU");
    tb_info_msg("Golden values explicit per test (run_insn + check_expect)");

    // --- R-type ---
    run_insn(1'b1, OPC_OP, F3_ADD_SUB, 7'b0, 32'd10, 32'd32, 32'd0);
    check_expect("add", "ADD x5, rs1=10, rs2=32 -> 42", 1'b1, 32'd42);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_ADD_SUB, F7_SUB, 32'd50, 32'd8, 32'd0);
    check_expect("sub", "SUB x6, rs1=50, rs2=8 -> 42", 1'b1, 32'd42);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_AND, 7'b0, 32'hFF00_00FF, 32'h0F0F_0F0F, 32'd0);
    check_expect("and", "AND x7", 1'b1, 32'h0F00_000F);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_OR, 7'b0, 32'hF000_F000, 32'h0F0F_0F0F, 32'd0);
    check_expect("or", "OR x8", 1'b1, 32'hFF0F_FF0F);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_XOR, 7'b0, 32'hAAAA_AAAA, 32'h5555_5555, 32'd0);
    check_expect("xor", "XOR x9", 1'b1, 32'hFFFF_FFFF);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_SLL, 7'b0, 32'd1, 32'd4, 32'd0);
    check_expect("sll", "SLL x14, shamt=4", 1'b1, 32'd16);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_SRL_SRA, 7'b0, 32'd16, 32'd2, 32'd0);
    check_expect("srl", "SRL x15, shamt=2", 1'b1, 32'd4);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_SRL_SRA, F7_SRA, 32'h8000_0008, 32'd3, 32'd0);
    check_expect("sra", "SRA x16, shamt=3", 1'b1, 32'hF000_0001);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_SLT, 7'b0, 32'hFFFF_FFFF, 32'd1, 32'd0);
    check_expect("slt", "SLT x17", 1'b1, 32'd1);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_ADD_SUB, 7'b0, 32'd1, 32'd2, 32'd0);
    check_expect("add_x0", "ADD x0 now writes enabled by opcode", 1'b1, 32'd3);
    run_idle();

    // --- OP-IMM ---
    run_insn(1'b1, OPC_OP_IMM, F3_ADD_SUB, 7'b0, 32'd100, 32'd0, 32'd23);
    check_expect("addi", "ADDI x10, +23", 1'b1, 32'd123);
    run_idle();

    run_insn(1'b1, OPC_OP_IMM, F3_AND, 7'b0, 32'hFFFF_0000, 32'd0, 32'h0000_00FF);
    check_expect("andi", "ANDI x11", 1'b1, 32'h0000_0000);
    run_idle();

    run_insn(1'b1, OPC_OP_IMM, F3_OR, 7'b0, 32'h0000_F000, 32'd0, 32'h0000_0F0F);
    check_expect("ori", "ORI x12", 1'b1, 32'h0000_FF0F);
    run_idle();

    run_insn(1'b1, OPC_OP_IMM, F3_XOR, 7'b0, 32'hFFFF_0000, 32'd0, 32'h0000_FFFF);
    check_expect("xori", "XORI x13", 1'b1, 32'hFFFF_FFFF);
    run_idle();

    run_insn(1'b1, OPC_OP_IMM, F3_SLL, 7'b0, 32'd1, 32'd0, 32'd3);
    check_expect("slli", "SLLI x18, shamt=3", 1'b1, 32'd8);
    run_idle();

    run_insn(1'b1, OPC_OP_IMM, F3_SRL_SRA, 7'b0, 32'h8000_0000, 32'd0, 32'd4);
    check_expect("srli", "SRLI x19, shamt=4", 1'b1, 32'h0800_0000);
    run_idle();

    // SRAI: imm[11:0]={F7_SRA,shamt} = {7'h20,5'd4} = 12'h404 (ALU still uses imm[4:0]=4)
    run_insn(1'b1, OPC_OP_IMM, F3_SRL_SRA, F7_SRA, 32'h8000_0000, 32'd0, 32'h0000_0404);
    check_expect("srai", "SRAI x20, imm12=0x404, shamt=4", 1'b1, 32'hF800_0000);
    run_idle();

    // --- Wrong lane opcode ---
    run_insn(1'b1, OPC_LOAD, F3_LW, 7'b0, 32'd0, 32'd0, 32'd4);
    check_expect("load_reject", "LOAD on even lane -> no reg_write", 1'b0, alu_result);
    run_idle();

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "even_lane_tb failed");
    $finish;
  end

endmodule
