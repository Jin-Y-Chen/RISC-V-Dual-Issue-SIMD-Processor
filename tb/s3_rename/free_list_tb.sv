`timescale 1ns / 1ps

// Unit TB: partitioned free_list — two queues, dual-path alloc + commit free.
import rv_dis_pkg::*;

module free_list_tb;
  logic        clk, rst_n, flush;
  br_map_t     brch_map;
  logic        rename0_en, rename1_en;
  prf_addr_t   i0_alloc_br0, i0_alloc_br1, i1_alloc_br0, i1_alloc_br1;
  logic        alloc0_valid, alloc1_valid;
  logic        free0_en, free1_en;
  prf_addr_t   i0_free_tag, i1_free_tag;

  free_list dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic clear_stim;
    flush = 0;
    rename0_en = 0; rename1_en = 0;
    free0_en = 0; free1_en = 0;
    i0_free_tag = '0; i1_free_tag = '0;
  endtask

  initial begin
    rst_n = 0;
    brch_map = BR_MAP_NONE;
    clear_stim();
    repeat (2) tick;
    rst_n = 1;
    tick;

    // One-col dual-issue: i0←p32, i1←p33
    brch_map = BR_MAP_NONE;
    rename0_en = 1; rename1_en = 1;
    tick;
    if (!alloc0_valid || !alloc1_valid) $error("one-col alloc not ready");
    if (i0_alloc_br0 != 6'd32 || i1_alloc_br0 != 6'd33)
      $error("one-col expect p32/p33 got %0d/%0d", i0_alloc_br0, i1_alloc_br0);
    clear_stim();
    tick;

    // Dual-path: i0 gets p34+p35, i1 gets p36+p37
    brch_map = BR_MAP_BOTH;
    rename0_en = 1; rename1_en = 1;
    tick;
    if (i0_alloc_br0 != 6'd34 || i0_alloc_br1 != 6'd35)
      $error("dual i0 expect p34/p35 got %0d/%0d", i0_alloc_br0, i0_alloc_br1);
    if (i1_alloc_br0 != 6'd36 || i1_alloc_br1 != 6'd37)
      $error("dual i1 expect p36/p37 got %0d/%0d", i1_alloc_br0, i1_alloc_br1);
    clear_stim();
    tick;

    // Commit free returns p34 → next path0 peek is p34 again after draining? 
    // After pops rd0=3 (p38 next). Free p34 into q0, then next alloc still p38
    // (FIFO order: wr pushes at end). Just check free doesn't stall.
    free0_en = 1; i0_free_tag = 6'd34;
    tick;
    clear_stim();

    rename0_en = 1;
    tick;
    if (i0_alloc_br0 != 6'd38 || i0_alloc_br1 != 6'd39)
      $error("next dual expect p38/p39 got %0d/%0d", i0_alloc_br0, i0_alloc_br1);
    clear_stim();

    $display("OK free_list_tb");
    $finish;
  end
endmodule
