`timescale 1ns / 1ps

// Unit testbench for odd_lane: LW/SW, branches, jumps, LUI/AUIPC (RV32I).
module odd_lane_tb;

  import spu_lite_pkg::*;

  `include "tb_console.svh"

  logic        valid;
  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [4:0]  rd;
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;
  logic [31:0] imm;
  logic [31:0] pc;

  logic        branch_taken;
  logic [31:0] branch_target;
  logic        jump;
  logic [31:0] jump_target;
  logic        mem_read;
  logic        mem_write;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic [3:0]  mem_be;
  logic        reg_write;
  logic [4:0]  rd_out;
  logic [31:0] link_data;
  logic [31:0] wb_data;

  int pass_cnt;
  int fail_cnt;

  odd_lane dut (.*);

  task automatic check_mem(
    input string       name,
    input string       detail,
    input logic        exp_mem_read,
    input logic        exp_mem_write,
    input logic [31:0] exp_addr,
    input logic [31:0] exp_wdata,
    input logic [3:0]  exp_be
  );
    string got;
    if (valid !== 1'b1) begin
      tb_fail_detail(name, "valid=0 during check");
      fail_cnt++;
      return;
    end
    if (mem_read !== exp_mem_read || mem_write !== exp_mem_write ||
        mem_addr !== exp_addr || mem_wdata !== exp_wdata || mem_be !== exp_be) begin
      got = $sformatf("%s, got read=%0d write=%0d addr=%h wdata=%h be=%b",
        detail, mem_read, mem_write, mem_addr, mem_wdata, mem_be);
      tb_fail_detail(name, got);
      fail_cnt++;
    end else begin
      tb_pass_detail(name, detail);
      pass_cnt++;
    end
  endtask

  task automatic check_branch(
    input string       name,
    input string       detail,
    input logic        exp_taken,
    input logic [31:0] exp_target
  );
    string got;
    if (valid !== 1'b1) begin
      tb_fail_detail(name, "valid=0 during check");
      fail_cnt++;
      return;
    end
    if (branch_taken !== exp_taken || branch_target !== exp_target || jump !== 1'b0) begin
      got = $sformatf("%s, got taken=%0d target=%h jump=%0d",
        detail, branch_taken, branch_target, jump);
      tb_fail_detail(name, got);
      fail_cnt++;
    end else begin
      tb_pass_detail(name, detail);
      pass_cnt++;
    end
  endtask

  task automatic check_jump(
    input string       name,
    input string       detail,
    input logic        exp_jump,
    input logic [31:0] exp_target,
    input logic        exp_reg_write,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_link
  );
    string got;
    if (valid !== 1'b1) begin
      tb_fail_detail(name, "valid=0 during check");
      fail_cnt++;
      return;
    end
    if (jump !== exp_jump || jump_target !== exp_target ||
        reg_write !== exp_reg_write || rd_out !== exp_rd || link_data !== exp_link) begin
      got = $sformatf("%s, got jump=%0d tgt=%h reg_write=%0d rd=x%0d link=%h",
        detail, jump, jump_target, reg_write, rd_out, link_data);
      tb_fail_detail(name, got);
      fail_cnt++;
    end else begin
      tb_pass_detail(name, detail);
      pass_cnt++;
    end
  endtask

  task automatic check_lw(
    input string       name,
    input string       op_name,
    input logic [4:0]  rd_i,
    input logic [31:0] rs1,
    input logic [31:0] imm_i
  );
    string detail;
    valid    = 1'b1;
    opcode   = OPC_LOAD;
    funct3   = F3_LW;
    rd       = rd_i;
    rs1_data = rs1;
    rs2_data = 32'h0;
    imm      = imm_i;
    #1;
    detail = $sformatf("LW, rs1=%h, imm=%h, addr=%h, mem_be=1111, link=%h (rd=x%0d)",
      rs1, imm_i, rs1 + imm_i, pc + 32'd4, rd_i);
    if (valid !== 1'b1 || mem_read !== 1'b1 || mem_write !== 1'b0 ||
        mem_addr !== rs1 + imm_i || mem_be !== 4'b1111 ||
        reg_write !== (rd_i != 5'd0) || link_data !== pc + 32'd4) begin
      tb_fail_detail(name, $sformatf("%s (check failed)", detail));
      fail_cnt++;
    end else begin
      tb_pass_detail(name, detail);
      pass_cnt++;
    end
    valid = 1'b0;
    #1;
  endtask

  task automatic check_u_type(
    input string       name,
    input string       detail,
    input logic        exp_reg_write,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_wb
  );
    string got;
    if (valid !== 1'b1) begin
      tb_fail_detail(name, "valid=0 during check");
      fail_cnt++;
      return;
    end
    if (branch_taken || jump || mem_read || mem_write) begin
      tb_fail_detail(name, $sformatf("%s (unexpected branch/jump/mem)", detail));
      fail_cnt++;
      return;
    end
    if (reg_write !== exp_reg_write || rd_out !== exp_rd || wb_data !== exp_wb) begin
      got = $sformatf("%s, reg_write=%0d rd=x%0d wb=%h", detail, reg_write, rd_out, wb_data);
      tb_fail_detail(name, got);
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

  initial begin
    string detail;
    valid = 0;
    pc    = 32'h0000_1000;
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("odd_lane_tb - LW/SW, signed branch, jump");
    tb_info_msg("PASS line format: <test> | <op>, operands, behavior/result");

    // --- branches ---
    valid    = 1'b1;
    opcode   = OPC_BRANCH;
    funct3   = F3_BEQ;
    rd       = 5'd0;
    rs1_data = 32'd10;
    rs2_data = 32'd10;
    imm      = 32'd8;
    #1;
    detail = $sformatf("BEQ, rs1=%0d, rs2=%0d, pc=%h, imm=%0d -> taken, target=%h",
      rs1_data, rs2_data, pc, imm, pc + imm);
    check_branch("beq_taken", detail, 1'b1, pc + 32'd8);
    idle_cycle();

    valid    = 1'b1;
    opcode   = OPC_BRANCH;
    funct3   = F3_BEQ;
    rs1_data = 32'd1;
    rs2_data = 32'd2;
    imm      = 32'd16;
    #1;
    detail = $sformatf("BEQ, rs1=%0d, rs2=%0d -> not taken", rs1_data, rs2_data);
    check_branch("beq_nt", detail, 1'b0, pc + 32'd16);
    idle_cycle();

    valid    = 1'b1;
    opcode   = OPC_BRANCH;
    funct3   = F3_BNE;
    rs1_data = 32'd3;
    rs2_data = 32'd4;
    imm      = 32'd20;
    #1;
    detail = $sformatf("BNE, rs1=%0d, rs2=%0d -> taken, target=%h", rs1_data, rs2_data, pc + imm);
    check_branch("bne_taken", detail, 1'b1, pc + 32'd20);
    idle_cycle();

    valid    = 1'b1;
    opcode   = OPC_BRANCH;
    funct3   = F3_BLT;
    rs1_data = 32'hFFFF_FFFF;
    rs2_data = 32'd1;
    imm      = 32'd4;
    #1;
    detail = $sformatf("BLT, rs1=%h (signed -1), rs2=%0d -> taken", rs1_data, rs2_data);
    check_branch("blt_taken", detail, 1'b1, pc + 32'd4);
    idle_cycle();

    valid    = 1'b1;
    opcode   = OPC_BRANCH;
    funct3   = F3_BGE;
    rs1_data = 32'd1;
    rs2_data = 32'hFFFF_FFFF;
    imm      = 32'd8;
    #1;
    detail = $sformatf("BGE, rs1=%0d, rs2=%h (signed -1) -> taken", rs1_data, rs2_data);
    check_branch("bge_taken", detail, 1'b1, pc + 32'd8);
    idle_cycle();

    valid    = 1'b1;
    opcode   = OPC_BRANCH;
    funct3   = F3_BGE;
    rs1_data = 32'd1;
    rs2_data = 32'd5;
    imm      = 32'd12;
    #1;
    detail = $sformatf("BGE, rs1=%0d, rs2=%0d -> not taken", rs1_data, rs2_data);
    check_branch("bge_nt", detail, 1'b0, pc + 32'd12);
    idle_cycle();

    // --- loads (LW only) ---
    check_lw("lw", "LW", 5'd5, 32'h0000_2000, 32'd4);

    valid    = 1'b1;
    opcode   = OPC_LOAD;
    funct3   = F3_LW;
    rd       = 5'd0;
    rs1_data = 32'h0000_5000;
    imm      = 32'd0;
    #1;
    detail = "LW, rd=x0 -> reg_write=0";
    if (reg_write !== 1'b0) begin
      tb_fail_detail("lw_x0", detail);
      fail_cnt++;
    end else begin
      tb_pass_detail("lw_x0", detail);
      pass_cnt++;
    end
    idle_cycle();

    // --- stores (SW only) ---
    valid    = 1'b1;
    opcode   = OPC_STORE;
    funct3   = F3_SW;
    rd       = 5'd0;
    rs1_data = 32'h0000_6000;
    rs2_data = 32'hDEAD_BEEF;
    imm      = 32'd0;
    #1;
    detail = $sformatf("SW, rs1=%h, imm=%0d, wdata=%h, addr=%h, be=1111",
      rs1_data, imm, rs2_data, rs1_data + imm);
    check_mem("sw", detail, 1'b0, 1'b1, 32'h0000_6000, 32'hDEAD_BEEF, 4'b1111);
    idle_cycle();

    // --- jumps ---
    valid    = 1'b1;
    opcode   = OPC_JAL;
    funct3   = 3'b000;
    rd       = 5'd1;
    rs1_data = 32'h0;
    rs2_data = 32'h0;
    imm      = 32'h100;
    #1;
    detail = $sformatf("JAL, pc=%h, imm=%h -> target=%h, link=%h (rd=x%0d)",
      pc, imm, pc + imm, pc + 32'd4, rd);
    check_jump("jal", detail, 1'b1, pc + 32'h100, 1'b1, 5'd1, pc + 32'd4);
    idle_cycle();

    valid    = 1'b1;
    opcode   = OPC_JALR;
    funct3   = 3'b000;
    rd       = 5'd2;
    rs1_data = 32'h8000_0001;
    imm      = 32'h10;
    #1;
    detail = $sformatf("JALR, rs1=%h, imm=%h -> target=%h (LSB clear), link=%h",
      rs1_data, imm, 32'h8000_0010, pc + 32'd4);
    check_jump("jalr", detail, 1'b1, 32'h8000_0010, 1'b1, 5'd2, pc + 32'd4);
    idle_cycle();

    valid    = 1'b1;
    opcode   = OPC_JALR;
    funct3   = 3'b000;
    rd       = 5'd0;
    rs1_data = 32'h8000_0000;
    imm      = 32'd4;
    #1;
    detail = $sformatf("JALR, rs1=%h, imm=%0d, rd=x0 -> reg_write=0", rs1_data, imm);
    check_jump("jalr_x0", detail, 1'b1, 32'h8000_0004, 1'b0, 5'd0, pc + 32'd4);
    idle_cycle();

    // --- U-type (LUI / AUIPC) ---
    valid    = 1'b1;
    opcode   = OPC_LUI;
    funct3   = 3'b0;
    rd       = 5'd5;
    imm      = 32'h0004_5000;
    #1;
    detail = $sformatf("LUI, imm=%h -> wb=%h (rd=x%0d)", imm, imm, rd);
    check_u_type("lui", detail, 1'b1, 5'd5, 32'h0004_5000);
    idle_cycle();

    valid    = 1'b1;
    opcode   = OPC_AUIPC;
    rd       = 5'd6;
    imm      = 32'h0000_1000;
    #1;
    detail = $sformatf("AUIPC, pc=%h, imm=%h -> wb=%h", pc, imm, pc + imm);
    check_u_type("auipc", detail, 1'b1, 5'd6, pc + 32'h0000_1000);
    idle_cycle();

    valid    = 1'b1;
    opcode   = OPC_LUI;
    rd       = 5'd0;
    imm      = 32'h0000_1000;
    #1;
    detail = "LUI, rd=x0 -> reg_write=0";
    check_u_type("lui_x0", detail, 1'b0, 5'd0, 32'h0000_1000);
    idle_cycle();

    // --- invalid / idle ---
    valid    = 1'b1;
    opcode   = OPC_OP;
    funct3   = F3_ADD_SUB;
    rd       = 5'd3;
    rs1_data = 32'd1;
    rs2_data = 32'd2;
    imm      = 32'd0;
    #1;
    detail = "OP (ALU) on odd lane -> no mem/branch/jump/reg_write/wb";
    if (mem_read || mem_write || branch_taken || jump || reg_write) begin
      tb_fail_detail("alu_reject", detail);
      fail_cnt++;
    end else begin
      tb_pass_detail("alu_reject", detail);
      pass_cnt++;
    end
    idle_cycle();

    valid = 1'b0;
    opcode = OPC_BRANCH;
    #1;
    detail = "valid=0 -> no branch/mem/jump";
    if (branch_taken || jump || mem_read || mem_write) begin
      tb_fail_detail("idle", detail);
      fail_cnt++;
    end else begin
      tb_pass_detail("idle", detail);
      pass_cnt++;
    end

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "odd_lane_tb failed");
    $finish;
  end

endmodule
