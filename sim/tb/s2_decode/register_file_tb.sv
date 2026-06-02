`timescale 1ns / 1ps

// register_file_tb — dual-issue GPR: 4 read ports, 2 write ports, x0, bypass, wpc merge.
module register_file_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;

  logic [4:0]  even_rs1_addr;
  logic [4:0]  even_rs2_addr;
  reg_t        even_rs1_data;
  reg_t        even_rs2_data;

  logic [4:0]  odd_rs1_addr;
  logic [4:0]  odd_rs2_addr;
  reg_t        odd_rs1_data;
  reg_t        odd_rs2_data;

  logic        even_wen;
  logic [4:0]  even_rd;
  reg_t        even_wdata;
  reg_t        even_wpc;

  logic        odd_wen;
  logic [4:0]  odd_rd;
  reg_t        odd_wdata;
  reg_t        odd_wpc;

  int pass_cnt;
  int fail_cnt;

  register_file dut (.*);

  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic clear_writes;
    even_wen   = 1'b0;
    odd_wen    = 1'b0;
    even_rd    = 5'd0;
    odd_rd     = 5'd0;
    even_wdata = '0;
    odd_wdata  = '0;
    even_wpc   = '0;
    odd_wpc    = '0;
  endtask

  task automatic set_reads(
    input logic [4:0] e_rs1,
    input logic [4:0] e_rs2,
    input logic [4:0] o_rs1,
    input logic [4:0] o_rs2
  );
    even_rs1_addr = e_rs1;
    even_rs2_addr = e_rs2;
    odd_rs1_addr  = o_rs1;
    odd_rs2_addr  = o_rs2;
    #1;
  endtask

  task automatic drive_writes(
    input logic        e_wen,
    input logic [4:0]  e_rd,
    input reg_t        e_wdata,
    input reg_t        e_wpc,
    input logic        o_wen,
    input logic [4:0]  o_rd,
    input reg_t        o_wdata,
    input reg_t        o_wpc
  );
    even_wen   = e_wen;
    even_rd    = e_rd;
    even_wdata = e_wdata;
    even_wpc   = e_wpc;
    odd_wen    = o_wen;
    odd_rd     = o_rd;
    odd_wdata  = o_wdata;
    odd_wpc    = o_wpc;
  endtask

  task automatic check_reads(
    input string name,
    input string detail,
    input reg_t  exp_e_rs1,
    input reg_t  exp_e_rs2,
    input reg_t  exp_o_rs1,
    input reg_t  exp_o_rs2
  );
    bit pass;
    pass = (even_rs1_data === exp_e_rs1 && even_rs2_data === exp_e_rs2 &&
            odd_rs1_data  === exp_o_rs1  && odd_rs2_data  === exp_o_rs2);
    tb_report_open(pass, name, detail);
    tb_field_u32("even_rs1_data", even_rs1_data, exp_e_rs1);
    tb_field_u32("even_rs2_data", even_rs2_data, exp_e_rs2);
    tb_field_u32("odd_rs1_data", odd_rs1_data, exp_o_rs1);
    tb_field_u32("odd_rs2_data", odd_rs2_data, exp_o_rs2);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    even_rs1_addr = 5'd0;
    even_rs2_addr = 5'd0;
    odd_rs1_addr  = 5'd0;
    odd_rs2_addr  = 5'd0;
    clear_writes();

    rst_n = 1'b0;
    repeat (2) tick();
    rst_n = 1'b1;
    tick();

    tb_banner("register_file_tb - dual-issue GPR");
    tb_info_msg("Golden reads explicit per test (set_reads + check_reads)");

    // --- After reset ---
    set_reads(5'd1, 5'd2, 5'd3, 5'd4);
    check_reads("after_reset", "all GPRs read 0 after reset",
      32'd0, 32'd0, 32'd0, 32'd0);

    // --- Even lane write + read back on both lanes ---
    drive_writes(1'b1, 5'd5, 32'h0000_00AA, 32'h1000,
                 1'b0, 5'd0, 32'd0, 32'd0);
    tick();
    clear_writes();
    set_reads(5'd5, 5'd0, 5'd5, 5'd0);
    check_reads("even_wb_x5", "even WB x5 = 0xAA",
      32'h0000_00AA, 32'd0, 32'h0000_00AA, 32'd0);

    // --- Dual write different rd ---
    drive_writes(1'b1, 5'd3, 32'h0000_0003, 32'h1004,
                 1'b1, 5'd7, 32'h0000_0007, 32'h1008);
    tick();
    clear_writes();
    set_reads(5'd3, 5'd7, 5'd7, 5'd3);
    check_reads("dual_wb", "even x3, odd x7 same cycle",
      32'h0000_0003, 32'h0000_0007, 32'h0000_0007, 32'h0000_0003);

    // --- x0 read always zero ---
    set_reads(5'd0, 5'd0, 5'd0, 5'd0);
    check_reads("read_x0", "x0 reads as zero",
      32'd0, 32'd0, 32'd0, 32'd0);

    // --- Write x0 ignored ---
    drive_writes(1'b1, 5'd0, 32'hDEAD_BEEF, 32'h2000,
                 1'b1, 5'd5, 32'h0000_00BB, 32'h2004);
    tick();
    clear_writes();
    set_reads(5'd5, 5'd0, 5'd0, 5'd0);
    check_reads("wr_x0_ignore", "write x0 ignored; x5 = 0xBB",
      32'h0000_00BB, 32'd0, 32'd0, 32'd0);

    // --- Same rd, odd wpc wins (younger) ---
    drive_writes(1'b1, 5'd8, 32'h1111_1111, 32'h3000,
                 1'b1, 5'd8, 32'h2222_2222, 32'h3004);
    tick();
    clear_writes();
    set_reads(5'd8, 5'd0, 5'd8, 5'd0);
    check_reads("merge_odd_wins", "same rd x8; odd wpc wins",
      32'h2222_2222, 32'd0, 32'h2222_2222, 32'd0);

    // --- Same rd, even wpc wins (older even has higher pc tag here) ---
    drive_writes(1'b1, 5'd9, 32'hAAAA_AAAA, 32'h4008,
                 1'b1, 5'd9, 32'hBBBB_BBBB, 32'h4004);
    tick();
    clear_writes();
    set_reads(5'd9, 5'd0, 5'd9, 5'd0);
    check_reads("merge_even_wins", "same rd x9; even wpc wins",
      32'hAAAA_AAAA, 32'd0, 32'hAAAA_AAAA, 32'd0);

    // --- Write bypass (even) before posedge ---
    drive_writes(1'b1, 5'd12, 32'h0000_004D, 32'h5000,
                 1'b0, 5'd0, 32'd0, 32'd0);
    set_reads(5'd12, 5'd0, 5'd0, 5'd0);
    check_reads("bypass_even", "even WB bypass to even_rs1 same cycle",
      32'h0000_004D, 32'd0, 32'd0, 32'd0);
    tick();
    clear_writes();
    set_reads(5'd12, 5'd0, 5'd0, 5'd0);
    check_reads("bypass_even_hold", "x12 still 0x4D after commit",
      32'h0000_004D, 32'd0, 32'd0, 32'd0);

    // --- Write bypass (odd) + conflict bypass ---
    drive_writes(1'b1, 5'd15, 32'h0000_00EE, 32'h6000,
                 1'b1, 5'd15, 32'h0000_00FF, 32'h6004);
    set_reads(5'd15, 5'd0, 5'd15, 5'd0);
    check_reads("bypass_odd_wins", "same rd x15 bypass; odd wpc wins",
      32'h0000_00FF, 32'd0, 32'h0000_00FF, 32'd0);
    tick();
    clear_writes();

    // --- Four independent read ports in one cycle ---
    drive_writes(1'b1, 5'd20, 32'h0000_0020, 32'h7000,
                 1'b1, 5'd21, 32'h0000_0021, 32'h7004);
    tick();
    clear_writes();
    set_reads(5'd20, 5'd21, 5'd21, 5'd20);
    check_reads("four_ports", "four read ports in parallel",
      32'h0000_0020, 32'h0000_0021, 32'h0000_0021, 32'h0000_0020);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "register_file_tb failed");
    $finish;
  end

endmodule
