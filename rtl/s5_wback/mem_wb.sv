`timescale 1ns / 1ps

// MEM/WB pipeline register — dual slot (I0 older / I1 younger).
// Latches per-slot writeback control and data from the MEM stage for the
// GPR write ports and WB->EX forwarding (wb0/wb1 at the top level).
//
// Upstream MEM logic selects i0/i1_wdata_mem (even ALU result, odd load data,
// link_pc, or U-type alu_result) before this register.
module mem_wb
  import rv_dis_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        stall_i0,
  input  logic        stall_i1,

  // --- Slot 0 (I0 / older) from MEM ---
  input  logic        i0_reg_write_mem,
  input  logic [4:0]  i0_rd_addr_mem,
  input  reg_t        i0_wdata_mem,
  input  reg_t        i0_pc_mem,

  // --- Slot 1 (I1 / younger) from MEM ---
  input  logic        i1_reg_write_mem,
  input  logic [4:0]  i1_rd_addr_mem,
  input  reg_t        i1_wdata_mem,
  input  reg_t        i1_pc_mem,

  // --- Slot 0 WB (register file port 0 / forward wb0) ---
  output logic        i0_reg_write_wb,
  output logic [4:0]  i0_rd_addr_wb,
  output reg_t        i0_wdata_wb,
  output reg_t        i0_pc_wb,

  // --- Slot 1 WB (register file port 1 / forward wb1) ---
  output logic        i1_reg_write_wb,
  output logic [4:0]  i1_rd_addr_wb,
  output reg_t        i1_wdata_wb,
  output reg_t        i1_pc_wb
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      i0_reg_write_wb <= 1'b0;
      i0_rd_addr_wb   <= 5'd0;
      i0_wdata_wb     <= '0;
      i0_pc_wb        <= '0;

      i1_reg_write_wb <= 1'b0;
      i1_rd_addr_wb   <= 5'd0;
      i1_wdata_wb     <= '0;
      i1_pc_wb        <= '0;
    end else begin
      if (!stall_i0) begin
        i0_reg_write_wb <= i0_reg_write_mem;
        i0_rd_addr_wb   <= i0_rd_addr_mem;
        i0_wdata_wb     <= i0_wdata_mem;
        i0_pc_wb        <= i0_pc_mem;
      end

      if (!stall_i1) begin
        i1_reg_write_wb <= i1_reg_write_mem;
        i1_rd_addr_wb   <= i1_rd_addr_mem;
        i1_wdata_wb     <= i1_wdata_mem;
        i1_pc_wb        <= i1_pc_mem;
      end
    end
  end

endmodule
