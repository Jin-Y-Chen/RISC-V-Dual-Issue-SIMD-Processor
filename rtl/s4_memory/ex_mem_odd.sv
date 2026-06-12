`timescale 1ns / 1ps

// EX/MEM pipeline register — odd lane only (mem, branch, jump, U-type; isolated from even).
module ex_mem_odd (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        stall_odd,

  input  logic        enable,
  input  logic        reg_write_ex,
  input  logic [4:0]  rd_addr_ex,
  input  logic        brch_taken_ex,
  input  logic [31:0] brch_target_ex,
  input  logic        mem_en_ex,
  input  logic        mem_act_ex,
  input  logic [31:0] mem_addr_ex,
  input  logic [31:0] mem_wdata_ex,
  input  logic [3:0]  mem_besel_ex,
  input  logic [31:0] link_pc_ex,
  input  logic [31:0] alu_result_ex,
  input  logic [31:0] pc_ex,

  output logic        reg_write_mem,
  output logic [4:0]  rd_addr_mem,
  output logic        brch_taken_mem,
  output logic [31:0] brch_target_mem,
  output logic        mem_en_mem,
  output logic        mem_act_mem,
  output logic [31:0] mem_addr_mem,
  output logic [31:0] mem_wdata_mem,
  output logic [3:0]  mem_besel_mem,
  output logic [31:0] link_pc_mem,
  output logic [31:0] alu_result_mem,
  output logic [31:0] pc_mem
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_write_mem   <= 1'b0;
      rd_addr_mem     <= 5'd0;
      brch_taken_mem  <= 1'b0;
      brch_target_mem <= 32'd0;
      mem_en_mem      <= 1'b0;
      mem_act_mem     <= 1'b0;
      mem_addr_mem    <= 32'd0;
      mem_wdata_mem   <= 32'd0;
      mem_besel_mem   <= 4'd0;
      link_pc_mem     <= 32'd0;
      alu_result_mem  <= 32'd0;
      pc_mem          <= 32'd0;
    end else if (!stall_odd) begin
      // enable qualifies slot-level controls: only a slot dispatched to this
      // lane may write back from it.
      reg_write_mem   <= enable && reg_write_ex;
      rd_addr_mem     <= rd_addr_ex;
      brch_taken_mem  <= brch_taken_ex;
      brch_target_mem <= brch_target_ex;
      mem_en_mem      <= mem_en_ex;
      mem_act_mem     <= mem_act_ex;
      mem_addr_mem    <= mem_addr_ex;
      mem_wdata_mem   <= mem_wdata_ex;
      mem_besel_mem   <= mem_besel_ex;
      link_pc_mem     <= link_pc_ex;
      alu_result_mem  <= alu_result_ex;
      pc_mem          <= pc_ex;
    end
  end

endmodule
