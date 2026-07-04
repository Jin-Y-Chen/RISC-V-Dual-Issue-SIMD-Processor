`timescale 1ns / 1ps

// pc_tb — mode selects +4/+4 or +8/+8 from pc0_in/pc1_in; stall/disable hold.
module pc_tb;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;
  localparam logic [31:0] TB_RESET_PC = 32'h0000_1000;

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic        fetch_stall;
  logic        dispatch_stall;
  logic        mode;
  logic        spec0_en;
  logic        is_spec;
  logic [31:0] pc0_in;
  logic [31:0] pc1_in;
  logic [31:0] pc0;
  logic [31:0] pc1;

  int pass_cnt;
  int fail_cnt;

  pc #(
    .RESET_PC(TB_RESET_PC)
  ) dut (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    .fetch_stall     (fetch_stall),
    .dispatch_stall  (dispatch_stall),
    .mode            (mode),
    .spec0_en        (spec0_en),
    .pc0_in          (pc0_in),
    .pc1_in          (pc1_in),
    .is_spec         (is_spec),
    .pc0_out         (pc0),
    .pc1_out         (pc1)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic drive(
    input logic enable_v,
    input logic stall_v,
    input logic mode_v,
    input logic spec0_en_v,
    input logic [31:0] pc0_in_v,
    input logic [31:0] pc1_in_v
  );
    enable          = enable_v;
    fetch_stall     = stall_v;
    dispatch_stall  = 1'b0;
    mode            = mode_v;
    spec0_en        = spec0_en_v;
    pc0_in          = pc0_in_v;
    pc1_in          = pc1_in_v;
  endtask

  task automatic check_pair(
    input string       name,
    input string       detail,
    input logic [31:0] exp_pc0,
    input logic [31:0] exp_pc1
  );
    bit pass;
    pass = (pc0 === exp_pc0) && (pc1 === exp_pc1);
    tb_report_open(pass, name, detail);
    tb_field_u32("pc0", pc0, exp_pc0);
    tb_field_u32("pc1", pc1, exp_pc1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    enable = 1'b1;

    rst_n = 1'b0;
    drive(1'b1, 1'b0, 1'b0, 1'b0, 32'd0, 32'd0);
    tick();
    check_pair("reset", "RESET_PC pair after reset",
               TB_RESET_PC, TB_RESET_PC + 32'd4);

    rst_n = 1'b1;
    drive(1'b1, 1'b0, 1'b0, 1'b0, TB_RESET_PC, TB_RESET_PC + 32'd4);
    tick();
    check_pair("sequential_add", "mode=0 => +8/+8",
               TB_RESET_PC + 32'd8, TB_RESET_PC + 32'd12);

    drive(1'b1, 1'b0, 1'b1, 1'b1, 32'h2000, 32'h1008);
    tick();
    check_pair("spec_add", "mode=1 => +4/+4",
               32'h2004, 32'h100C);

    drive(1'b1, 1'b0, 1'b0, 1'b0, 32'h2000, 32'h2004);
    tick();
    check_pair("sequential_resume", "mode=0 => +8/+8",
               32'h2008, 32'h200C);

    drive(1'b1, 1'b1, 1'b0, 1'b0, 32'h3000, 32'h3004);
    tick();
    check_pair("stall_hold", "stall blocks update", 32'h2008, 32'h200C);

    drive(1'b0, 1'b0, 1'b0, 1'b0, 32'h4000, 32'h4004);
    tick();
    check_pair("disable_hold", "enable=0 holds pair", 32'h2008, 32'h200C);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "pc_tb failed");
    $finish;
  end

endmodule
