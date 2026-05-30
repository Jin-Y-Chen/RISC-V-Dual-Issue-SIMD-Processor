`timescale 1ns / 1ps

// EX/MEM pipeline register — odd lane (memory, branch, jump).
module ex_mem_odd (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        stall,
  input  logic        flush,

  input  logic        valid_ex,
  input  logic        reg_write_ex,
  input  logic [4:0]  rd_ex,
  input  logic [31:0] link_data_ex,
  input  logic        mem_read_ex,
  input  logic        mem_write_ex,
  input  logic [31:0] mem_addr_ex,
  input  logic [31:0] mem_wdata_ex,
  input  logic [3:0]  mem_be_ex,
  input  logic        branch_taken_ex,
  input  logic [31:0] branch_target_ex,
  input  logic        jump_ex,
  input  logic [31:0] jump_target_ex,

  output logic        valid_mem,
  output logic        reg_write_mem,
  output logic [4:0]  rd_mem,
  output logic [31:0] link_data_mem,
  output logic        mem_read_mem,
  output logic        mem_write_mem,
  output logic [31:0] mem_addr_mem,
  output logic [31:0] mem_wdata_mem,
  output logic [3:0]  mem_be_mem,
  output logic        branch_taken_mem,
  output logic [31:0] branch_target_mem,
  output logic        jump_mem,
  output logic [31:0] jump_target_mem
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_mem         <= 1'b0;
      reg_write_mem     <= 1'b0;
      rd_mem            <= 5'd0;
      link_data_mem     <= 32'd0;
      mem_read_mem      <= 1'b0;
      mem_write_mem     <= 1'b0;
      mem_addr_mem      <= 32'd0;
      mem_wdata_mem     <= 32'd0;
      mem_be_mem        <= 4'd0;
      branch_taken_mem  <= 1'b0;
      branch_target_mem <= 32'd0;
      jump_mem          <= 1'b0;
      jump_target_mem   <= 32'd0;
    end else if (flush) begin
      valid_mem         <= 1'b0;
      reg_write_mem     <= 1'b0;
      rd_mem            <= 5'd0;
      link_data_mem     <= 32'd0;
      mem_read_mem      <= 1'b0;
      mem_write_mem     <= 1'b0;
      mem_addr_mem      <= 32'd0;
      mem_wdata_mem     <= 32'd0;
      mem_be_mem        <= 4'd0;
      branch_taken_mem  <= 1'b0;
      branch_target_mem <= 32'd0;
      jump_mem          <= 1'b0;
      jump_target_mem   <= 32'd0;
    end else if (!stall) begin
      valid_mem         <= valid_ex;
      reg_write_mem     <= reg_write_ex;
      rd_mem            <= rd_ex;
      link_data_mem     <= link_data_ex;
      mem_read_mem      <= mem_read_ex;
      mem_write_mem     <= mem_write_ex;
      mem_addr_mem      <= mem_addr_ex;
      mem_wdata_mem     <= mem_wdata_ex;
      mem_be_mem        <= mem_be_ex;
      branch_taken_mem  <= branch_taken_ex;
      branch_target_mem <= branch_target_ex;
      jump_mem          <= jump_ex;
      jump_target_mem   <= jump_target_ex;
    end
  end

endmodule
