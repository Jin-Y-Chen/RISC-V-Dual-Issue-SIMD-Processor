`timescale 1ns / 1ps

import rv_dis_pkg::*;

// Top-level CPU testbench — wires interfaces, env, and risc_dis_unit.
// Probe nets on cpu_if / commit_if grow as more DUT ports are exposed.
module tb_top;
  localparam time CLK_PERIOD = 10ns;

  logic clk;
  logic rst_n;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
  end

  cpu_if    cif  (.clk(clk), .rst_n(rst_n));
  commit_if cmt  (.clk(clk), .rst_n(rst_n));
  memory_if mif  (.clk(clk), .rst_n(rst_n));

  // DUT — currently only enable/flush/PC/stall are external.
  risc_dis_unit u_dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .enable         (cif.enable),
    .flush          (cif.flush),
    .pc_fetch       (cif.pc0),
    .pc_fetch_plus4 (cif.pc1),
    .stall_id       (cif.stall_id)
  );

  // Observe-side placeholders until fuller DUT hooks exist.
  assign cif.i0_valid = 1'b0;
  assign cif.i1_valid = 1'b0;

  assign cmt.rrat0_en       = 1'b0;
  assign cmt.rrat1_en       = 1'b0;
  assign cmt.stb0_en        = 1'b0;
  assign cmt.stb1_en        = 1'b0;
  assign cmt.rat0_en        = 1'b0;
  assign cmt.rat1_en        = 1'b0;
  assign cmt.i0_path_sel    = 1'b0;
  assign cmt.i1_path_sel    = 1'b0;
  assign cmt.i0_rd_addr_cmt = '0;
  assign cmt.i1_rd_addr_cmt = '0;
  assign cmt.i0_rob_tag_cmt = '0;
  assign cmt.i1_rob_tag_cmt = '0;
  assign cmt.i0_can_retire  = 1'b0;
  assign cmt.i1_can_retire  = 1'b0;

  assign mif.imem_req   = 1'b0;
  assign mif.imem_addr0 = '0;
  assign mif.imem_addr1 = '0;
  assign mif.dmem_req   = 1'b0;
  assign mif.dmem_we    = 1'b0;
  assign mif.dmem_addr  = '0;
  assign mif.dmem_wdata = '0;

  cpu_env u_env (
    .clk        (clk),
    .rst_n      (rst_n),
    .cpu_mon_if (cif),
    .cmt_mon_if (cmt),
    .mem_drv_if (mif),
    .mem_mon_if (mif)
  );

  cpu_test u_test (
    .clk   (clk),
    .rst_n (rst_n),
    .vif   (cif)
  );

  initial begin
    wait (rst_n === 1'b1);
    repeat (200) @(posedge clk);
    $display("[tb_top] done");
    $finish;
  end
endmodule
