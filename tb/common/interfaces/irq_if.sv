`timescale 1ns / 1ps
interface irq_if (input logic clk, input logic rst_n);
  logic irq;
  modport dut (input irq);
  modport drv (output irq);
endinterface
