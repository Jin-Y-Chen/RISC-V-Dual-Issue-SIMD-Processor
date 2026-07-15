`timescale 1ns / 1ps

`include "../include/tb_console.svh"
import rv_dis_pkg::*;

// pc_tb — ctrl = {rst_n, enable, dispatch_stall, spec0_stall, spec1_stall, br_map[1:0]}
module pc_tb;

  localparam int          CLK_PERIOD  = 10;
  localparam int          CTRL_BITS   = 7;
  localparam int          N_VECTORS   = (1 << CTRL_BITS);
  localparam logic [31:0] TB_RESET_PC = 32'h0000_0000;
  localparam logic [31:0] PC0_IN      = 32'h0000_1000;
  localparam logic [31:0] PC1_IN      = 32'h0000_1004;

  logic        clk, rst_n, enable, dispatch_stall, spec0_stall, spec1_stall;
  br_map_t     branch_map_in;
  br_map_t     branch_map_out;
  logic [31:0] pc0_in, pc1_in, pc0, pc1;
  br_map_t     ref_branch_map_out;
  logic [31:0] ref_pc0, ref_pc1;
  int pass_cnt, fail_cnt;

  pc #(.RESET_PC(TB_RESET_PC)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .dispatch_stall(dispatch_stall),
    .spec0_stall(spec0_stall), .spec1_stall(spec1_stall),
    .branch_map_in(branch_map_in),
    .pc0_in(pc0_in), .pc1_in(pc1_in),
    .pc0_out(pc0), .pc1_out(pc1),
    .branch_map_out(branch_map_out)
  );

  pc_gm #(.RESET_PC(TB_RESET_PC)) u_gm (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .dispatch_stall(dispatch_stall),
    .spec0_stall(spec0_stall), .spec1_stall(spec1_stall),
    .branch_map_in(branch_map_in),
    .pc0_in(pc0_in), .pc1_in(pc1_in),
    .pc0_out(ref_pc0), .pc1_out(ref_pc1),
    .branch_map_out(ref_branch_map_out)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk;

  task automatic check_vector(input logic [CTRL_BITS-1:0] ctrl);
    bit pass;
    @(posedge clk);
    rst_n = 0; enable = 0; dispatch_stall = 0;
    spec0_stall = 0; spec1_stall = 0; branch_map_in = BR_MAP_NONE;
    pc0_in = PC0_IN; pc1_in = PC1_IN;
    #0;
    @(posedge clk);
    rst_n = ctrl[6]; enable = ctrl[5]; dispatch_stall = ctrl[4];
    spec0_stall = ctrl[3]; spec1_stall = ctrl[2];
    branch_map_in = br_map_t'(ctrl[1:0]);
    #0;

    pass = (pc0 === ref_pc0) && (pc1 === ref_pc1)
        && (branch_map_out === ref_branch_map_out);

    tb_report_open(pass, $sformatf("ctrl_%02x", ctrl), $sformatf("ctrl=%0b", ctrl));
    tb_log_section("check");
    tb_field_u32("br_map_out", {30'b0, branch_map_out}, {30'b0, ref_branch_map_out});
    tb_field_u32("pc0_out", pc0, ref_pc0);
    tb_field_u32("pc1_out", pc1, ref_pc1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    int unsigned ctrl;
    pass_cnt = 0; fail_cnt = 0;
    tb_banner($sformatf("pc_tb: DUT vs pc_gm.sv (%0d vectors)", N_VECTORS));
    for (ctrl = 0; ctrl < N_VECTORS; ctrl++)
      check_vector(ctrl[CTRL_BITS-1:0]);
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0) $error("pc_tb: %0d failure(s)", fail_cnt);
    $finish;
  end

endmodule
