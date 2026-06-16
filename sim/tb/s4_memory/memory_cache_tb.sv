`timescale 1ns / 1ps

// memory_cache_tb — L1 miss stall, L2 fill, hit path.
module memory_cache_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD     = 10;
  localparam int L2_FILL_CYCLES = 4;
  localparam int TEST_ADDR      = 32'h0000_1000;
  localparam int TEST_ADDR2     = 32'h0000_2000;
  localparam logic [31:0] L2_WORD = 32'hDEAD_BEEF;

  logic        clk;
  logic        rst_n;

  logic        p0_read_en;
  logic        p0_write_en;
  logic [31:0] p0_addr;
  logic [31:0] p0_wdata;
  logic [3:0]  p0_besel;
  logic [31:0] p0_rdata;

  logic        p1_read_en;
  logic        p1_write_en;
  logic [31:0] p1_addr;
  logic [31:0] p1_wdata;
  logic [3:0]  p1_besel;
  logic [31:0] p1_rdata;

  logic        stall_p0;
  logic        stall_p1;

  int pass_cnt;
  int fail_cnt;

  memory_cache #(
    .L2_FILL_CYCLES (L2_FILL_CYCLES),
    .COLD_L1_RESET  (1'b1)
  ) dut (.*);

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic clear_ports;
    p0_read_en  = 1'b0;
    p0_write_en = 1'b0;
    p0_addr     = '0;
    p0_wdata    = '0;
    p0_besel    = '0;
    p1_read_en  = 1'b0;
    p1_write_en = 1'b0;
    p1_addr     = '0;
    p1_wdata    = '0;
    p1_besel    = '0;
  endtask

  task automatic preload_l2_word(input logic [31:0] byte_addr, input logic [31:0] word);
    logic [31:0] base;
    base = {byte_addr[31:2], 2'b00};
    dut.l2_array[base + 0] = word[7:0];
    dut.l2_array[base + 1] = word[15:8];
    dut.l2_array[base + 2] = word[23:16];
    dut.l2_array[base + 3] = word[31:24];
  endtask

  task automatic drive_p0_read(input logic [31:0] addr);
    p0_read_en  = 1'b1;
    p0_write_en = 1'b0;
    p0_addr     = addr;
    p0_besel    = 4'b1111;
  endtask

  task automatic check_stall(
    input string name,
    input string detail,
    input logic  exp_p0,
    input logic  exp_p1
  );
    bit pass;
    pass = (stall_p0 === exp_p0) && (stall_p1 === exp_p1);
    tb_report_open(pass, name, detail);
    tb_field_bit("stall_p0", stall_p0, exp_p0);
    tb_field_bit("stall_p1", stall_p1, exp_p1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_rdata(
    input string       name,
    input string       detail,
    input logic [31:0] exp_p0,
    input logic [31:0] exp_p1
  );
    bit pass;
    pass = (p0_rdata === exp_p0) && (p1_rdata === exp_p1);
    tb_report_open(pass, name, detail);
    tb_field_u32("p0_rdata", p0_rdata, exp_p0);
    tb_field_u32("p1_rdata", p1_rdata, exp_p1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic wait_until_no_stall;
    int guard;
    guard = 0;
    while ((stall_p0 || stall_p1) && guard < 20) begin
      tick();
      guard++;
    end
    if (guard >= 20)
      $fatal(1, "wait_until_no_stall timeout");
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    clear_ports();
    rst_n = 1'b0;
    tick();
    rst_n = 1'b1;
    preload_l2_word(TEST_ADDR, L2_WORD);
    preload_l2_word(TEST_ADDR2, 32'hCAFE_BABE);

    tb_banner("memory_cache_tb - L1 miss stall / L2 fill");

    // COLD_L1_RESET: all lines invalid; L2 preloaded but not visible until fill.
    drive_p0_read(TEST_ADDR);
    tick();
    check_stall("miss_stall_start", "first touch misses L1: stall_p0 asserted",
                1'b1, 1'b0);
    repeat (L2_FILL_CYCLES - 1) begin
      tick();
      check_stall("miss_stall_hold", "hold request while L2 fills",
                  1'b1, 1'b0);
    end
    tick();
    check_stall("miss_stall_end", "fill complete: stall deasserts",
                1'b0, 1'b0);
    check_rdata("miss_rdata", "read data from filled L1 line",
                L2_WORD, 32'd0);

    tick();
    check_stall("hit_no_stall", "second read same line is L1 hit",
                1'b0, 1'b0);
    check_rdata("hit_rdata", "hit returns same word",
                L2_WORD, 32'd0);
    clear_ports();
    tick();

    drive_p0_read(TEST_ADDR2);
    p1_read_en = 1'b1;
    p1_addr    = TEST_ADDR2;
    p1_besel   = 4'b1111;
    tick();
    check_stall("dual_miss_stall", "RAR same line: both ports stall",
                1'b1, 1'b1);
    wait_until_no_stall();
    check_rdata("dual_miss_rdata", "both ports see L2 data after fill",
                32'hCAFE_BABE, 32'hCAFE_BABE);
    clear_ports();
    tick();

    // --- Write hit: TEST_ADDR line already resident from miss/hit sequence above ---
    p0_write_en = 1'b1;
    p0_addr     = TEST_ADDR;
    p0_wdata    = 32'h1122_3344;
    p0_besel    = 4'b1111;
    tick();
    check_stall("write_hit_no_stall", "store to resident line does not stall",
                1'b0, 1'b0);
    drive_p0_read(TEST_ADDR);
    tick();
    check_rdata("write_then_read", "written word visible on L1 read",
                32'h1122_3344, 32'd0);
    clear_ports();
    tick();

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "memory_cache_tb failed");
    $finish;
  end

endmodule
