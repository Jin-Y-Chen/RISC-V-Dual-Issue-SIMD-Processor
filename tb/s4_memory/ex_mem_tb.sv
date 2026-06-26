`timescale 1ns / 1ps

// ex_mem_tb — odd-lane EX/MEM copies (od0, od1). Even-lane ALU skips ex_mem
// and routes to ex_mem_wb EX bank.
module ex_mem_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic clk;
  logic rst_n;
  logic enable;

  logic stall_od0;
  logic stall_od1;

  // --- od0 EX inputs (I0 / odd copy) ---
  logic        od0_enable_ex;
  logic        od0_reg_write_ex;
  logic [4:0]  od0_rd_ex;
  logic        od0_brch_taken_ex;
  logic [31:0] od0_brch_pc_ex;
  logic        od0_mem_en_ex;
  logic        od0_mem_act_ex;
  logic [31:0] od0_mem_addr_ex;
  logic [31:0] od0_mem_wdata_ex;
  logic [3:0]  od0_mem_besel_ex;
  logic [31:0] od0_link_pc_ex;
  logic [31:0] od0_alu_result_ex;
  logic        od0_use_link_ex;
  logic [31:0] od0_pc_ex;

  // --- od1 EX inputs (I1 / odd copy) ---
  logic        od1_enable_ex;
  logic        od1_reg_write_ex;
  logic [4:0]  od1_rd_ex;
  logic        od1_brch_taken_ex;
  logic [31:0] od1_brch_pc_ex;
  logic        od1_mem_en_ex;
  logic        od1_mem_act_ex;
  logic [31:0] od1_mem_addr_ex;
  logic [31:0] od1_mem_wdata_ex;
  logic [3:0]  od1_mem_besel_ex;
  logic [31:0] od1_link_pc_ex;
  logic [31:0] od1_alu_result_ex;
  logic        od1_use_link_ex;
  logic [31:0] od1_pc_ex;

  // --- od0 MEM outputs ---
  logic        od0_reg_write_mem;
  logic [4:0]  od0_rd_mem;
  logic        od0_brch_taken_mem;
  logic [31:0] od0_brch_pc_mem;
  logic        od0_mem_en_mem;
  logic        od0_mem_act_mem;
  logic [31:0] od0_mem_addr_mem;
  logic [31:0] od0_mem_wdata_mem;
  logic [3:0]  od0_mem_besel_mem;
  logic [31:0] od0_link_pc_mem;
  logic [31:0] od0_alu_result_mem;
  logic        od0_use_link_mem;
  logic [31:0] od0_pc_mem;

  // --- od1 MEM outputs ---
  logic        od1_reg_write_mem;
  logic [4:0]  od1_rd_mem;
  logic        od1_brch_taken_mem;
  logic [31:0] od1_brch_pc_mem;
  logic        od1_mem_en_mem;
  logic        od1_mem_act_mem;
  logic [31:0] od1_mem_addr_mem;
  logic [31:0] od1_mem_wdata_mem;
  logic [3:0]  od1_mem_besel_mem;
  logic [31:0] od1_link_pc_mem;
  logic [31:0] od1_alu_result_mem;
  logic        od1_use_link_mem;
  logic [31:0] od1_pc_mem;

  int pass_cnt;
  int fail_cnt;

  ex_mem dut (.*);

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    tb_advance(clk);
  endtask

  task automatic clear_ex;
    od0_enable_ex = 1'b0; od0_reg_write_ex = 1'b0;
    od0_rd_ex = '0; od0_brch_taken_ex = 1'b0; od0_brch_pc_ex = '0;
    od0_mem_en_ex = 1'b0; od0_mem_act_ex = 1'b0;
    od0_mem_addr_ex = '0; od0_mem_wdata_ex = '0; od0_mem_besel_ex = '0;
    od0_link_pc_ex = '0; od0_alu_result_ex = '0; od0_use_link_ex = 1'b0; od0_pc_ex = '0;
    od1_enable_ex = 1'b0; od1_reg_write_ex = 1'b0;
    od1_rd_ex = '0; od1_brch_taken_ex = 1'b0; od1_brch_pc_ex = '0;
    od1_mem_en_ex = 1'b0; od1_mem_act_ex = 1'b0;
    od1_mem_addr_ex = '0; od1_mem_wdata_ex = '0; od1_mem_besel_ex = '0;
    od1_link_pc_ex = '0; od1_alu_result_ex = '0; od1_use_link_ex = 1'b0; od1_pc_ex = '0;
  endtask

  task automatic check_od0_mem(
    input string       name,
    input string       detail,
    input logic        exp_rw,
    input logic [4:0]  exp_rd,
    input logic        exp_brch,
    input logic [31:0] exp_brch_pc,
    input logic        exp_mem_en,
    input logic        exp_mem_act,
    input logic [31:0] exp_mem_addr,
    input logic [31:0] exp_mem_wdata,
    input logic [3:0]  exp_besel,
    input logic [31:0] exp_link,
    input logic [31:0] exp_alu,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (od0_reg_write_mem === exp_rw) && (od0_rd_mem === exp_rd) &&
           (od0_brch_taken_mem === exp_brch) && (od0_brch_pc_mem === exp_brch_pc) &&
           (od0_mem_en_mem === exp_mem_en) && (od0_mem_act_mem === exp_mem_act) &&
           (od0_mem_addr_mem === exp_mem_addr) && (od0_mem_wdata_mem === exp_mem_wdata) &&
           (od0_mem_besel_mem === exp_besel) && (od0_link_pc_mem === exp_link) &&
           (od0_alu_result_mem === exp_alu) && (od0_pc_mem === exp_pc);
    tb_report_open(pass, name, detail);
    tb_field_bit("od0_reg_write_mem", od0_reg_write_mem, exp_rw);
    tb_field_u5("od0_rd_mem", od0_rd_mem, exp_rd);
    tb_field_bit("od0_brch_taken_mem", od0_brch_taken_mem, exp_brch);
    tb_field_u32("od0_brch_pc_mem", od0_brch_pc_mem, exp_brch_pc);
    tb_field_bit("od0_mem_en_mem", od0_mem_en_mem, exp_mem_en);
    tb_field_bit("od0_mem_act_mem", od0_mem_act_mem, exp_mem_act);
    tb_field_u32("od0_mem_addr_mem", od0_mem_addr_mem, exp_mem_addr);
    tb_field_u32("od0_mem_wdata_mem", od0_mem_wdata_mem, exp_mem_wdata);
    tb_field_be("od0_mem_besel_mem", od0_mem_besel_mem, exp_besel);
    tb_field_u32("od0_link_pc_mem", od0_link_pc_mem, exp_link);
    tb_field_u32("od0_alu_result_mem", od0_alu_result_mem, exp_alu);
    tb_field_u32("od0_pc_mem", od0_pc_mem, exp_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_od1_mem(
    input string       name,
    input string       detail,
    input logic        exp_rw,
    input logic [4:0]  exp_rd,
    input logic        exp_mem_en,
    input logic        exp_mem_act,
    input logic [31:0] exp_mem_addr,
    input logic [31:0] exp_mem_wdata
  );
    bit pass;
    pass = (od1_reg_write_mem === exp_rw) && (od1_rd_mem === exp_rd) &&
           (od1_mem_en_mem === exp_mem_en) && (od1_mem_act_mem === exp_mem_act) &&
           (od1_mem_addr_mem === exp_mem_addr) && (od1_mem_wdata_mem === exp_mem_wdata);
    tb_report_open(pass, name, detail);
    tb_field_bit("od1_reg_write_mem", od1_reg_write_mem, exp_rw);
    tb_field_u5("od1_rd_mem", od1_rd_mem, exp_rd);
    tb_field_bit("od1_mem_en_mem", od1_mem_en_mem, exp_mem_en);
    tb_field_bit("od1_mem_act_mem", od1_mem_act_mem, exp_mem_act);
    tb_field_u32("od1_mem_addr_mem", od1_mem_addr_mem, exp_mem_addr);
    tb_field_u32("od1_mem_wdata_mem", od1_mem_wdata_mem, exp_mem_wdata);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    enable    = 1'b1;
    stall_od0 = 1'b0;
    stall_od1 = 1'b0;
    pass_cnt  = 0;
    fail_cnt  = 0;
    clear_ex();

    rst_n = 1'b0;
    repeat (2) tick();
    rst_n = 1'b1;
    tick();

    tb_banner("ex_mem_tb - odd-lane od0/od1 (even bypasses ex_mem)");

    check_od0_mem("reset_od0", "od0 bubble after reset",
                  1'b0, 5'd0, 1'b0, 32'd0,
                  1'b0, 1'b0, 32'd0, 32'd0, 4'd0, 32'd0, 32'd0, 32'd0);
    check_od1_mem("reset_od1", "od1 bubble after reset",
                  1'b0, 5'd0, 1'b0, 1'b0, 32'd0, 32'd0);

    clear_ex();
    od0_enable_ex      = 1'b1;
    od0_reg_write_ex   = 1'b1;
    od0_rd_ex          = 5'd7;
    od0_mem_en_ex      = 1'b1;
    od0_mem_act_ex     = 1'b0;
    od0_mem_addr_ex    = 32'h400;
    od0_pc_ex          = 32'h0000_1008;
    tick();
    check_od0_mem("od0_load", "I0 LW latched in ex_mem",
                  1'b1, 5'd7, 1'b0, 32'd0,
                  1'b1, 1'b0, 32'h400, 32'd0, 4'd0, 32'd0, 32'd0, 32'h0000_1008);

    clear_ex();
    od1_enable_ex      = 1'b1;
    od1_reg_write_ex   = 1'b0;
    od1_mem_en_ex      = 1'b1;
    od1_mem_act_ex     = 1'b1;
    od1_mem_addr_ex    = 32'h200;
    od1_mem_wdata_ex   = 32'hDEAD_BEEF;
    od1_mem_besel_ex   = 4'b1111;
    tick();
    check_od1_mem("od1_store", "I1 SW addr=200 wdata=DEAD_BEEF",
                  1'b0, 5'd0, 1'b1, 1'b1, 32'h200, 32'hDEAD_BEEF);

    clear_ex();
    od0_enable_ex      = 1'b1;
    od0_reg_write_ex   = 1'b0;
    od0_brch_taken_ex  = 1'b1;
    od0_brch_pc_ex     = 32'h0000_2000;
    od0_pc_ex          = 32'h0000_1020;
    od1_enable_ex      = 1'b1;
    od1_mem_en_ex      = 1'b1;
    od1_mem_act_ex     = 1'b0;
    od1_mem_addr_ex    = 32'h800;
    od1_pc_ex          = 32'h0000_1024;
    tick();
    check_od0_mem("dual_od0", "od0 taken branch latched",
                  1'b0, 5'd0, 1'b1, 32'h0000_2000,
                  1'b0, 1'b0, 32'd0, 32'd0, 4'd0, 32'd0, 32'd0, 32'h0000_1020);
    check_od1_mem("dual_od1", "od1 LW latched alongside od0 branch",
                  1'b0, 5'd0, 1'b1, 1'b0, 32'h800, 32'd0);

    clear_ex();
    od0_enable_ex      = 1'b1;
    od0_reg_write_ex   = 1'b1;
    od0_rd_ex          = 5'd4;
    od0_mem_en_ex      = 1'b1;
    od0_mem_act_ex     = 1'b0;
    od0_mem_addr_ex    = 32'h100;
    od0_pc_ex          = 32'h0000_1030;
    tick();
    od0_mem_addr_ex    = 32'h999;
    od1_enable_ex      = 1'b1;
    od1_mem_en_ex      = 1'b1;
    od1_mem_act_ex     = 1'b1;
    od1_mem_addr_ex    = 32'h300;
    stall_od0          = 1'b1;
    tick();
    check_od0_mem("stall_od0_hold", "od0 stalled: holds previous latch",
                  1'b1, 5'd4, 1'b0, 32'd0,
                  1'b1, 1'b0, 32'h100, 32'd0, 4'd0, 32'd0, 32'd0, 32'h0000_1030);
    check_od1_mem("stall_od0_od1_adv", "od1 advances while od0 stalled",
                  1'b0, 5'd0, 1'b1, 1'b1, 32'h300, 32'd0);
    stall_od0 = 1'b0;
    tick();
    check_od0_mem("stall_od0_release", "od0 captures after stall clears",
                  1'b1, 5'd4, 1'b0, 32'd0,
                  1'b1, 1'b0, 32'h999, 32'd0, 4'd0, 32'd0, 32'd0, 32'h0000_1030);

    clear_ex();
    od0_enable_ex      = 1'b0;
    od0_reg_write_ex   = 1'b1;
    od0_rd_ex          = 5'd11;
    od0_mem_en_ex      = 1'b1;
    od0_pc_ex          = 32'h0000_1040;
    tick();
    check_od0_mem("enable_gate", "enable=0: reg_write_mem gated, payload still latches",
                  1'b0, 5'd11, 1'b0, 32'd0,
                  1'b1, 1'b0, 32'd0, 32'd0, 4'd0, 32'd0, 32'd0, 32'h0000_1040);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "ex_mem_tb failed");
    $finish;
  end

endmodule
