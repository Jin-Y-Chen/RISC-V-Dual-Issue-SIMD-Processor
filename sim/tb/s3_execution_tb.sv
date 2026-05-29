`timescale 1ns / 1ps

module s3_execution_tb;

  import spu_lite_pkg::*;

  logic        even_valid, odd_valid;
  logic [6:0]  even_opcode, odd_opcode;
  logic [2:0]  even_funct3, odd_funct3;
  logic [6:0]  even_funct7;
  logic [4:0]  even_rd, odd_rd;
  logic [31:0] even_rs1_data, even_rs2_data, even_imm, even_pc;
  logic [31:0] odd_rs1_data, odd_rs2_data, odd_imm, odd_pc;
  vreg_t       even_vs1_data, even_vs2_data, odd_vs_data;

  logic        even_reg_write, odd_reg_write;
  logic [4:0]  even_rd_out, odd_rd_out;
  logic [31:0] even_alu_result, even_wb_data, odd_link_data;
  logic        even_vreg_write, odd_vreg_write;
  logic [2:0]  even_vd_out, odd_vd_out;
  vreg_t       even_vreg_result, odd_vec_mem_wdata;

  logic        odd_branch_taken, odd_jump, odd_mem_read, odd_mem_write;
  logic        odd_vec_mem_read, odd_vec_mem_write, odd_vec_addr_misaligned;
  logic [31:0] odd_branch_target, odd_jump_target, odd_mem_addr, odd_mem_wdata;
  logic [31:0] odd_vec_mem_addr;
  logic [3:0]  odd_mem_be;
  logic [15:0] odd_vec_mem_be;

  s3_execution dut (.*);

  function automatic instr_t enc_vec_alu(
    input logic [6:0] f7,
    input logic [2:0] f3,
    input logic [2:0] vd,
    input logic [2:0] vs1,
    input logic [2:0] vs2
  );
    return {f7, vs2, vs1, f3, vd, OPC_VEC_ALU};
  endfunction

  function automatic instr_t enc_vld128(
    input logic [11:0] imm12,
    input logic [4:0]  base,
    input logic [2:0]  vd
  );
    return {{20{imm12[11]}}, imm12, base, F3_VLD128, vd, OPC_VEC_MEM};
  endfunction

  task automatic check_eq32(input string name, input logic [31:0] a, input logic [31:0] b);
    if (a !== b) $error("%s: exp %h got %h", name, b, a);
    else $display("PASS: %s", name);
  endtask

  task automatic check_vreg_byte(
    input string name,
    input vreg_t   v,
    input int      idx,
    input logic [7:0] exp
  );
    if (v[idx*8 +: 8] !== exp)
      $error("%s[%0d]: exp %h got %h", name, idx, exp, v[idx*8 +: 8]);
    else
      $display("PASS: %s[%0d]", name, idx);
  endtask

  initial begin
    even_valid = 0;
    odd_valid  = 0;
    even_pc    = 32'h1000;
    odd_pc     = 32'h2000;

    // Scalar even: add
    #1;
    even_valid    = 1;
    even_opcode   = OPC_OP;
    even_funct3   = F3_ADD_SUB;
    even_funct7   = 7'b0;
    even_rd       = 5'd5;
    even_rs1_data = 32'd10;
    even_rs2_data = 32'd32;
    odd_valid     = 0;
    #1;
    check_eq32("scalar add", even_alu_result, 32'd42);

    // SIMD: vadd.vb v1, v2, v3  (16 x 8-bit lanes)
    even_opcode = OPC_VEC_ALU;
    even_funct7 = F7_VADD;
    even_funct3 = F3_VEC_B;
    even_rd     = 5'd1;
    for (int i = 0; i < 16; i++) begin
      even_vs1_data[i*8 +: 8] = 8'(i);
      even_vs2_data[i*8 +: 8] = 8'(1);
    end
    #1;
    if (!even_vreg_write || even_vd_out !== 3'd1)
      $error("vadd.vb write control");
    check_vreg_byte("vadd.vb", even_vreg_result, 0, 8'd1);
    check_vreg_byte("vadd.vb", even_vreg_result, 5, 8'd6);

    // SIMD: vld128 v2, 0(x10) on odd lane
    even_valid  = 0;
    odd_valid   = 1;
    odd_opcode  = OPC_VEC_MEM;
    odd_funct3  = F3_VLD128;
    odd_rd      = 5'd2;
    odd_rs1_data = 32'h100;
    odd_imm     = 32'd0;
    #1;
    if (!odd_vec_mem_read || !odd_vreg_write || odd_vd_out !== 3'd2)
      $error("vld128 control");
    check_eq32("vld128 addr aligned", odd_vec_mem_addr, 32'h100);
    if (odd_vec_mem_be !== 16'hFFFF)
      $error("vld128 mem_be");

    // SIMD: vst128 v4, 16(x11)
    odd_funct3   = F3_VST128;
    odd_rd       = 5'd0;
    odd_rs1_data = 32'h110;
    odd_imm      = 32'd16;
    for (int k = 0; k < VLEN; k++)
      odd_vs_data[k] = 8'hAA;
    #1;
    if (!odd_vec_mem_write)
      $error("vst128 write");
    check_eq32("vst128 addr", odd_vec_mem_addr, 32'h120);

    $display("s3_execution_tb done");
    $finish;
  end

endmodule
