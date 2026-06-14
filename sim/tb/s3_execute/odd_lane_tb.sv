`timescale 1ns / 1ps

// odd_lane_tb — DUT vs hand-written expected (decoder_tb-style run_insn + check_expect).
module odd_lane_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  logic        enable;
  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;
  logic [31:0] imm;
  logic [31:0] pc;

  logic        brch_taken;
  logic [31:0] brch_pc;
  logic        mem_en;
  logic        mem_act;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic [3:0]  mem_besel;
  logic [31:0] link_pc;
  logic [31:0] wb_data;

  int pass_cnt;
  int fail_cnt;

  odd_lane dut (.*);

  task automatic run_insn(
    input logic        enable_i,
    input logic [6:0]  opcode_i,
    input logic [2:0]  funct3_i,
    input logic [31:0] rs1_i,
    input logic [31:0] rs2_i,
    input logic [31:0] imm_i,
    input logic [31:0] pc_i
  );
    enable   = enable_i;
    opcode   = opcode_i;
    funct3   = funct3_i;
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
    input logic [31:0] exp_brch_pc,
    input logic        exp_mem_en,
    input logic        exp_mem_act,
    input logic [31:0] exp_mem_addr,
    input logic [31:0] exp_mem_wdata,
    input logic [3:0]  exp_mem_besel,
    input logic [31:0] exp_link,
    input logic [31:0] exp_wb
  );
    bit pass;
    if (enable !== 1'b1) begin
      tb_fail_field_bit(name, detail, "enable", enable, 1'b1);
      fail_cnt++;
      return;
    end
    pass = (brch_taken === exp_brch_taken && brch_pc === exp_brch_pc &&
            mem_en === exp_mem_en && mem_act === exp_mem_act &&
            mem_addr === exp_mem_addr && mem_wdata === exp_mem_wdata &&
            mem_besel === exp_mem_besel &&
            link_pc === exp_link && wb_data === exp_wb);
    tb_report_open(pass, name, detail);
    tb_field_bit("brch_taken", brch_taken, exp_brch_taken);
    tb_field_u32("brch_pc", brch_pc, exp_brch_pc);
    tb_field_bit("mem_en", mem_en, exp_mem_en);
    tb_field_bit("mem_act", mem_act, exp_mem_act);
    tb_field_u32("mem_addr", mem_addr, exp_mem_addr);
    tb_field_u32("mem_wdata", mem_wdata, exp_mem_wdata);
    tb_field_be("mem_besel", mem_besel, exp_mem_besel);
    tb_field_u32("link_pc", link_pc, exp_link);
    tb_field_u32("wb_data", wb_data, exp_wb);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic run_idle;
    enable = 1'b0;
    #1;
  endtask

  task automatic check_expect_quiet(input string name, input string detail);
    bit pass;
    pass = !(brch_taken || mem_en);
    tb_report_open(pass, name, detail);
    tb_field_bit("brch_taken", brch_taken, 1'b0);
    tb_field_bit("mem_en", mem_en, 1'b0);
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
    run_insn(1'b1, OPC_BRANCH, F3_BEQ, 32'd10, 32'd10, 32'd8, pc);
    check_expect("beq_taken", "BEQ x10==x10, imm=8 -> taken",
      1'b1, pc + 32'd8,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      link_pc, wb_data);
    run_idle();

    run_insn(1'b1, OPC_BRANCH, F3_BEQ, 32'd1, 32'd2, 32'd16, pc);
    check_expect("beq_nt", "BEQ x1!=x2 -> not taken",
      1'b0, pc + 32'd16,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      link_pc, wb_data);
    run_idle();

    run_insn(1'b1, OPC_BRANCH, F3_BNE, 32'd3, 32'd4, 32'd20, pc);
    check_expect("bne_taken", "BNE x3!=x4 -> taken",
      1'b1, pc + 32'd20,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      link_pc, wb_data);
    run_idle();

    run_insn(1'b1, OPC_BRANCH, F3_BLT, 32'hFFFF_FFFF, 32'd1, 32'd4, pc);
    check_expect("blt_taken", "BLT signed(-1)<1 -> taken",
      1'b1, pc + 32'd4,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      link_pc, wb_data);
    run_idle();

    run_insn(1'b1, OPC_BRANCH, F3_BGE, 32'd1, 32'hFFFF_FFFF, 32'd8, pc);
    check_expect("bge_taken", "BGE signed(1)>=(-1) -> taken",
      1'b1, pc + 32'd8,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      link_pc, wb_data);
    run_idle();

    run_insn(1'b1, OPC_BRANCH, F3_BGE, 32'd1, 32'd5, 32'd12, pc);
    check_expect("bge_nt", "BGE 1>=5 -> not taken",
      1'b0, pc + 32'd12,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      link_pc, wb_data);
    run_idle();

    // --- Load ---
    run_insn(1'b1, OPC_LOAD, F3_LW, 32'h0000_2000, 32'd0, 32'd4, pc);
    check_expect("lw", "LW 4(x2000)",
      1'b0, brch_pc,
      1'b1, 1'b0, 32'h0000_2004, mem_wdata, 4'b1111,
      pc + 32'd4, wb_data);
    run_idle();

    // --- Store ---
    run_insn(1'b1, OPC_STORE, F3_SW, 32'h0000_6000, 32'hDEAD_BEEF, 32'd0, pc);
    check_expect("sw", "SW xDEAD_BEEF, 0(x6000)",
      1'b0, brch_pc,
      1'b1, 1'b1, 32'h0000_6000, 32'hDEAD_BEEF, 4'b1111,
      link_pc, wb_data);
    run_idle();

    // --- Jumps ---
    run_insn(1'b1, OPC_JAL, 3'b000, 32'd0, 32'd0, 32'h100, pc);
    check_expect("jal", "JAL +0x100",
      1'b1, pc + 32'h100,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      pc + 32'd4, wb_data);
    run_idle();

    run_insn(1'b1, OPC_JALR, 3'b000, 32'h8000_0001, 32'd0, 32'h10, pc);
    check_expect("jalr", "JALR 0x10(x1) LSB clear",
      1'b1, 32'h8000_0010,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      pc + 32'd4, wb_data);
    run_idle();

    // --- U-type ---
    run_insn(1'b1, OPC_LUI, 3'b0, 32'd0, 32'd0, 32'h0004_5000, pc);
    check_expect("lui", "LUI 0x45000",
      1'b0, brch_pc,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      link_pc, 32'h0004_5000);
    run_idle();

    run_insn(1'b1, OPC_AUIPC, 3'b0, 32'd0, 32'd0, 32'h0000_1000, pc);
    check_expect("auipc", "AUIPC +0x1000",
      1'b0, brch_pc,
      1'b0, 1'b0, mem_addr, mem_wdata, mem_besel,
      link_pc, pc + 32'h0000_1000);
    run_idle();

    // --- Wrong lane (even-lane opcode): no brch_taken/mem/reg_write
    run_insn(1'b1, OPC_OP, F3_ADD_SUB, 32'd1, 32'd2, 32'd0, pc);
    check_expect("alu_reject", "OP on odd lane -> no activity",
      1'b0, pc + 32'd0,
      1'b0, 1'b0, 32'd1, 32'd2, 4'b0000,
      pc + 32'd4, 32'd0);
    run_idle();

    run_idle();
    check_expect_quiet("idle", "enable=0 -> no brch_taken/mem/reg_write");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "odd_lane_tb failed");
    $finish;
  end

endmodule
