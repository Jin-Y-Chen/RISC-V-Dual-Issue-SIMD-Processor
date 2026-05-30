`timescale 1ns / 1ps

// EX/MEM register test: even ALU bubble + odd load/store/branch through pipeline.
module ex_mem_tb;

  import spu_lite_pkg::*;

  `include "tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic clk;
  logic rst_n;
  logic stall;
  logic flush;

  logic        even_valid_ex;
  logic        even_reg_write_ex;
  logic [4:0]  even_rd_ex;
  logic [31:0] even_alu_result_ex;

  logic        even_valid_mem;
  logic        even_reg_write_mem;
  logic [4:0]  even_rd_mem;
  logic [31:0] even_alu_result_mem;

  logic        odd_valid_ex;
  logic        odd_reg_write_ex;
  logic [4:0]  odd_rd_ex;
  logic [31:0] odd_link_data_ex;
  logic        odd_mem_read_ex;
  logic        odd_mem_write_ex;
  logic [31:0] odd_mem_addr_ex;
  logic [31:0] odd_mem_wdata_ex;
  logic [3:0]  odd_mem_be_ex;
  logic        odd_branch_taken_ex;
  logic [31:0] odd_branch_target_ex;
  logic        odd_jump_ex;
  logic [31:0] odd_jump_target_ex;

  logic        odd_valid_mem;
  logic        odd_reg_write_mem;
  logic [4:0]  odd_rd_mem;
  logic [31:0] odd_link_data_mem;
  logic        odd_mem_read_mem;
  logic        odd_mem_write_mem;
  logic [31:0] odd_mem_addr_mem;
  logic [31:0] odd_mem_wdata_mem;
  logic [3:0]  odd_mem_be_mem;
  logic        odd_branch_taken_mem;
  logic [31:0] odd_branch_target_mem;
  logic        odd_jump_mem;
  logic [31:0] odd_jump_target_mem;

  int pass_cnt;
  int fail_cnt;

  ex_mem dut (.*);

  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic check_even(
    input string name,
    input logic exp_v,
    input logic exp_rw,
    input logic [4:0] exp_rd,
    input logic [31:0] exp_res
  );
    if (even_valid_mem !== exp_v) begin
      tb_fail_msg($sformatf("%s: even_valid_mem", name));
      fail_cnt++;
    end else if (even_reg_write_mem !== exp_rw) begin
      tb_fail_msg($sformatf("%s: even_reg_write_mem", name));
      fail_cnt++;
    end else if (even_rd_mem !== exp_rd) begin
      tb_fail_msg($sformatf("%s: even_rd_mem", name));
      fail_cnt++;
    end else if (even_alu_result_mem !== exp_res) begin
      tb_fail_msg($sformatf("%s: even_alu_result_mem exp %h got %h", name, exp_res, even_alu_result_mem));
      fail_cnt++;
    end else begin
      tb_pass_msg(name);
      pass_cnt++;
    end
  endtask

  task automatic check_odd_store(
    input string name,
    input logic [31:0] exp_addr,
    input logic [31:0] exp_wdata
  );
    if (!odd_valid_mem || !odd_mem_write_mem) begin
      tb_fail_msg($sformatf("%s: odd mem write flags", name));
      fail_cnt++;
    end else if (odd_mem_addr_mem !== exp_addr || odd_mem_wdata_mem !== exp_wdata) begin
      tb_fail_msg($sformatf("%s: odd mem data", name));
      fail_cnt++;
    end else begin
      tb_pass_msg(name);
      pass_cnt++;
    end
  endtask

  initial begin
    stall = 0;
    flush = 0;
    pass_cnt = 0;
    fail_cnt = 0;

    even_valid_ex = 0;
    odd_valid_ex  = 0;

    rst_n = 0;
    repeat (2) tick();
    rst_n = 1;
    tick();

    tb_banner("ex_mem_tb");

    // Even: latch ALU result
    even_valid_ex      = 1;
    even_reg_write_ex  = 1;
    even_rd_ex         = 5'd5;
    even_alu_result_ex = 32'd42;
    odd_valid_ex       = 0;
    tick();
    check_even("even add latched", 1, 1, 5'd5, 32'd42);

    // Stall: hold previous MEM values while EX changes
    stall = 1;
    even_alu_result_ex = 32'd99;
    tick();
    check_even("even stall holds", 1, 1, 5'd5, 32'd42);
    stall = 0;
    even_alu_result_ex = 32'd99;
    tick();
    check_even("even after stall", 1, 1, 5'd5, 32'd99);

    // Odd: store through EX/MEM
    even_valid_ex      = 0;
    odd_valid_ex       = 1;
    odd_reg_write_ex   = 0;
    odd_mem_read_ex    = 0;
    odd_mem_write_ex   = 1;
    odd_mem_addr_ex    = 32'h100;
    odd_mem_wdata_ex   = 32'hDEAD_BEEF;
    odd_mem_be_ex      = 4'b1111;
    odd_branch_taken_ex = 0;
    odd_jump_ex        = 0;
    tick();
    check_odd_store("odd store latched", 32'h100, 32'hDEAD_BEEF);

    // Flush clears both lanes
    flush = 1;
    even_valid_ex = 1;
    odd_valid_ex  = 1;
    tick();
    flush = 0;
    if (even_valid_mem || odd_valid_mem) begin
      tb_fail_msg("flush did not clear valid");
      fail_cnt++;
    end else begin
      tb_pass_msg("flush bubble");
      pass_cnt++;
    end

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "ex_mem_tb failed");
    $finish;
  end

endmodule
