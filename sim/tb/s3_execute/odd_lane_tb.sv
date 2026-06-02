`timescale 1ns / 1ps

// odd_lane_tb — DUT vs hand-written expected (decoder_tb-style run_insn + check_expect).
module odd_lane_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  logic        valid;
  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [4:0]  rd;
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;
  logic [31:0] imm;
  logic [31:0] pc;

  logic        brch_taken;
  logic [31:0] brch_target;
  logic        jmp;
  logic [31:0] jmp_target;
  logic        mem_read;
  logic        mem_write;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic [3:0]  mem_besel;
  logic        reg_write;
  logic [4:0]  rd_out;
  logic [31:0] link_data;
  logic [31:0] wb_data;

  int pass_cnt;
  int fail_cnt;

  odd_lane dut (.*);

  task automatic run_insn(
    input logic        valid_i,
    input logic [6:0]  opcode_i,
    input logic [2:0]  funct3_i,
    input logic [4:0]  rd_i,
    input logic [31:0] rs1_i,
    input logic [31:0] rs2_i,
    input logic [31:0] imm_i,
    input logic [31:0] pc_i
  );
    valid    = valid_i;
    opcode   = opcode_i;
    funct3   = funct3_i;
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
    input logic        exp_brch_taken,
    input logic [31:0] exp_brch_target,
    input logic        exp_jmp,
    input logic [31:0] exp_jmp_target,
    input logic        exp_mem_read,
    input logic        exp_mem_write,
    input logic [31:0] exp_mem_addr,
    input logic [31:0] exp_mem_wdata,
    input logic [3:0]  exp_mem_besel,
    input logic        exp_reg_write,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_link,
    input logic [31:0] exp_wb
  );
    bit pass;
    if (valid !== 1'b1) begin
      tb_fail_field_bit(name, detail, "valid", valid, 1'b1);
      fail_cnt++;
      return;
    end
    pass = (brch_taken === exp_brch_taken && brch_target === exp_brch_target &&
            jmp === exp_jmp && jmp_target === exp_jmp_target &&
            mem_read === exp_mem_read && mem_write === exp_mem_write &&
            mem_addr === exp_mem_addr && mem_wdata === exp_mem_wdata &&
            mem_besel === exp_mem_besel &&
            reg_write === exp_reg_write && rd_out === exp_rd &&
            link_data === exp_link && wb_data === exp_wb);
    tb_report_open(pass, name, detail);
    tb_field_bit("brch_taken", brch_taken, exp_brch_taken);
    tb_field_u32("brch_target", brch_target, exp_brch_target);
    tb_field_bit("jmp", jmp, exp_jmp);
    tb_field_u32("jmp_target", jmp_target, exp_jmp_target);
    tb_field_bit("mem_read", mem_read, exp_mem_read);
    tb_field_bit("mem_write", mem_write, exp_mem_write);
    tb_field_u32("mem_addr", mem_addr, exp_mem_addr);
    tb_field_u32("mem_wdata", mem_wdata, exp_mem_wdata);
    tb_field_be("mem_besel", mem_besel, exp_mem_besel);
    tb_field_bit("reg_write", reg_write, exp_reg_write);
    tb_field_u5("rd_out", rd_out, exp_rd);
    tb_field_u32("link_data", link_data, exp_link);
    tb_field_u32("wb_data", wb_data, exp_wb);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic run_idle;
    valid = 1'b0;
    #1;
  endtask

  task automatic check_expect_quiet(input string name, input string detail);
    bit pass;
    pass = !(brch_taken || jmp || mem_read || mem_write || reg_write);
    tb_report_open(pass, name, detail);
    tb_field_bit("brch_taken", brch_taken, 1'b0);
    tb_field_bit("jmp", jmp, 1'b0);
    tb_field_bit("mem_read", mem_read, 1'b0);
    tb_field_bit("mem_write", mem_write, 1'b0);
    tb_field_bit("reg_write", reg_write, 1'b0);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    pc       = 32'h0000_1000;

    tb_banner("odd_lane_tb - LW/SW, branch, jump, U-type");
    tb_info_msg("Golden values explicit per test (run_insn + check_expect)");

    // --- Branches ---
    run_insn(1'b1, OPC_BRANCH, F3_BEQ, 5'd0, 32'd10, 32'd10, 32'd8, pc);
    check_expect("beq_taken", "BEQ x10==x10, imm=8 -> taken",
      1'b1, pc + 32'd8, 1'b0, jmp_target,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b0, 5'd0, link_data, wb_data);
    run_idle();

    run_insn(1'b1, OPC_BRANCH, F3_BEQ, 5'd0, 32'd1, 32'd2, 32'd16, pc);
    check_expect("beq_nt", "BEQ x1!=x2 -> not taken",
      1'b0, pc + 32'd16, 1'b0, jmp_target,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b0, 5'd0, link_data, wb_data);
    run_idle();

    run_insn(1'b1, OPC_BRANCH, F3_BNE, 5'd0, 32'd3, 32'd4, 32'd20, pc);
    check_expect("bne_taken", "BNE x3!=x4 -> taken",
      1'b1, pc + 32'd20, 1'b0, jmp_target,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b0, 5'd0, link_data, wb_data);
    run_idle();

    run_insn(1'b1, OPC_BRANCH, F3_BLT, 5'd0, 32'hFFFF_FFFF, 32'd1, 32'd4, pc);
    check_expect("blt_taken", "BLT signed(-1)<1 -> taken",
      1'b1, pc + 32'd4, 1'b0, jmp_target,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b0, 5'd0, link_data, wb_data);
    run_idle();

    run_insn(1'b1, OPC_BRANCH, F3_BGE, 5'd0, 32'd1, 32'hFFFF_FFFF, 32'd8, pc);
    check_expect("bge_taken", "BGE signed(1)>=(-1) -> taken",
      1'b1, pc + 32'd8, 1'b0, jmp_target,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b0, 5'd0, link_data, wb_data);
    run_idle();

    run_insn(1'b1, OPC_BRANCH, F3_BGE, 5'd0, 32'd1, 32'd5, 32'd12, pc);
    check_expect("bge_nt", "BGE 1>=5 -> not taken",
      1'b0, pc + 32'd12, 1'b0, jmp_target,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b0, 5'd0, link_data, wb_data);
    run_idle();

    // --- Load ---
    run_insn(1'b1, OPC_LOAD, F3_LW, 5'd5, 32'h0000_2000, 32'd0, 32'd4, pc);
    check_expect("lw", "LW x5, 4(x2000)",
      1'b0, brch_target, 1'b0, jmp_target,
      1'b1, 1'b0, 32'h0000_2004, mem_wdata, 4'b1111,
      1'b1, 5'd5, pc + 32'd4, wb_data);
    run_idle();

    run_insn(1'b1, OPC_LOAD, F3_LW, 5'd0, 32'h0000_5000, 32'd0, 32'd0, pc);
    check_expect("lw_x0", "LW x0 -> reg_write=0",
      1'b0, brch_target, 1'b0, jmp_target,
      1'b1, 1'b0, 32'h0000_5000, mem_wdata, 4'b1111,
      1'b0, 5'd0, pc + 32'd4, wb_data);
    run_idle();

    // --- Store ---
    run_insn(1'b1, OPC_STORE, F3_SW, 5'd0, 32'h0000_6000, 32'hDEAD_BEEF, 32'd0, pc);
    check_expect("sw", "SW xDEAD_BEEF, 0(x6000)",
      1'b0, brch_target, 1'b0, jmp_target,
      1'b0, 1'b1, 32'h0000_6000, 32'hDEAD_BEEF, 4'b1111,
      1'b0, 5'd0, link_data, wb_data);
    run_idle();

    // --- Jumps ---
    run_insn(1'b1, OPC_JAL, 3'b000, 5'd1, 32'd0, 32'd0, 32'h100, pc);
    check_expect("jal", "JAL x1, +0x100",
      1'b0, brch_target, 1'b1, pc + 32'h100,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b1, 5'd1, pc + 32'd4, wb_data);
    run_idle();

    run_insn(1'b1, OPC_JALR, 3'b000, 5'd2, 32'h8000_0001, 32'd0, 32'h10, pc);
    check_expect("jalr", "JALR x2, 0x10(x1) LSB clear",
      1'b0, brch_target, 1'b1, 32'h8000_0010,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b1, 5'd2, pc + 32'd4, wb_data);
    run_idle();

    run_insn(1'b1, OPC_JALR, 3'b000, 5'd0, 32'h8000_0000, 32'd0, 32'd4, pc);
    check_expect("jalr_x0", "JALR x0 -> no reg_write",
      1'b0, brch_target, 1'b1, 32'h8000_0004,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b0, 5'd0, pc + 32'd4, wb_data);
    run_idle();

    // --- U-type ---
    run_insn(1'b1, OPC_LUI, 3'b0, 5'd5, 32'd0, 32'd0, 32'h0004_5000, pc);
    check_expect("lui", "LUI x5, 0x45000",
      1'b0, brch_target, 1'b0, jmp_target,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b1, 5'd5, link_data, 32'h0004_5000);
    run_idle();

    run_insn(1'b1, OPC_AUIPC, 3'b0, 5'd6, 32'd0, 32'd0, 32'h0000_1000, pc);
    check_expect("auipc", "AUIPC x6, +0x1000",
      1'b0, brch_target, 1'b0, jmp_target,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b1, 5'd6, link_data, pc + 32'h0000_1000);
    run_idle();

    run_insn(1'b1, OPC_LUI, 3'b0, 5'd0, 32'd0, 32'd0, 32'h0000_1000, pc);
    check_expect("lui_x0", "LUI x0 -> reg_write=0",
      1'b0, brch_target, 1'b0, jmp_target,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      1'b0, 5'd0, link_data, 32'h0000_1000);
    run_idle();

    // --- Wrong lane (even-lane opcode): no branch/jump/mem/reg_write; rd_out still passthrough rd
    run_insn(1'b1, OPC_OP, F3_ADD_SUB, 5'd3, 32'd1, 32'd2, 32'd0, pc);
    check_expect("alu_reject", "OP on odd lane -> no activity",
      1'b0, pc + 32'd0, 1'b0, pc + 32'd0,
      1'b0, 1'b0, 32'd1, 32'd2, 4'b0000,
      1'b0, 5'd3, pc + 32'd4, 32'd0);
    run_idle();

    run_idle();
    check_expect_quiet("idle", "valid=0 -> no branch/mem/jump/reg_write");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "odd_lane_tb failed");
    $finish;
  end

endmodule
