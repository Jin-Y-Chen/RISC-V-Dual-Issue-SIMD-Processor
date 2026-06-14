`timescale 1ns / 1ps

// ex_mem_tb — four EX/MEM copies (ev0, ev1, od0, od1); reset, latch, stall,
// dual-issue pairs, and enable-qualified reg_write.
module ex_mem_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic clk;
  logic rst_n;

  logic stall_ev0;
  logic stall_ev1;
  logic stall_od0;
  logic stall_od1;

  // --- ev0 EX inputs (I0 / even copy) ---
  logic        ev0_enable_ex;
  logic        ev0_reg_write_ex;
  logic [4:0]  ev0_rd_ex;
  logic [31:0] ev0_alu_result_ex;
  logic [31:0] ev0_pc_ex;

  // --- ev1 EX inputs (I1 / even copy) ---
  logic        ev1_enable_ex;
  logic        ev1_reg_write_ex;
  logic [4:0]  ev1_rd_ex;
  logic [31:0] ev1_alu_result_ex;
  logic [31:0] ev1_pc_ex;

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
  logic [31:0] od1_pc_ex;

  // --- ev0 MEM outputs ---
  logic        ev0_reg_write_mem;
  logic [4:0]  ev0_rd_mem;
  logic [31:0] ev0_alu_result_mem;
  logic [31:0] ev0_pc_mem;

  // --- ev1 MEM outputs ---
  logic        ev1_reg_write_mem;
  logic [4:0]  ev1_rd_mem;
  logic [31:0] ev1_alu_result_mem;
  logic [31:0] ev1_pc_mem;

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
  logic [31:0] od1_pc_mem;

  int pass_cnt;
  int fail_cnt;

  ex_mem dut (.*);

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic clear_ex;
    ev0_enable_ex = 1'b0; ev0_reg_write_ex = 1'b0;
    ev0_rd_ex = '0; ev0_alu_result_ex = '0; ev0_pc_ex = '0;
    ev1_enable_ex = 1'b0; ev1_reg_write_ex = 1'b0;
    ev1_rd_ex = '0; ev1_alu_result_ex = '0; ev1_pc_ex = '0;
    od0_enable_ex = 1'b0; od0_reg_write_ex = 1'b0;
    od0_rd_ex = '0; od0_brch_taken_ex = 1'b0; od0_brch_pc_ex = '0;
    od0_mem_en_ex = 1'b0; od0_mem_act_ex = 1'b0;
    od0_mem_addr_ex = '0; od0_mem_wdata_ex = '0; od0_mem_besel_ex = '0;
    od0_link_pc_ex = '0; od0_alu_result_ex = '0; od0_pc_ex = '0;
    od1_enable_ex = 1'b0; od1_reg_write_ex = 1'b0;
    od1_rd_ex = '0; od1_brch_taken_ex = 1'b0; od1_brch_pc_ex = '0;
    od1_mem_en_ex = 1'b0; od1_mem_act_ex = 1'b0;
    od1_mem_addr_ex = '0; od1_mem_wdata_ex = '0; od1_mem_besel_ex = '0;
    od1_link_pc_ex = '0; od1_alu_result_ex = '0; od1_pc_ex = '0;
  endtask

  task automatic check_ev0_mem(
    input string       name,
    input string       detail,
    input logic        exp_rw,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_alu,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (ev0_reg_write_mem === exp_rw) && (ev0_rd_mem === exp_rd) &&
           (ev0_alu_result_mem === exp_alu) && (ev0_pc_mem === exp_pc);
    tb_report_open(pass, name, detail);
    tb_field_bit("ev0_reg_write_mem", ev0_reg_write_mem, exp_rw);
    tb_field_u5("ev0_rd_mem", ev0_rd_mem, exp_rd);
    tb_field_u32("ev0_alu_result_mem", ev0_alu_result_mem, exp_alu);
    tb_field_u32("ev0_pc_mem", ev0_pc_mem, exp_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_ev1_mem(
    input string       name,
    input string       detail,
    input logic        exp_rw,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_alu,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (ev1_reg_write_mem === exp_rw) && (ev1_rd_mem === exp_rd) &&
           (ev1_alu_result_mem === exp_alu) && (ev1_pc_mem === exp_pc);
    tb_report_open(pass, name, detail);
    tb_field_bit("ev1_reg_write_mem", ev1_reg_write_mem, exp_rw);
    tb_field_u5("ev1_rd_mem", ev1_rd_mem, exp_rd);
    tb_field_u32("ev1_alu_result_mem", ev1_alu_result_mem, exp_alu);
    tb_field_u32("ev1_pc_mem", ev1_pc_mem, exp_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
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

  task automatic check_ev_bubble(
    input string name,
    input string detail,
    input bit    is_ev0,
    input bit    is_ev1
  );
    if (is_ev0)
      check_ev0_mem(name, detail, 1'b0, 5'd0, 32'd0, 32'd0);
    if (is_ev1)
      check_ev1_mem(name, detail, 1'b0, 5'd0, 32'd0, 32'd0);
  endtask

  initial begin
    stall_ev0 = 1'b0;
    stall_ev1 = 1'b0;
    stall_od0 = 1'b0;
    stall_od1 = 1'b0;
    pass_cnt  = 0;
    fail_cnt  = 0;
    clear_ex();

    rst_n = 1'b0;
    repeat (2) tick();
    rst_n = 1'b1;
    tick();

    tb_banner("ex_mem_tb - four copies: ev0, ev1, od0, od1");

    // --- Reset clears all four copies ---
    check_ev0_mem("reset_ev0", "ev0 bubble after reset",
                  1'b0, 5'd0, 32'd0, 32'd0);
    check_ev1_mem("reset_ev1", "ev1 bubble after reset",
                  1'b0, 5'd0, 32'd0, 32'd0);
    check_od0_mem("reset_od0", "od0 bubble after reset",
                  1'b0, 5'd0, 1'b0, 32'd0,
                  1'b0, 1'b0, 32'd0, 32'd0, 4'd0, 32'd0, 32'd0, 32'd0);
    check_od1_mem("reset_od1", "od1 bubble after reset",
                  1'b0, 5'd0, 1'b0, 1'b0, 32'd0, 32'd0);

    // --- ev0 only: I0 ADD ---
    clear_ex();
    ev0_enable_ex      = 1'b1;
    ev0_reg_write_ex   = 1'b1;
    ev0_rd_ex          = 5'd5;
    ev0_alu_result_ex  = 32'd42;
    ev0_pc_ex          = 32'h0000_1000;
    tick();
    check_ev0_mem("ev0_latch", "I0 ADD res=42 rd=x5 pc=1000",
                  1'b1, 5'd5, 32'd42, 32'h0000_1000);
    check_ev_bubble("ev0_only_ev1", "ev1 idle while ev0 latches", 1'b0, 1'b1);

    // --- ev1 only: I1 SUB ---
    clear_ex();
    ev1_enable_ex      = 1'b1;
    ev1_reg_write_ex   = 1'b1;
    ev1_rd_ex          = 5'd6;
    ev1_alu_result_ex  = 32'd99;
    ev1_pc_ex          = 32'h0000_1004;
    tick();
    check_ev1_mem("ev1_latch", "I1 SUB res=99 rd=x6 pc=1004",
                  1'b1, 5'd6, 32'd99, 32'h0000_1004);

    // --- od0 only: I0 LUI ---
    clear_ex();
    od0_enable_ex      = 1'b1;
    od0_reg_write_ex   = 1'b1;
    od0_rd_ex          = 5'd7;
    od0_alu_result_ex  = 32'h0004_5000;
    od0_pc_ex          = 32'h0000_1008;
    tick();
    check_od0_mem("od0_lui", "I0 LUI wb=45000 rd=x7 pc=1008",
                  1'b1, 5'd7, 1'b0, 32'd0,
                  1'b0, 1'b0, 32'd0, 32'd0, 4'd0, 32'd0,
                  32'h0004_5000, 32'h0000_1008);

    // --- od1 only: I1 SW ---
    clear_ex();
    od1_enable_ex      = 1'b1;
    od1_reg_write_ex   = 1'b0;
    od1_rd_ex          = 5'd0;
    od1_mem_en_ex      = 1'b1;
    od1_mem_act_ex     = 1'b1;
    od1_mem_addr_ex    = 32'h200;
    od1_mem_wdata_ex   = 32'hDEAD_BEEF;
    od1_mem_besel_ex   = 4'b1111;
    od1_pc_ex          = 32'h0000_100C;
    tick();
    check_od1_mem("od1_store", "I1 SW addr=200 wdata=DEAD_BEEF",
                  1'b0, 5'd0, 1'b1, 1'b1, 32'h200, 32'hDEAD_BEEF);

    // --- Dual mixed: ev0 ADD + od1 LW (typical even+odd pair) ---
    clear_ex();
    ev0_enable_ex      = 1'b1;
    ev0_reg_write_ex   = 1'b1;
    ev0_rd_ex          = 5'd1;
    ev0_alu_result_ex  = 32'd10;
    ev0_pc_ex          = 32'h0000_1010;
    od1_enable_ex      = 1'b1;
    od1_reg_write_ex   = 1'b1;
    od1_rd_ex          = 5'd8;
    od1_mem_en_ex      = 1'b1;
    od1_mem_act_ex     = 1'b0;
    od1_mem_addr_ex    = 32'h400;
    od1_pc_ex          = 32'h0000_1014;
    tick();
    check_ev0_mem("dual_ev0", "mixed pair ev0 ADD x1=10",
                  1'b1, 5'd1, 32'd10, 32'h0000_1010);
    check_od1_mem("dual_od1", "mixed pair od1 LW x8 addr=400",
                  1'b1, 5'd8, 1'b1, 1'b0, 32'h400, 32'd0);

    // --- Even pair: ev0 + ev1 same cycle ---
    clear_ex();
    ev0_enable_ex      = 1'b1;
    ev0_reg_write_ex   = 1'b1;
    ev0_rd_ex          = 5'd2;
    ev0_alu_result_ex  = 32'd20;
    ev0_pc_ex          = 32'h0000_1018;
    ev1_enable_ex      = 1'b1;
    ev1_reg_write_ex   = 1'b1;
    ev1_rd_ex          = 5'd3;
    ev1_alu_result_ex  = 32'd30;
    ev1_pc_ex          = 32'h0000_101C;
    tick();
    check_ev0_mem("even_pair_ev0", "ev0+ev1 dual: ev0 res=20",
                  1'b1, 5'd2, 32'd20, 32'h0000_1018);
    check_ev1_mem("even_pair_ev1", "ev0+ev1 dual: ev1 res=30",
                  1'b1, 5'd3, 32'd30, 32'h0000_101C);

    // --- Odd pair: od0 branch + od1 JAL link ---
    clear_ex();
    od0_enable_ex      = 1'b1;
    od0_reg_write_ex   = 1'b0;
    od0_brch_taken_ex  = 1'b1;
    od0_brch_pc_ex     = 32'h0000_2000;
    od0_pc_ex          = 32'h0000_1020;
    od1_enable_ex      = 1'b1;
    od1_reg_write_ex   = 1'b1;
    od1_rd_ex          = 5'd1;
    od1_link_pc_ex     = 32'h0000_1028;
    od1_pc_ex          = 32'h0000_1024;
    tick();
    check_od0_mem("odd_pair_od0", "od0+od1 dual: taken branch",
                  1'b0, 5'd0, 1'b1, 32'h0000_2000,
                  1'b0, 1'b0, 32'd0, 32'd0, 4'd0, 32'd0, 32'd0, 32'h0000_1020);
    check_od1_mem("odd_pair_od1_rw", "od1 reg_write from slot control",
                  1'b1, 5'd1, 1'b0, 1'b0, 32'd0, 32'd0);

    // --- Stall ev0: establish state, then ev1 advances while ev0 holds ---
    clear_ex();
    ev0_enable_ex      = 1'b1;
    ev0_reg_write_ex   = 1'b1;
    ev0_rd_ex          = 5'd4;
    ev0_alu_result_ex  = 32'd77;
    ev0_pc_ex          = 32'h0000_1030;
    tick();  // latch baseline ev0 state
    ev0_alu_result_ex  = 32'd99;  // new EX payload (must not reach MEM while stalled)
    ev1_enable_ex      = 1'b1;
    ev1_reg_write_ex   = 1'b1;
    ev1_rd_ex          = 5'd9;
    ev1_alu_result_ex  = 32'd88;
    ev1_pc_ex          = 32'h0000_1034;
    stall_ev0          = 1'b1;
    tick();
    check_ev0_mem("stall_ev0_hold", "ev0 stalled: holds previous latch",
                  1'b1, 5'd4, 32'd77, 32'h0000_1030);
    check_ev1_mem("stall_ev0_ev1_adv", "ev1 advances while ev0 stalled",
                  1'b1, 5'd9, 32'd88, 32'h0000_1034);
    stall_ev0 = 1'b0;
    ev0_alu_result_ex = 32'd99;
    tick();
    check_ev0_mem("stall_ev0_release", "ev0 captures after stall clears",
                  1'b1, 5'd4, 32'd99, 32'h0000_1030);

    // --- enable=0 gates reg_write even when reg_write_ex=1 ---
    clear_ex();
    ev0_enable_ex      = 1'b0;
    ev0_reg_write_ex   = 1'b1;
    ev0_rd_ex          = 5'd11;
    ev0_alu_result_ex  = 32'hBAD0_BAD0;
    ev0_pc_ex          = 32'h0000_1040;
    tick();
    check_ev0_mem("enable_gate", "enable=0: reg_write_mem stays low",
                  1'b0, 5'd11, 32'hBAD0_BAD0, 32'h0000_1040);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "ex_mem_tb failed");
    $finish;
  end

endmodule
