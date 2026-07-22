`timescale 1ns / 1ps

// Unit TB: 64-slot free_list — dual alloc, rename free, arch-tag free.
import rv_dis_pkg::*;

module free_list_tb;
  logic        clk, rst_n, flush;
  logic        i0_alloc_en, i1_alloc_en;
  prf_addr_t   i0_alloc_ntag, i1_alloc_ntag;
  logic        i0_alloc_ok, i1_alloc_ok;
  logic        i0_free_en, i1_free_en;
  prf_addr_t   i0_free_tag, i1_free_tag;
  logic [NUM_PRF-1:0] rrat_used;

  free_list dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic clear_stim;
    flush = 0;
    i0_alloc_en = 0; i1_alloc_en = 0;
    i0_free_en = 0; i1_free_en = 0;
    i0_free_tag = '0; i1_free_tag = '0;
  endtask

  initial begin
    rst_n = 0;
    rrat_used = '0;
    for (int r = 0; r < NUM_GPR; r++)
      rrat_used[r] = 1'b1;
    clear_stim();
    repeat (2) tick;
    rst_n = 1;
    tick;

    i0_alloc_en = 1; i1_alloc_en = 1;
    tick;
    if (!i0_alloc_ok || !i1_alloc_ok) $error("alloc not ready");
    if (i0_alloc_ntag != 6'd32 || i1_alloc_ntag != 6'd33)
      $error("expect p32/p33 got %0d/%0d", i0_alloc_ntag, i1_alloc_ntag);
    clear_stim();
    tick;

    i0_free_en = 1; i0_free_tag = 6'd32;
    i1_free_en = 1; i1_free_tag = 6'd5;
    tick;
    clear_stim();

    i0_alloc_en = 1; i1_alloc_en = 1;
    tick;
    if (i0_alloc_ntag != 6'd34 || i1_alloc_ntag != 6'd35)
      $error("expect p34/p35 got %0d/%0d", i0_alloc_ntag, i1_alloc_ntag);
    clear_stim();

    // Model x1 committing p32: p1 becomes free while p32 remains architected.
    rrat_used = '0;
    rrat_used[0] = 1'b1;
    for (int r = 2; r <= 32; r++)
      rrat_used[r] = 1'b1;
    flush = 1;
    @(negedge clk);
    #1;
    flush = 0;
    i0_alloc_en = 1;
    i1_alloc_en = 1;
    #1;
    if (i0_alloc_ntag != 6'd1 || i1_alloc_ntag != 6'd33)
      $error("flush rebuild expect p1/p33 got %0d/%0d",
             i0_alloc_ntag, i1_alloc_ntag);

    $display("OK free_list_tb");
    $finish;
  end
endmodule
