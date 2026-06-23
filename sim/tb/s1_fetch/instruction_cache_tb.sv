`timescale 1ns / 1ps

// instruction_cache_tb - dual fetch via cache_pkg bank (16-way set lookup).
module instruction_cache_tb;

  import rv_dis_pkg::*;
  import cache_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;
  localparam int INDEX_W    = 6;  // 64 insn slots => 256 B address span for TB

  localparam cache_struct_t CACHE = cache_struct_build#(.DATA_W(32), .INDEX_W(INDEX_W))();

  localparam logic [31:0] PC0      = 32'h0000_0080;
  localparam logic [31:0] PC1      = 32'h0000_0084;
  localparam logic [31:0] INSN_I0  = 32'h0000_0013;  // addi x0,x0,0
  localparam logic [31:0] INSN_I1  = 32'h0010_0093;  // addi x1,x1,1
  localparam logic [31:0] PC_LINE0 = 32'h0000_001C;
  localparam logic [31:0] PC_LINE1 = 32'h0000_0020;
  localparam logic [31:0] INSN_L0  = 32'h0020_0213;  // addi x4,x4,1
  localparam logic [31:0] INSN_L1  = 32'h0030_0313;  // addi x6,x6,1

  logic        clk;
  logic        rst_n;

  logic [31:0] pc0;
  logic [31:0] pc1;
  logic [31:0] instr0;
  logic [31:0] instr1;

  int pass_cnt;
  int fail_cnt;

  instruction_cache #(
    .INDEX_W (INDEX_W)
  ) dut (.*);

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic preload_word(input logic [31:0] byte_pc, input logic [31:0] word);
    dut.bank[pc_set(byte_pc, CACHE)][pc_way(byte_pc, CACHE)] =
      cache_set_write#(32)(1'b1, word);
  endtask

  task automatic drive_fetch(input logic [31:0] pc0_v, input logic [31:0] pc1_v);
    pc0 = pc0_v;
    pc1 = pc1_v;
    #1step;
  endtask

  task automatic check_fetch(
    input string       name,
    input string       detail,
    input logic [31:0] exp_i0,
    input logic [31:0] exp_i1
  );
    bit pass;
    #1step;
    pass = (instr0 === exp_i0) && (instr1 === exp_i1);
    tb_report_open(pass, name, detail);
    tb_field_u32("instr0", instr0, exp_i0);
    tb_field_u32("instr1", instr1, exp_i1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("instruction_cache_tb - dual read, cache_pkg bank");

    rst_n = 1'b0;
    tick();
    rst_n = 1'b1;
    tick();

    preload_word(PC0, INSN_I0);
    preload_word(PC1, INSN_I1);
    preload_word(PC_LINE0, INSN_L0);
    preload_word(PC_LINE1, INSN_L1);

    drive_fetch(PC0, PC1);
    check_fetch("same_line_pair",
                "pc0/pc1 in same set, different ways",
                INSN_I0, INSN_I1);

    drive_fetch(PC_LINE0, PC_LINE1);
    check_fetch("span_two_lines",
                "pc0 at 0x1C, pc1 at 0x20",
                INSN_L0, INSN_L1);

    drive_fetch(PC0, PC1);
    check_fetch("repeat_read",
                "same addresses return same words",
                INSN_I0, INSN_I1);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "instruction_cache_tb failed");
    $finish;
  end

endmodule
