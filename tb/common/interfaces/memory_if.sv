`timescale 1ns / 1ps

// Instruction / data memory probe interface.
interface memory_if (input logic clk, input logic rst_n);
  import rv_dis_pkg::*;

  logic  imem_req;
  word_t imem_addr0, imem_addr1;
  word_t imem_rdata0, imem_rdata1;
  logic  imem_rvalid0, imem_rvalid1;

  logic  dmem_req, dmem_we;
  word_t dmem_addr, dmem_wdata, dmem_rdata;
  logic  dmem_rvalid;

  modport drv (input clk, rst_n,
               output imem_rdata0, imem_rdata1, imem_rvalid0, imem_rvalid1,
               output dmem_rdata, dmem_rvalid,
               input  imem_req, imem_addr0, imem_addr1,
               input  dmem_req, dmem_we, dmem_addr, dmem_wdata);
  modport mon (input clk, rst_n,
               input imem_req, imem_addr0, imem_addr1, imem_rdata0, imem_rdata1,
               input dmem_req, dmem_we, dmem_addr, dmem_wdata, dmem_rdata);
endinterface
