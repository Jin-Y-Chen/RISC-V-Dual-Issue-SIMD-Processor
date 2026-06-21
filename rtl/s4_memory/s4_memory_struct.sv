`timescale 1ns / 1ps

// S4 memory structure — L1 data cache only (ex_mem is instantiated in risc_dis_unit).
module s4_memory_struct
  import rv_dis_pkg::*;
(
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls
  input  logic        od0_mem_en_mem,
  input  logic        od0_mem_act_mem,
  input  logic        od1_mem_en_mem,
  input  logic        od1_mem_act_mem,

  // input data
  input  logic [31:0] od0_mem_addr_mem,
  input  logic [31:0] od0_mem_wdata_mem,
  input  logic [3:0]  od0_mem_besel_mem,
  input  logic [31:0] od1_mem_addr_mem,
  input  logic [31:0] od1_mem_wdata_mem,
  input  logic [3:0]  od1_mem_besel_mem,

  // output data
  output logic [31:0] od0_load_mem_data,
  output logic [31:0] od1_load_mem_data,

  // output controls
  output logic        dcache_busy
);

  logic        cache_i0_act;
  logic [31:0] cache_i0_addr;
  logic [31:0] cache_i0_wdata;
  logic [3:0]  cache_i0_besel;

  logic        cache_i1_act;
  logic [31:0] cache_i1_addr;
  logic [31:0] cache_i1_wdata;
  logic [3:0]  cache_i1_besel;

  assign cache_i0_act   = od0_mem_en_mem ? od0_mem_act_mem : 1'b0;
  assign cache_i0_addr  = od0_mem_addr_mem;
  assign cache_i0_wdata = od0_mem_wdata_mem;
  assign cache_i0_besel = od0_mem_en_mem ? od0_mem_besel_mem : 4'b0000;

  assign cache_i1_act   = od1_mem_en_mem ? od1_mem_act_mem : 1'b0;
  assign cache_i1_addr  = od1_mem_addr_mem;
  assign cache_i1_wdata = od1_mem_wdata_mem;
  assign cache_i1_besel = od1_mem_en_mem ? od1_mem_besel_mem : 4'b0000;

  memory_cache u_dcache (
    // external controls
    .clk         (clk),
    .rst_n       (rst_n),
    .enable      (enable),
    // internal controls
    .i0_act      (cache_i0_act),
    .i1_act      (cache_i1_act),
    // input data
    .i0_addr     (cache_i0_addr),
    .i0_wdata    (cache_i0_wdata),
    .i0_besel    (cache_i0_besel),
    .i1_addr     (cache_i1_addr),
    .i1_wdata    (cache_i1_wdata),
    .i1_besel    (cache_i1_besel),
    // output data
    .i0_mem_data (od0_load_mem_data),
    .i1_mem_data (od1_load_mem_data),
    // output controls
    .cache_busy  (dcache_busy)
  );

endmodule
