`timescale 1ns / 1ps

// memory_cache_tb — L1 miss busy, hit path, WAW suppress, WAR read-then-write.
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
  logic        enable;

  logic        i0_act;
  logic [31:0] i0_addr;
  logic [31:0] i0_wdata;
  logic [3:0]  i0_besel;
  logic [31:0] i0_mem_data;

  logic        i1_act;
  logic [31:0] i1_addr;
  logic [31:0] i1_wdata;
  logic [3:0]  i1_besel;
  logic [31:0] i1_mem_data;

  logic        cache_busy;

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
    i0_act      = 1'b0;
    i0_addr     = '0;
    i0_wdata    = '0;
    i0_besel    = '0;
    i1_act      = 1'b0;
    i1_addr     = '0;
    i1_wdata    = '0;
    i1_besel    = '0;
  endtask

  task automatic preload_l2_word(input logic [31:0] byte_addr, input logic [31:0] word);
    logic [31:0] base;
    base = {byte_addr[31:2], 2'b00};
    dut.l2_array[base + 0] = word[7:0];
    dut.l2_array[base + 1] = word[15:8];
    dut.l2_array[base + 2] = word[23:16];
    dut.l2_array[base + 3] = word[31:24];
  endtask

  task automatic drive_i0_read(input logic [31:0] addr);
    i0_act      = 1'b0;
    i0_addr     = addr;
    i0_besel    = 4'b1111;
  endtask

  task automatic fill_line(input logic [31:0] addr);
    drive_i0_read(addr);
    while (cache_busy) tick();
    clear_ports();
    tick();
  endtask

  task automatic check_busy(
    input string name,
    input string detail,
    input logic  exp_busy
  );
    bit pass;
    pass = (cache_busy === exp_busy);
    tb_report_open(pass, name, detail);
    tb_field_bit("cache_busy", cache_busy, exp_busy);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_mem_data(
    input string       name,
    input string       detail,
    input logic [31:0] exp_i0,
    input logic [31:0] exp_i1
  );
    bit pass;
    pass = (i0_mem_data === exp_i0) && (i1_mem_data === exp_i1);
    tb_report_open(pass, name, detail);
    tb_field_u32("i0_mem_data", i0_mem_data, exp_i0);
    tb_field_u32("i1_mem_data", i1_mem_data, exp_i1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    clear_ports();
    enable = 1'b1;
    rst_n  = 1'b0;
    tick();
    rst_n = 1'b1;
    preload_l2_word(TEST_ADDR, L2_WORD);
    preload_l2_word(TEST_ADDR2, 32'hCAFE_BABE);

    tb_banner("memory_cache_tb - miss busy / hit / WAW / WAR");

    // --- L1 miss: cache_busy until fill completes (status only) ---
    drive_i0_read(TEST_ADDR);
    tick();
    check_busy("miss_busy_start", "first touch misses L1: cache_busy asserted", 1'b1);
    repeat (L2_FILL_CYCLES - 2) begin
      tick();
      check_busy("miss_busy_hold", "hold while L2 fills", 1'b1);
    end
    tick();
    check_busy("miss_busy_end", "fill complete: cache_busy deasserts", 1'b0);
    check_mem_data("miss_mem_data", "read data from filled L1 line",
                   L2_WORD, 32'd0);

    tick();
    check_busy("hit_no_busy", "second read same line is L1 hit", 1'b0);
    check_mem_data("hit_mem_data", "hit returns same word", L2_WORD, 32'd0);
    clear_ports();
    tick();

    drive_i0_read(TEST_ADDR2);
    i1_act   = 1'b0;
    i1_addr  = TEST_ADDR2;
    i1_besel = 4'b1111;
    tick();
    check_busy("dual_miss_busy", "RAR same line: cache_busy until fill", 1'b1);
    while (cache_busy) tick();
    check_mem_data("dual_miss_mem_data", "both ports see L2 data after fill",
                   32'hCAFE_BABE, 32'hCAFE_BABE);
    clear_ports();
    tick();

    // --- Write hit ---
    fill_line(TEST_ADDR);
    i0_act   = 1'b1;
    i0_addr  = TEST_ADDR;
    i0_wdata = 32'h1122_3344;
    i0_besel = 4'b1111;
    tick();
    check_busy("write_hit_no_busy", "store to resident line does not busy", 1'b0);
    drive_i0_read(TEST_ADDR);
    tick();
    check_mem_data("write_then_read", "written word visible on L1 read",
                   32'h1122_3344, 32'd0);
    clear_ports();
    tick();

    // --- WAW: dual store same word — I1 (younger) wins ---
    preload_l2_word(TEST_ADDR, 32'hAABB_CCDD);
    fill_line(TEST_ADDR);
    i0_act    = 1'b1;
    i0_addr   = TEST_ADDR;
    i0_wdata  = 32'h1111_1111;
    i0_besel  = 4'b1111;
    i1_act    = 1'b1;
    i1_addr   = TEST_ADDR;
    i1_wdata  = 32'h2222_2222;
    i1_besel  = 4'b1111;
    tick();
    drive_i0_read(TEST_ADDR);
    tick();
    check_mem_data("waw_younger_wins", "I0 store suppressed; I1 value visible",
                   32'h2222_2222, 32'd0);
    clear_ports();
    tick();

    // --- WAR: I0 read + I1 write same word — comb read sees pre-write value ---
    preload_l2_word(TEST_ADDR, 32'h3333_4444);
    fill_line(TEST_ADDR);
    i0_act   = 1'b0;
    i0_addr  = TEST_ADDR;
    i0_besel = 4'b1111;
    i1_act   = 1'b1;
    i1_addr  = TEST_ADDR;
    i1_wdata = 32'h5555_6666;
    i1_besel = 4'b1111;
    #1;
    check_mem_data("war_read_before_write", "I0 load sees old word before I1 store",
                   32'h3333_4444, 32'd0);
    tick();
    drive_i0_read(TEST_ADDR);
    tick();
    check_mem_data("war_write_visible", "after posedge, I1 store is visible",
                   32'h5555_6666, 32'd0);
    clear_ports();
    tick();

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "memory_cache_tb failed");
    $finish;
  end

endmodule
