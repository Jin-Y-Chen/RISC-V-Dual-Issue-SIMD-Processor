`timescale 1ns / 1ps

// EX/MEM pipeline register — even lane only (ALU result for forward / writeback).
module ex_mem_even (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        stall_even,
  input  logic        flush_even,

  input  logic        valid_ex,
  input  logic        reg_write_ex,
  input  logic [4:0]  rd_ex,
  input  logic [31:0] alu_result_ex,
  input  logic [31:0] pc_ex,

  output logic        valid_mem,
  output logic        reg_write_mem,
  output logic [4:0]  rd_mem,
  output logic [31:0] alu_result_mem,
  output logic [31:0] pc_mem
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_mem      <= 1'b0;
      reg_write_mem  <= 1'b0;
      rd_mem         <= 5'd0;
      alu_result_mem <= 32'd0;
      pc_mem         <= 32'd0;
    end else if (flush_even) begin
      valid_mem      <= 1'b0;
      reg_write_mem  <= 1'b0;
      rd_mem         <= 5'd0;
      alu_result_mem <= 32'd0;
      pc_mem         <= 32'd0;
    end else if (!stall_even) begin
      valid_mem      <= valid_ex;
      reg_write_mem  <= reg_write_ex;
      rd_mem         <= rd_ex;
      alu_result_mem <= alu_result_ex;
      pc_mem         <= pc_ex;
    end
  end

endmodule
