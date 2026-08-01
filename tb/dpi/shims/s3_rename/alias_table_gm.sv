`timescale 1ns / 1ps

// DPI shim - model/s3_rename/alias_table_gm.cpp
import rv_dis_pkg::*;
import dpi_pkg::*;

module alias_table_gm (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        spec_en       [2],

  input  logic        rs1_use       [2],
  input  logic        rs2_use       [2],
  input  gpr_addr_t   rs1_addr      [2],
  input  gpr_addr_t   rs2_addr      [2],
  output logic        path_use      [2],
  output prf_addr_t   ps1_tag       [2],
  output prf_addr_t   ps2_tag       [2],

  input  logic        alloc_en      [2],
  input  gpr_addr_t   alloc_rd_addr [2],
  input  prf_addr_t   alloc_rob_tag [2],

  input  logic        rrat_en       [2],
  input  gpr_addr_t   rd_addr_cmt   [2],
  input  prf_addr_t   rob_tag_cmt   [2],

  input  logic        rat_en        [2],
  input  logic        path_sel      [2]
);

  chandle h;
  int path0, path1, p10, p11, p20, p21;

  initial begin
    h = alias_dpi_create();
    if (h == null) $fatal(1, "alias_dpi_create failed");
  end
  final alias_dpi_destroy(h);

  always @(*) begin
    alias_dpi_eval(
      h,
      int'(flush),
      int'(spec_en[0]), int'(spec_en[1]),
      int'(rs1_use[0]), int'(rs1_use[1]), int'(rs2_use[0]), int'(rs2_use[1]),
      int'(rs1_addr[0]), int'(rs1_addr[1]), int'(rs2_addr[0]), int'(rs2_addr[1]),
      int'(alloc_en[0]), int'(alloc_en[1]),
      int'(alloc_rd_addr[0]), int'(alloc_rd_addr[1]),
      int'(alloc_rob_tag[0]), int'(alloc_rob_tag[1]),
      int'(rrat_en[0]), int'(rrat_en[1]),
      int'(rd_addr_cmt[0]), int'(rd_addr_cmt[1]),
      int'(rob_tag_cmt[0]), int'(rob_tag_cmt[1]),
      int'(rat_en[0]), int'(rat_en[1]),
      int'(path_sel[0]), int'(path_sel[1]),
      path0, path1, p10, p11, p20, p21);
    path_use[0] = path0[0];
    path_use[1] = path1[0];
    ps1_tag[0]  = prf_addr_t'(p10);
    ps1_tag[1]  = prf_addr_t'(p11);
    ps2_tag[0]  = prf_addr_t'(p20);
    ps2_tag[1]  = prf_addr_t'(p21);
  end

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
      alias_dpi_reset(h);
    else
      alias_dpi_commit(
        h,
        int'(flush),
        int'(spec_en[0]), int'(spec_en[1]),
        int'(rs1_use[0]), int'(rs1_use[1]), int'(rs2_use[0]), int'(rs2_use[1]),
        int'(rs1_addr[0]), int'(rs1_addr[1]), int'(rs2_addr[0]), int'(rs2_addr[1]),
        int'(alloc_en[0]), int'(alloc_en[1]),
        int'(alloc_rd_addr[0]), int'(alloc_rd_addr[1]),
        int'(alloc_rob_tag[0]), int'(alloc_rob_tag[1]),
        int'(rrat_en[0]), int'(rrat_en[1]),
        int'(rd_addr_cmt[0]), int'(rd_addr_cmt[1]),
        int'(rob_tag_cmt[0]), int'(rob_tag_cmt[1]),
        int'(rat_en[0]), int'(rat_en[1]),
        int'(path_sel[0]), int'(path_sel[1]));
  end

endmodule
