`timescale 1ns / 1ps

// EX/MEM: independent even and odd pipeline registers (per-lane stall / flush).
module ex_mem_tb;

  import spu_lite_pkg::*;

  `include "tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic clk;
  logic rst_n;
  logic stall_even;
  logic stall_odd;
  logic flush_even;
  logic flush_odd;

  logic        even_valid_ex;
  logic        even_reg_write_ex;
  logic [4:0]  even_rd_ex;
  logic [31:0] even_alu_result_ex;
  logic [31:0] even_pc_ex;

  logic        even_valid_mem;
  logic        even_reg_write_mem;
  logic [4:0]  even_rd_mem;
  logic [31:0] even_alu_result_mem;
  logic [31:0] even_pc_mem;

  logic        odd_valid_ex;
  logic        odd_reg_write_ex;
  logic [4:0]  odd_rd_ex;
  logic [31:0] odd_link_data_ex;
  logic [31:0] odd_wb_data_ex;
  logic        odd_mem_read_ex;
  logic        odd_mem_write_ex;
  logic [31:0] odd_mem_addr_ex;
  logic [31:0] odd_mem_wdata_ex;
  logic [3:0]  odd_mem_besel_ex;
  logic        odd_brch_taken_ex;
  logic [31:0] odd_brch_target_ex;
  logic        odd_jmp_ex;
  logic [31:0] odd_jmp_target_ex;

  logic        odd_valid_mem;
  logic        odd_reg_write_mem;
  logic [4:0]  odd_rd_mem;
  logic [31:0] odd_link_data_mem;
  logic [31:0] odd_wb_data_mem;
  logic        odd_mem_read_mem;
  logic        odd_mem_write_mem;
  logic [31:0] odd_mem_addr_mem;
  logic [31:0] odd_mem_wdata_mem;
  logic [3:0]  odd_mem_besel_mem;
  logic        odd_brch_taken_mem;
  logic [31:0] odd_brch_target_mem;
  logic        odd_jmp_mem;
  logic [31:0] odd_jmp_target_mem;

  int pass_cnt;
  int fail_cnt;

  ex_mem_even u_ex_mem_even (
    .clk            (clk),
    .rst_n          (rst_n),
    .stall_even     (stall_even),
    .flush_even     (flush_even),
    .valid_ex       (even_valid_ex),
    .reg_write_ex   (even_reg_write_ex),
    .rd_ex          (even_rd_ex),
    .alu_result_ex  (even_alu_result_ex),
    .pc_ex          (even_pc_ex),
    .valid_mem      (even_valid_mem),
    .reg_write_mem  (even_reg_write_mem),
    .rd_mem         (even_rd_mem),
    .alu_result_mem (even_alu_result_mem),
    .pc_mem         (even_pc_mem)
  );

  ex_mem_odd u_ex_mem_odd (
    .clk               (clk),
    .rst_n             (rst_n),
    .stall_odd         (stall_odd),
    .flush_odd         (flush_odd),
    .valid_ex          (odd_valid_ex),
    .reg_write_ex      (odd_reg_write_ex),
    .rd_ex             (odd_rd_ex),
    .link_data_ex      (odd_link_data_ex),
    .wb_data_ex        (odd_wb_data_ex),
    .mem_read_ex       (odd_mem_read_ex),
    .mem_write_ex      (odd_mem_write_ex),
    .mem_addr_ex       (odd_mem_addr_ex),
    .mem_wdata_ex      (odd_mem_wdata_ex),
    .mem_besel_ex         (odd_mem_besel_ex),
    .brch_taken_ex     (odd_brch_taken_ex),
    .brch_target_ex    (odd_brch_target_ex),
    .jmp_ex            (odd_jmp_ex),
    .jmp_target_ex     (odd_jmp_target_ex),
    .valid_mem         (odd_valid_mem),
    .reg_write_mem     (odd_reg_write_mem),
    .rd_mem            (odd_rd_mem),
    .link_data_mem     (odd_link_data_mem),
    .wb_data_mem       (odd_wb_data_mem),
    .mem_read_mem      (odd_mem_read_mem),
    .mem_write_mem     (odd_mem_write_mem),
    .mem_addr_mem      (odd_mem_addr_mem),
    .mem_wdata_mem     (odd_mem_wdata_mem),
    .mem_besel_mem        (odd_mem_besel_mem),
    .brch_taken_mem    (odd_brch_taken_mem),
    .brch_target_mem   (odd_brch_target_mem),
    .jmp_mem           (odd_jmp_mem),
    .jmp_target_mem    (odd_jmp_target_mem)
  );

  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic check_even(
    input string       name,
    input string       detail,
    input logic        exp_v,
    input logic        exp_rw,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_res,
    input logic [31:0] exp_pc = even_pc_ex
  );
    if (even_valid_mem !== exp_v || even_reg_write_mem !== exp_rw ||
        even_rd_mem !== exp_rd || even_alu_result_mem !== exp_res ||
        even_pc_mem !== exp_pc) begin
      tb_fail_detail(name, $sformatf("%s, got v=%0d rw=%0d rd=x%0d res=%h pc=%h",
        detail, even_valid_mem, even_reg_write_mem, even_rd_mem, even_alu_result_mem,
        even_pc_mem));
      fail_cnt++;
    end else begin
      tb_pass_detail(name, detail);
      pass_cnt++;
    end
  endtask

  task automatic check_odd_store(
    input string       name,
    input string       detail,
    input logic [31:0] exp_addr,
    input logic [31:0] exp_wdata
  );
    if (!odd_valid_mem || !odd_mem_write_mem ||
        odd_mem_addr_mem !== exp_addr || odd_mem_wdata_mem !== exp_wdata) begin
      tb_fail_detail(name, $sformatf("%s, got addr=%h wdata=%h", detail,
        odd_mem_addr_mem, odd_mem_wdata_mem));
      fail_cnt++;
    end else begin
      tb_pass_detail(name, detail);
      pass_cnt++;
    end
  endtask

  task automatic check_odd_lui(
    input string       name,
    input string       detail,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_wb
  );
    if (!odd_valid_mem || !odd_reg_write_mem || odd_rd_mem !== exp_rd ||
        odd_wb_data_mem !== exp_wb) begin
      tb_fail_detail(name, $sformatf("%s, got rw=%0d rd=x%0d wb=%h", detail,
        odd_reg_write_mem, odd_rd_mem, odd_wb_data_mem));
      fail_cnt++;
    end else begin
      tb_pass_detail(name, detail);
      pass_cnt++;
    end
  endtask

  initial begin
    stall_even = 0;
    stall_odd  = 0;
    flush_even = 0;
    flush_odd  = 0;
    pass_cnt   = 0;
    fail_cnt   = 0;

    even_valid_ex = 0;
    odd_valid_ex  = 0;

    rst_n = 0;
    repeat (2) tick();
    rst_n = 1;
    tick();

    tb_banner("ex_mem_tb - independent even / odd EX/MEM");
    tb_info_msg("Per-lane stall_even/stall_odd and flush_even/flush_odd");

    // Even only: latch ALU result (odd idle)
    even_valid_ex      = 1;
    even_reg_write_ex  = 1;
    even_rd_ex         = 5'd5;
    even_alu_result_ex = 32'd42;
    even_pc_ex         = 32'h0000_1004;
    odd_valid_ex       = 0;
    tick();
    check_even("even_latch", "even ALU, res=42 (rd=x5) pc=1004, odd idle",
      1, 1, 5'd5, 32'd42, 32'h0000_1004);
    if (odd_valid_mem) begin
      tb_fail_detail("odd_idle", "odd_valid_mem should stay 0");
      fail_cnt++;
    end else begin
      tb_pass_detail("odd_idle", "odd lane not latched");
      pass_cnt++;
    end

    // Stall even only; odd advances independently
    stall_even = 1;
    even_alu_result_ex = 32'd99;
    even_pc_ex         = 32'h0000_1008;
    odd_valid_ex       = 1;
    odd_reg_write_ex   = 1;
    odd_rd_ex          = 5'd7;
    odd_link_data_ex   = 32'h1004;
    odd_wb_data_ex     = 32'h0004_5000;
    odd_mem_read_ex    = 0;
    odd_mem_write_ex   = 0;
    odd_brch_taken_ex = 0;
    odd_jmp_ex        = 0;
    tick();
    check_even("even_stall_hold", "even stall holds res=42 pc=1004",
      1, 1, 5'd5, 32'd42, 32'h0000_1004);
    check_odd_lui("odd_while_even_stall", "odd LUI wb=0x45000 latched while even stalled",
      5'd7, 32'h0004_5000);
    stall_even = 0;
    even_alu_result_ex = 32'd99;
    tick();
    check_even("even_after_stall", "even after stall, res=99 pc=1008",
      1, 1, 5'd5, 32'd99, 32'h0000_1008);

    // Odd only: store
    even_valid_ex       = 0;
    odd_valid_ex        = 1;
    odd_reg_write_ex    = 0;
    odd_mem_read_ex     = 0;
    odd_mem_write_ex    = 1;
    odd_mem_addr_ex     = 32'h100;
    odd_mem_wdata_ex    = 32'hDEAD_BEEF;
    odd_mem_besel_ex       = 4'b1111;
    odd_brch_taken_ex = 0;
    odd_jmp_ex         = 0;
    tick();
    check_odd_store("odd_store", "SW addr=100 wdata=DEAD_BEEF",
      32'h100, 32'hDEAD_BEEF);
    if (even_valid_mem && even_alu_result_mem == 32'd99) begin
      tb_pass_detail("even_hold", "even MEM unchanged while odd store");
      pass_cnt++;
    end else begin
      tb_fail_detail("even_hold", "even should still hold prior latch");
      fail_cnt++;
    end

    // Flush even only; odd holds store
    flush_even = 1;
    even_valid_ex = 1;
    tick();
    flush_even = 0;
    if (even_valid_mem) begin
      tb_fail_detail("flush_even", "even_valid_mem not cleared");
      fail_cnt++;
    end else begin
      tb_pass_detail("flush_even", "even flushed, odd store retained");
      pass_cnt++;
    end
    check_odd_store("odd_after_even_flush", "odd still has store after flush_even",
      32'h100, 32'hDEAD_BEEF);

    // Flush odd
    flush_odd = 1;
    tick();
    flush_odd = 0;
    if (odd_valid_mem) begin
      tb_fail_detail("flush_odd", "odd_valid_mem not cleared");
      fail_cnt++;
    end else begin
      tb_pass_detail("flush_odd", "odd flushed");
      pass_cnt++;
    end

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "ex_mem_tb failed");
    $finish;
  end

endmodule
