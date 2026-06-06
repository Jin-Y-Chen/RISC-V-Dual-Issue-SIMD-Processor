`timescale 1ns / 1ps

// ex_mem_tb — per-lane EX/MEM (decoder_tb-style run_insn + check_expect).
module ex_mem_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic clk;
  logic rst_n;
  logic stall_even;
  logic stall_odd;
  logic flush_even;
  logic flush_odd;

  logic        even_valid_ex;
  logic        even_reg_write_ex;
  logic [4:0]  even_rd_ex;
  logic [31:0] even_alu_result_ex;
  logic [31:0] even_pc_ex;

  logic        even_valid_mem;
  logic        even_reg_write_mem;
  logic [4:0]  even_rd_mem;
  logic [31:0] even_alu_result_mem;
  logic [31:0] even_pc_mem;

  logic        odd_valid_ex;
  logic        odd_reg_write_ex;
  logic [4:0]  odd_rd_ex;
  logic [31:0] odd_link_data_ex;
  logic [31:0] odd_wb_data_ex;
  logic        odd_mem_read_ex;
  logic        odd_mem_write_ex;
  logic [31:0] odd_mem_addr_ex;
  logic [31:0] odd_mem_wdata_ex;
  logic [3:0]  odd_mem_besel_ex;
  logic        odd_brch_taken_ex;
  logic [31:0] odd_brch_target_ex;
  logic        odd_jmp_ex;
  logic [31:0] odd_jmp_target_ex;

  logic        odd_valid_mem;
  logic        odd_reg_write_mem;
  logic [4:0]  odd_rd_mem;
  logic [31:0] odd_link_data_mem;
  logic [31:0] odd_wb_data_mem;
  logic        odd_mem_read_mem;
  logic        odd_mem_write_mem;
  logic [31:0] odd_mem_addr_mem;
  logic [31:0] odd_mem_wdata_mem;
  logic [3:0]  odd_mem_besel_mem;
  logic        odd_brch_taken_mem;
  logic [31:0] odd_brch_target_mem;
  logic        odd_jmp_mem;
  logic [31:0] odd_jmp_target_mem;

  int pass_cnt;
  int fail_cnt;

  ex_mem_even u_ex_mem_even (
    .clk            (clk),
    .rst_n          (rst_n),
    .stall_even     (stall_even),
    .flush_even     (flush_even),
    .valid_ex       (even_valid_ex),
    .reg_write_ex   (even_reg_write_ex),
    .rd_ex          (even_rd_ex),
    .alu_result_ex  (even_alu_result_ex),
    .pc_ex          (even_pc_ex),
    .valid_mem      (even_valid_mem),
    .reg_write_mem  (even_reg_write_mem),
    .rd_mem         (even_rd_mem),
    .alu_result_mem (even_alu_result_mem),
    .pc_mem         (even_pc_mem)
  );

  ex_mem_odd u_ex_mem_odd (
    .clk               (clk),
    .rst_n             (rst_n),
    .stall_odd         (stall_odd),
    .flush_odd         (flush_odd),
    .valid_ex          (odd_valid_ex),
    .reg_write_ex      (odd_reg_write_ex),
    .rd_ex             (odd_rd_ex),
    .link_data_ex      (odd_link_data_ex),
    .wb_data_ex        (odd_wb_data_ex),
    .mem_read_ex       (odd_mem_read_ex),
    .mem_write_ex      (odd_mem_write_ex),
    .mem_addr_ex       (odd_mem_addr_ex),
    .mem_wdata_ex      (odd_mem_wdata_ex),
    .mem_besel_ex      (odd_mem_besel_ex),
    .brch_taken_ex     (odd_brch_taken_ex),
    .brch_target_ex    (odd_brch_target_ex),
    .jmp_ex            (odd_jmp_ex),
    .jmp_target_ex     (odd_jmp_target_ex),
    .valid_mem         (odd_valid_mem),
    .reg_write_mem     (odd_reg_write_mem),
    .rd_mem            (odd_rd_mem),
    .link_data_mem     (odd_link_data_mem),
    .wb_data_mem       (odd_wb_data_mem),
    .mem_read_mem      (odd_mem_read_mem),
    .mem_write_mem     (odd_mem_write_mem),
    .mem_addr_mem      (odd_mem_addr_mem),
    .mem_wdata_mem     (odd_mem_wdata_mem),
    .mem_besel_mem     (odd_mem_besel_mem),
    .brch_taken_mem    (odd_brch_taken_mem),
    .brch_target_mem   (odd_brch_target_mem),
    .jmp_mem           (odd_jmp_mem),
    .jmp_target_mem    (odd_jmp_target_mem)
  );

  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic run_insn_even(
    input logic        valid_i,
    input logic        reg_write_i,
    input logic [4:0]  rd_i,
    input logic [31:0] alu_result_i,
    input logic [31:0] pc_i
  );
    even_valid_ex      = valid_i;
    even_reg_write_ex  = reg_write_i;
    even_rd_ex         = rd_i;
    even_alu_result_ex = alu_result_i;
    even_pc_ex         = pc_i;
    tick();
  endtask

  task automatic run_insn_odd(
    input logic        valid_i,
    input logic        reg_write_i,
    input logic [4:0]  rd_i,
    input logic [31:0] link_i,
    input logic [31:0] wb_i,
    input logic        mem_read_i,
    input logic        mem_write_i,
    input logic [31:0] mem_addr_i,
    input logic [31:0] mem_wdata_i,
    input logic [3:0]  mem_besel_i,
    input logic        brch_taken_i,
    input logic [31:0] brch_target_i,
    input logic        jmp_i,
    input logic [31:0] jmp_target_i
  );
    odd_valid_ex        = valid_i;
    odd_reg_write_ex    = reg_write_i;
    odd_rd_ex           = rd_i;
    odd_link_data_ex    = link_i;
    odd_wb_data_ex      = wb_i;
    odd_mem_read_ex     = mem_read_i;
    odd_mem_write_ex    = mem_write_i;
    odd_mem_addr_ex     = mem_addr_i;
    odd_mem_wdata_ex    = mem_wdata_i;
    odd_mem_besel_ex    = mem_besel_i;
    odd_brch_taken_ex   = brch_taken_i;
    odd_brch_target_ex  = brch_target_i;
    odd_jmp_ex          = jmp_i;
    odd_jmp_target_ex   = jmp_target_i;
    tick();
  endtask

  task automatic check_expect_even(
    input string       name,
    input string       detail,
    input logic        exp_valid,
    input logic        exp_reg_write,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_alu_result,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (even_valid_mem === exp_valid && even_reg_write_mem === exp_reg_write &&
            even_rd_mem === exp_rd && even_alu_result_mem === exp_alu_result &&
            even_pc_mem === exp_pc);
    tb_report_open(pass, name, detail);
    tb_field_bit("even_valid_mem", even_valid_mem, exp_valid);
    tb_field_bit("even_reg_write_mem", even_reg_write_mem, exp_reg_write);
    tb_field_u5("even_rd_mem", even_rd_mem, exp_rd);
    tb_field_u32("even_alu_result_mem", even_alu_result_mem, exp_alu_result);
    tb_field_u32("even_pc_mem", even_pc_mem, exp_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_expect_odd(
    input string       name,
    input string       detail,
    input logic        exp_valid,
    input logic        exp_reg_write,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_wb,
    input logic        exp_mem_write,
    input logic [31:0] exp_mem_addr,
    input logic [31:0] exp_mem_wdata
  );
    bit pass;
    pass = (odd_valid_mem === exp_valid && odd_reg_write_mem === exp_reg_write &&
            odd_rd_mem === exp_rd && odd_wb_data_mem === exp_wb &&
            odd_mem_write_mem === exp_mem_write &&
            odd_mem_addr_mem === exp_mem_addr &&
            odd_mem_wdata_mem === exp_mem_wdata);
    tb_report_open(pass, name, detail);
    tb_field_bit("odd_valid_mem", odd_valid_mem, exp_valid);
    tb_field_bit("odd_reg_write_mem", odd_reg_write_mem, exp_reg_write);
    tb_field_u5("odd_rd_mem", odd_rd_mem, exp_rd);
    tb_field_u32("odd_wb_data_mem", odd_wb_data_mem, exp_wb);
    tb_field_bit("odd_mem_write_mem", odd_mem_write_mem, exp_mem_write);
    tb_field_u32("odd_mem_addr_mem", odd_mem_addr_mem, exp_mem_addr);
    tb_field_u32("odd_mem_wdata_mem", odd_mem_wdata_mem, exp_mem_wdata);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_expect_odd_invalid(input string name, input string detail);
    bit pass;
    pass = !odd_valid_mem;
    tb_report_open(pass, name, detail);
    tb_field_bit("odd_valid_mem", odd_valid_mem, 1'b0);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    stall_even = 0;
    stall_odd  = 0;
    flush_even = 0;
    flush_odd  = 0;
    pass_cnt   = 0;
    fail_cnt   = 0;

    even_valid_ex = 0;
    odd_valid_ex  = 0;

    rst_n = 0;
    repeat (2) tick();
    rst_n = 1;
    tick();

    tb_banner("ex_mem_tb - independent even / odd EX/MEM");
    tb_info_msg("Golden values per test (run_insn_* + check_expect_*)");

    // Even latch; odd idle (one cycle)
    even_valid_ex      = 1;
    even_reg_write_ex  = 1;
    even_rd_ex         = 5'd5;
    even_alu_result_ex = 32'd42;
    even_pc_ex         = 32'h0000_1004;
    odd_valid_ex       = 0;
    tick();
    check_expect_even("even_latch", "even ALU res=42 rd=x5 pc=1004",
      1'b1, 1'b1, 5'd5, 32'd42, 32'h0000_1004);
    check_expect_odd_invalid("odd_idle", "odd not latched");

    // Stall even; odd LUI advances (one cycle, both lanes driven)
    stall_even = 1;
    even_alu_result_ex = 32'd99;
    even_pc_ex         = 32'h0000_1008;
    odd_valid_ex       = 1;
    odd_reg_write_ex   = 1;
    odd_rd_ex          = 5'd7;
    odd_link_data_ex   = 32'h1004;
    odd_wb_data_ex     = 32'h0004_5000;
    odd_mem_read_ex    = 0;
    odd_mem_write_ex   = 0;
    odd_brch_taken_ex  = 0;
    odd_jmp_ex         = 0;
    tick();
    check_expect_even("even_stall_hold", "even stall holds res=42 pc=1004",
      1'b1, 1'b1, 5'd5, 32'd42, 32'h0000_1004);
    check_expect_odd("odd_while_even_stall", "odd LUI wb=45000 rd=x7",
      1'b1, 1'b1, 5'd7, 32'h0004_5000, 1'b0, 32'd0, 32'd0);

    stall_even = 0;
    even_alu_result_ex = 32'd99;
    even_valid_ex      = 1;
    odd_valid_ex       = 0;
    tick();
    check_expect_even("even_after_stall", "even after stall res=99 pc=1008",
      1'b1, 1'b1, 5'd5, 32'd99, 32'h0000_1008);

    // Odd store; even idle
    even_valid_ex       = 0;
    odd_valid_ex        = 1;
    odd_reg_write_ex    = 0;
    odd_mem_read_ex     = 0;
    odd_mem_write_ex    = 1;
    odd_mem_addr_ex     = 32'h100;
    odd_mem_wdata_ex    = 32'hDEAD_BEEF;
    odd_mem_besel_ex    = 4'b1111;
    odd_brch_taken_ex   = 0;
    odd_jmp_ex          = 0;
    tick();
    check_expect_odd("odd_store", "SW addr=100 wdata=DEAD_BEEF",
      1'b1, 1'b0, 5'd0, 32'd0, 1'b1, 32'h100, 32'hDEAD_BEEF);
    check_expect_even("even_hold", "even MEM still res=99 while odd store",
      1'b1, 1'b1, 5'd5, 32'd99, 32'h0000_1008);

    // Flush even only
    flush_even = 1;
    even_valid_ex = 1;
    tick();
    flush_even = 0;
    check_expect_even("flush_even", "even flushed",
      1'b0, 1'b0, 5'd0, 32'd0, 32'd0);
    check_expect_odd("odd_after_even_flush", "odd store retained",
      1'b1, 1'b0, 5'd0, 32'd0, 1'b1, 32'h100, 32'hDEAD_BEEF);

    // Flush odd
    flush_odd = 1;
    tick();
    flush_odd = 0;
    check_expect_odd_invalid("flush_odd", "odd flushed");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "ex_mem_tb failed");
    $finish;
  end

endmodule
