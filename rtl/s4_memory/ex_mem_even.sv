`timescale 1ns / 1ps

// EX/MEM pipeline register — even lane only (ALU result for forward / writeback).
// Carries the even_lane outputs plus the WB controls (rd, pc for write-port age).
module ex_mem_even (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        stall_even,

  input  logic        enable,
  input  logic        reg_write_ex,
  input  logic [4:0]  rd_addr_ex,
  input  logic [31:0] alu_result_ex,
  input  logic [31:0] pc_ex,

  output logic        reg_write_mem,
  output logic [4:0]  rd_addr_mem,
  output logic [31:0] alu_result_mem,
  output logic [31:0] pc_mem
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_write_mem  <= 1'b0;
      rd_addr_mem    <= 5'd0;
      alu_result_mem <= 32'd0;
      pc_mem         <= 32'd0;
    end else if (!stall_even) begin
      // enable qualifies slot-level controls: only a slot dispatched to this
      // lane may write back from it.
      reg_write_mem  <= enable && reg_write_ex;
      rd_addr_mem    <= rd_addr_ex;
      alu_result_mem <= alu_result_ex;
      pc_mem         <= pc_ex;
    end
  end

endmodule
