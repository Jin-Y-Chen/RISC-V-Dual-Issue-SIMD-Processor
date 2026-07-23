`timescale 1ns / 1ps

import rv_dis_pkg::*;
import dpi_pkg::*;

// DPI shim — model/s4_dispatch/register_file_gm.cpp
module register_file_gm (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        i0_rs1_use,
  input  logic        i0_rs2_use,
  input  logic        i1_rs1_use,
  input  logic        i1_rs2_use,
  input  logic        i0_valid_wb,
  input  logic        i1_valid_wb,
  input  gpr_addr_t   i0_rs1_addr,
  input  gpr_addr_t   i0_rs2_addr,
  input  gpr_addr_t   i1_rs1_addr,
  input  gpr_addr_t   i1_rs2_addr,
  input  gpr_addr_t   i0_rd_addr,
  input  gpr_addr_t   i1_rd_addr,
  input  word_t       i0_data_wb,
  input  word_t       i1_data_wb,
  output word_t       i0_rs1_data,
  output word_t       i0_rs2_data,
  output word_t       i1_rs1_data,
  output word_t       i1_rs2_data
);

  chandle h;
  int d00, d01, d10, d11;

  initial begin
    h = rf_dpi_create();
    if (h == null) $fatal(1, "rf_dpi_create failed");
  end
  final rf_dpi_destroy(h);

  always @(*) begin
    rf_dpi_eval(h, int'(i0_rs1_use), int'(i0_rs2_use), int'(i1_rs1_use), int'(i1_rs2_use),
                int'(i0_valid_wb), int'(i1_valid_wb),
                int'(i0_rs1_addr), int'(i0_rs2_addr), int'(i1_rs1_addr), int'(i1_rs2_addr),
                int'(i0_rd_addr), int'(i1_rd_addr), int'(i0_data_wb), int'(i1_data_wb),
                d00, d01, d10, d11);
    i0_rs1_data = d00[31:0];
    i0_rs2_data = d01[31:0];
    i1_rs1_data = d10[31:0];
    i1_rs2_data = d11[31:0];
  end

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
      rf_dpi_reset(h);
    else
      rf_dpi_commit(h, int'(i0_valid_wb), int'(i1_valid_wb),
                    int'(i0_rd_addr), int'(i1_rd_addr),
                    int'(i0_data_wb), int'(i1_data_wb));
  end

endmodule
