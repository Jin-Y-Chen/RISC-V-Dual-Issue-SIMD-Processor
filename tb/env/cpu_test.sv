`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;
import cpu_txn_pkg::*;

`include "sequences/base_seq.sv"
`include "sequences/random_seq.sv"
`include "sequences/directed_seq.sv"

// Test layer: builds sequences and drives cpu_if.
module cpu_test (
  input  logic clk,
  input  logic rst_n,
  cpu_if.drv vif
);
  cpu_txn_t seq_q[$];
  fetch_driver drv (.vif(vif));

  task automatic run_directed();
    directed_seq seq;
    seq = new();
    seq.run(seq_q);
    foreach (seq_q[i]) begin
      drv.drive(seq_q[i]);
      @(posedge clk);
    end
    drv.clear();
  endtask

  task automatic run_random(input int unsigned n = 100);
    random_seq seq;
    seq = new("random_seq", n);
    seq.run(seq_q);
    foreach (seq_q[i]) begin
      drv.drive(seq_q[i]);
      @(posedge clk);
    end
    drv.clear();
  endtask

  initial begin
    wait (rst_n === 1'b1);
    repeat (2) @(posedge clk);
    run_directed();
    run_random(50);
    $display("[cpu_test] sequences complete");
  end
endmodule
