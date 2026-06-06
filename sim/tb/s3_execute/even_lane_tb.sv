`timescale 1ns / 1ps

// even_lane_tb — DUT vs hand-written expected ALU results (decoder_tb-style stimulus).
module even_lane_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

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
  logic [31:0] pc_out;

  int pass_cnt;
  int fail_cnt;

  even_lane dut (.*);

  task automatic run_insn(
    input logic        valid_i,
    input logic [6:0]  opcode_i,
    input logic [2:0]  funct3_i,
    input logic [6:0]  funct7_i,
    input logic [4:0]  rd_i,
    input logic [31:0] rs1_i,
    input logic [31:0] rs2_i,
    input logic [31:0] imm_i,
    input logic [31:0] pc_i
  );
    valid    = valid_i;
    opcode   = opcode_i;
    funct3   = funct3_i;
    funct7   = funct7_i;
    rd       = rd_i;
    rs1_data = rs1_i;
    rs2_data = rs2_i;
    imm      = imm_i;
    pc       = pc_i;
    #1;
  endtask

  task automatic check_expect(
    input string       name,
    input string       detail,
    input logic        exp_reg_write,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_alu_result,
    input logic [31:0] exp_pc_out
  );
    bit pass;
    if (valid !== 1'b1) begin
      tb_fail_field_bit(name, detail, "valid", valid, 1'b1);
      fail_cnt++;
      return;
    end
    pass = (reg_write === exp_reg_write && rd_out === exp_rd &&
            alu_result === exp_alu_result && pc_out === exp_pc_out);
    tb_report_open(pass, name, detail);
    tb_field_bit("reg_write", reg_write, exp_reg_write);
    tb_field_u5("rd_out", rd_out, exp_rd);
    tb_field_u32("alu_result", alu_result, exp_alu_result);
    tb_field_u32("pc_out", pc_out, exp_pc_out);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic run_idle;
    valid = 1'b0;
    #1;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("even_lane_tb - scalar ALU");
    tb_info_msg("Golden values explicit per test (run_insn + check_expect)");

    // --- R-type ---
    run_insn(1'b1, OPC_OP, F3_ADD_SUB, 7'b0, 5'd5, 32'd10, 32'd32, 32'd0, 32'h0000_1000);
    check_expect("add", "ADD x5, rs1=10, rs2=32 -> 42", 1'b1, 5'd5, 32'd42, 32'h0000_1000);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_ADD_SUB, F7_SUB, 5'd6, 32'd50, 32'd8, 32'd0, 32'h0000_1004);
    check_expect("sub", "SUB x6, rs1=50, rs2=8 -> 42", 1'b1, 5'd6, 32'd42, 32'h0000_1004);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_AND, 7'b0, 5'd7, 32'hFF00_00FF, 32'h0F0F_0F0F, 32'd0, 32'h0000_1008);
    check_expect("and", "AND x7", 1'b1, 5'd7, 32'h0F00_000F, 32'h0000_1008);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_OR, 7'b0, 5'd8, 32'hF000_F000, 32'h0F0F_0F0F, 32'd0, 32'h0000_100C);
    check_expect("or", "OR x8", 1'b1, 5'd8, 32'hFF0F_FF0F, 32'h0000_100C);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_XOR, 7'b0, 5'd9, 32'hAAAA_AAAA, 32'h5555_5555, 32'd0, 32'h0000_1010);
    check_expect("xor", "XOR x9", 1'b1, 5'd9, 32'hFFFF_FFFF, 32'h0000_1010);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_SLL, 7'b0, 5'd14, 32'd1, 32'd4, 32'd0, 32'h0000_1014);
    check_expect("sll", "SLL x14, shamt=4", 1'b1, 5'd14, 32'd16, 32'h0000_1014);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_SRL_SRA, 7'b0, 5'd15, 32'd16, 32'd2, 32'd0, 32'h0000_1018);
    check_expect("srl", "SRL x15, shamt=2", 1'b1, 5'd15, 32'd4, 32'h0000_1018);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_SRL_SRA, F7_SRA, 5'd16, 32'h8000_0008, 32'd3, 32'd0, 32'h0000_101C);
    check_expect("sra", "SRA x16, shamt=3", 1'b1, 5'd16, 32'hF000_0001, 32'h0000_101C);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_SLT, 7'b0, 5'd17, 32'hFFFF_FFFF, 32'd1, 32'd0, 32'h0000_1020);
    check_expect("slt", "SLT x17", 1'b1, 5'd17, 32'd1, 32'h0000_1020);
    run_idle();

    run_insn(1'b1, OPC_OP, F3_ADD_SUB, 7'b0, 5'd0, 32'd1, 32'd2, 32'd0, 32'h0000_1024);
    check_expect("add_x0", "ADD x0 -> no reg_write", 1'b0, 5'd0, 32'd3, 32'h0000_1024);
    run_idle();

    // --- OP-IMM ---
    run_insn(1'b1, OPC_OP_IMM, F3_ADD_SUB, 7'b0, 5'd10, 32'd100, 32'd0, 32'd23, 32'h0000_1100);
    check_expect("addi", "ADDI x10, +23", 1'b1, 5'd10, 32'd123, 32'h0000_1100);
    run_idle();

    run_insn(1'b1, OPC_OP_IMM, F3_AND, 7'b0, 5'd11, 32'hFFFF_0000, 32'd0, 32'h0000_00FF, 32'h0000_1104);
    check_expect("andi", "ANDI x11", 1'b1, 5'd11, 32'h0000_0000, 32'h0000_1104);
    run_idle();

    run_insn(1'b1, OPC_OP_IMM, F3_OR, 7'b0, 5'd12, 32'h0000_F000, 32'd0, 32'h0000_0F0F, 32'h0000_1108);
    check_expect("ori", "ORI x12", 1'b1, 5'd12, 32'h0000_FF0F, 32'h0000_1108);
    run_idle();

    run_insn(1'b1, OPC_OP_IMM, F3_XOR, 7'b0, 5'd13, 32'hFFFF_0000, 32'd0, 32'h0000_FFFF, 32'h0000_110C);
    check_expect("xori", "XORI x13", 1'b1, 5'd13, 32'hFFFF_FFFF, 32'h0000_110C);
    run_idle();

    run_insn(1'b1, OPC_OP_IMM, F3_SLL, 7'b0, 5'd18, 32'd1, 32'd0, 32'd3, 32'h0000_1110);
    check_expect("slli", "SLLI x18, shamt=3", 1'b1, 5'd18, 32'd8, 32'h0000_1110);
    run_idle();

    run_insn(1'b1, OPC_OP_IMM, F3_SRL_SRA, 7'b0, 5'd19, 32'h8000_0000, 32'd0, 32'd4, 32'h0000_1114);
    check_expect("srli", "SRLI x19, shamt=4", 1'b1, 5'd19, 32'h0800_0000, 32'h0000_1114);
    run_idle();

    // SRAI: imm[11:0]={F7_SRA,shamt} = {7'h20,5'd4} = 12'h404 (ALU still uses imm[4:0]=4)
    run_insn(1'b1, OPC_OP_IMM, F3_SRL_SRA, F7_SRA, 5'd20, 32'h8000_0000, 32'd0, 32'h0000_0404, 32'h0000_1118);
    check_expect("srai", "SRAI x20, imm12=0x404, shamt=4", 1'b1, 5'd20, 32'hF800_0000, 32'h0000_1118);
    run_idle();

    // --- Wrong lane opcode ---
    run_insn(1'b1, OPC_LOAD, F3_LW, 7'b0, 5'd3, 32'd0, 32'd0, 32'd4, 32'h0000_2000);
    check_expect("load_reject", "LOAD on even lane -> no reg_write", 1'b0, 5'd3, alu_result, 32'h0000_2000);
    run_idle();

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "even_lane_tb failed");
    $finish;
  end

endmodule
