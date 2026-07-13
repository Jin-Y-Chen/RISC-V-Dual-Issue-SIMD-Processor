`timescale 1ns / 1ps

// Smoke elaborate of risc_dis_unit (port / child wiring check).
import rv_dis_pkg::*;

module risc_dis_unit_tb;
  logic clk, rst_n, enable, flush;
  word_t pc_fetch, pc_fetch_plus4;
  logic stall_id;

  risc_dis_unit dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .enable         (enable),
    .flush          (flush),
    .pc_fetch       (pc_fetch),
    .pc_fetch_plus4 (pc_fetch_plus4),
    .stall_id       (stall_id)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 0; enable = 0; flush = 0;
    repeat (2) @(posedge clk);
    rst_n = 1; enable = 1;
    repeat (4) @(posedge clk);
    $display("OK risc_dis_unit_tb elaborate/smoke");
    $finish;
  end
endmodule
