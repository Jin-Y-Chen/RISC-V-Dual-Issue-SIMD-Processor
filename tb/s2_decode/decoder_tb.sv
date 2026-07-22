`timescale 1ns / 1ps

// decoder_tb - DUT vs gm/decoder_gm.sv (opcode/funct3 control LUTs).

import rv_dis_pkg::*;

`include "../include/tb_console.svh"

module decoder_tb;

  logic [31:0] instr;

  logic        valid, lane_sel, brch_en, jump_en, store_en;
  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [4:0]  rd_addr, rs1_addr, rs2_addr;
  logic [31:0] imm;
  logic        rs1_use, rs2_use, reg_write;

  logic        ref_valid, ref_lane_sel, ref_brch_en, ref_jump_en, ref_store_en;
  logic [6:0]  ref_opcode;
  logic [2:0]  ref_funct3;
  logic [6:0]  ref_funct7;
  logic [4:0]  ref_rd_addr, ref_rs1_addr, ref_rs2_addr;
  logic [31:0] ref_imm;
  logic        ref_rs1_use, ref_rs2_use, ref_reg_write;

  int pass_cnt;
  int fail_cnt;

  decoder dut (
    .instr     (instr),
    .valid     (valid),
    .lane_sel  (lane_sel),
    .brch_en   (brch_en),
    .jump_en   (jump_en),
    .store_en  (store_en),
    .opcode    (opcode),
    .funct3    (funct3),
    .funct7    (funct7),
    .rd_addr   (rd_addr),
    .rs1_addr  (rs1_addr),
    .rs2_addr  (rs2_addr),
    .imm       (imm),
    .rs1_use   (rs1_use),
    .rs2_use   (rs2_use),
    .reg_write (reg_write)
  );

  decoder_gm u_decoder_gm (
    .instr     (instr),
    .valid     (ref_valid),
    .lane_sel  (ref_lane_sel),
    .brch_en   (ref_brch_en),
    .jump_en   (ref_jump_en),
    .store_en  (ref_store_en),
    .opcode    (ref_opcode),
    .funct3    (ref_funct3),
    .funct7    (ref_funct7),
    .rd_addr   (ref_rd_addr),
    .rs1_addr  (ref_rs1_addr),
    .rs2_addr  (ref_rs2_addr),
    .imm       (ref_imm),
    .rs1_use   (ref_rs1_use),
    .rs2_use   (ref_rs2_use),
    .reg_write (ref_reg_write)
  );

  task automatic check_decode(input string name, input string detail);
    bit pass;
    pass = (valid === ref_valid) && (lane_sel === ref_lane_sel) &&
           (brch_en === ref_brch_en) && (jump_en === ref_jump_en) &&
           (store_en === ref_store_en) &&
           (opcode === ref_opcode) && (funct3 === ref_funct3) &&
           (funct7 === ref_funct7) && (rd_addr === ref_rd_addr) &&
           (rs1_addr === ref_rs1_addr) && (rs2_addr === ref_rs2_addr) && (imm === ref_imm) &&
           (rs1_use === ref_rs1_use) && (rs2_use === ref_rs2_use) &&
           (reg_write === ref_reg_write);
    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_u32("instr", instr);
    $display("");
    tb_log_section("check");
    tb_field_bit("valid", valid, ref_valid);
    tb_field_lane("lane_sel", lane_sel, ref_lane_sel);
    tb_field_bit("brch_en", brch_en, ref_brch_en);
    tb_field_bit("jump_en", jump_en, ref_jump_en);
    tb_field_bit("store_en", store_en, ref_store_en);
    tb_field_op7("opcode", opcode, ref_opcode);
    tb_field_f3("funct3", funct3, ref_funct3);
    tb_field_f7("funct7", funct7, ref_funct7);
    tb_field_u5("rd_addr", rd_addr, ref_rd_addr);
    tb_field_u5("rs1_addr", rs1_addr, ref_rs1_addr);
    tb_field_u5("rs2_addr", rs2_addr, ref_rs2_addr);
    tb_field_u32("imm", imm, ref_imm);
    tb_field_bit("rs1_use", rs1_use, ref_rs1_use);
    tb_field_bit("rs2_use", rs2_use, ref_rs2_use);
    tb_field_bit("reg_write", reg_write, ref_reg_write);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic run_check(
    input logic [31:0] insn_i,
    input string       name,
    input string       detail
  );
    instr = insn_i;
    #0;
    check_decode(name, detail);
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("decoder_tb: DUT vs decoder_gm.sv");

    run_check(32'h0046_8613, "addi",  "ADDI x12,x13,+4");
    run_check(32'h0027_9713, "slli",  "SLLI x14,x15,2");
    run_check(32'h0018_D813, "srli",  "SRLI x16,x17,1");
    run_check(32'h4039_D913, "srai",  "SRAI x18,x19,3");
    run_check(32'h00AA_AA13, "slti",  "SLTI x20,x21,10");
    run_check(32'h0FFB_CB13, "xori",  "XORI x22,x23,0xFF");
    run_check(32'h00FC_EC13, "ori",   "ORI x24,x25,15");
    run_check(32'h00FD_FD13, "andi",  "ANDI x26,x27,15");
    run_check(32'h001E_0013, "addi_x0", "ADDI x0,x28,1");

    run_check(32'h0094_03B3, "add", "ADD x7,x8,x9");
    run_check(32'h40C5_8533, "sub", "SUB x10,x11,x12");
    run_check(32'h00F7_16B3, "sll", "SLL x13,x14,x15");
    run_check(32'h0128_A833, "slt", "SLT x16,x17,x18");
    run_check(32'h015A_49B3, "xor", "XOR x19,x20,x21");
    run_check(32'h018B_DB33, "srl", "SRL x22,x23,x24");
    run_check(32'h41BD_5CB3, "sra", "SRA x25,x26,x27");
    run_check(32'h01EE_EE33, "or",  "OR x28,x29,x30");
    run_check(32'h0062_FFB3, "and", "AND x31,x5,x6");

    run_check(32'h0086_2583, "lw", "LW x11,8(x12)");
    run_check(32'h00D7_2223, "sw", "SW x13,4(x14)");

    run_check(32'h0107_8863, "beq", "BEQ x15,x16,+16");
    run_check(32'h0128_9863, "bne", "BNE x17,x18,+16");
    run_check(32'h0149_C863, "blt", "BLT x19,x20,+16");
    run_check(32'h016A_D863, "bge", "BGE x21,x22,+16");

    run_check(32'h0080_0BEF, "jal",   "JAL x23,+8");
    run_check(32'h000C_8C67, "jalr",  "JALR x24,0(x25)");
    run_check(32'h1234_5D37, "lui",   "LUI x26,0x12345");
    run_check(32'h0000_1D97, "auipc", "AUIPC x27,1");

    instr = 32'h0086_2583;
    instr[14:12] = 3'b000;
    #0;
    check_decode("lb", "LB funct3 illegal");

    instr = 32'h0000_0023;
    instr[6:0]   = 7'b0100011;
    instr[14:12] = 3'b001;
    #0;
    check_decode("sh", "SH funct3 illegal");

    run_check(32'hFFFF_FFFF, "bad_opcode", "unknown opcode");
    run_check(32'h0000_0000, "flush_zero", "flush bubble illegal insn");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "decoder_tb failed");
    $finish;
  end

endmodule
