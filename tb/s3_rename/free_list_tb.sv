`timescale 1ns / 1ps

// Unit TB: 64-slot free_list — dual alloc, rename free, arch-tag free.
import rv_dis_pkg::*;

module free_list_tb;
  logic        clk, rst_n, flush;
  logic        rename0_en, rename1_en;
  prf_addr_t   i0_alloc_tag, i1_alloc_tag;
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
    clear_stim();
    repeat (2) tick;
    rst_n = 1;
    tick;

    rename0_en = 1; rename1_en = 1;
    tick;
    if (!alloc0_valid || !alloc1_valid) $error("alloc not ready");
    if (i0_alloc_tag != 6'd32 || i1_alloc_tag != 6'd33)
      $error("expect p32/p33 got %0d/%0d", i0_alloc_tag, i1_alloc_tag);
    clear_stim();
    tick;

    // Rename temp + arch tag both re-enter the 64-deep pool.
    free0_en = 1; i0_free_tag = 6'd32;
    free1_en = 1; i1_free_tag = 6'd5;
    tick;
    clear_stim();

    rename0_en = 1; rename1_en = 1;
    tick;
    if (i0_alloc_tag != 6'd34 || i1_alloc_tag != 6'd35)
      $error("expect p34/p35 got %0d/%0d", i0_alloc_tag, i1_alloc_tag);
    clear_stim();

    $display("OK free_list_tb");
    $finish;
  end
endmodule
