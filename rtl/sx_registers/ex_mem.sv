`timescale 1ns / 1ps

// EX/MEM pipeline registers for dual-issue even and odd lanes.
module ex_mem (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        stall,
  input  logic        flush,

  // Even lane — EX in
  input  logic        even_valid_ex,
  input  logic        even_reg_write_ex,
  input  logic [4:0]  even_rd_ex,
  input  logic [31:0] even_alu_result_ex,

  // Even lane — MEM out
  output logic        even_valid_mem,
  output logic        even_reg_write_mem,
  output logic [4:0]  even_rd_mem,
  output logic [31:0] even_alu_result_mem,

  // Odd lane — EX in
  input  logic        odd_valid_ex,
  input  logic        odd_reg_write_ex,
  input  logic [4:0]  odd_rd_ex,
  input  logic [31:0] odd_link_data_ex,
  input  logic        odd_mem_read_ex,
  input  logic        odd_mem_write_ex,
  input  logic [31:0] odd_mem_addr_ex,
  input  logic [31:0] odd_mem_wdata_ex,
  input  logic [3:0]  odd_mem_be_ex,
  input  logic        odd_branch_taken_ex,
  input  logic [31:0] odd_branch_target_ex,
  input  logic        odd_jump_ex,
  input  logic [31:0] odd_jump_target_ex,

  // Odd lane — MEM out
  output logic        odd_valid_mem,
  output logic        odd_reg_write_mem,
  output logic [4:0]  odd_rd_mem,
  output logic [31:0] odd_link_data_mem,
  output logic        odd_mem_read_mem,
  output logic        odd_mem_write_mem,
  output logic [31:0] odd_mem_addr_mem,
  output logic [31:0] odd_mem_wdata_mem,
  output logic [3:0]  odd_mem_be_mem,
  output logic        odd_branch_taken_mem,
  output logic [31:0] odd_branch_target_mem,
  output logic        odd_jump_mem,
  output logic [31:0] odd_jump_target_mem
);

  ex_mem_even u_even (
    .clk            (clk),
    .rst_n          (rst_n),
    .stall          (stall),
    .flush          (flush),
    .valid_ex       (even_valid_ex),
    .reg_write_ex   (even_reg_write_ex),
    .rd_ex          (even_rd_ex),
    .alu_result_ex  (even_alu_result_ex),
    .valid_mem      (even_valid_mem),
    .reg_write_mem  (even_reg_write_mem),
    .rd_mem         (even_rd_mem),
    .alu_result_mem (even_alu_result_mem)
  );

  ex_mem_odd u_odd (
    .clk               (clk),
    .rst_n             (rst_n),
    .stall             (stall),
    .flush             (flush),
    .valid_ex          (odd_valid_ex),
    .reg_write_ex      (odd_reg_write_ex),
    .rd_ex             (odd_rd_ex),
    .link_data_ex      (odd_link_data_ex),
    .mem_read_ex       (odd_mem_read_ex),
    .mem_write_ex      (odd_mem_write_ex),
    .mem_addr_ex       (odd_mem_addr_ex),
    .mem_wdata_ex      (odd_mem_wdata_ex),
    .mem_be_ex         (odd_mem_be_ex),
    .branch_taken_ex   (odd_branch_taken_ex),
    .branch_target_ex  (odd_branch_target_ex),
    .jump_ex           (odd_jump_ex),
    .jump_target_ex    (odd_jump_target_ex),
    .valid_mem         (odd_valid_mem),
    .reg_write_mem     (odd_reg_write_mem),
    .rd_mem            (odd_rd_mem),
    .link_data_mem     (odd_link_data_mem),
    .mem_read_mem      (odd_mem_read_mem),
    .mem_write_mem     (odd_mem_write_mem),
    .mem_addr_mem      (odd_mem_addr_mem),
    .mem_wdata_mem     (odd_mem_wdata_mem),
    .mem_be_mem        (odd_mem_be_mem),
    .branch_taken_mem  (odd_branch_taken_mem),
    .branch_target_mem (odd_branch_target_mem),
    .jump_mem          (odd_jump_mem),
    .jump_target_mem   (odd_jump_target_mem)
  );

endmodule
