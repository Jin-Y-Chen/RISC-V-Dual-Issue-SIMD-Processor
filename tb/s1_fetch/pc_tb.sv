`timescale 1ns / 1ps

// pc_tb - fetch PC update policy for dual-issue front-end.
module pc_tb;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;
  localparam logic [31:0] TB_RESET_PC = 32'h0000_1000;

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic        stall;
  logic        set;
  logic [31:0] set_pc;
  logic [31:0] pc0;
  logic [31:0] pc1;

  int pass_cnt;
  int fail_cnt;

  pc #(
    .RESET_PC(TB_RESET_PC)
  ) dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .enable        (enable),
    .stall       (stall),
    .set         (set),
    .set_pc      (set_pc),
    .pc0         (pc0),
    .pc1         (pc1)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    tb_advance(clk);
  endtask

  task automatic check_pc(
    input string       name,
    input string       detail,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (pc0 === exp_pc) && (pc1 === (exp_pc + 32'd4));
    tb_report_open(pass, name, detail);
    tb_field_u32("pc0", pc0, exp_pc);
    tb_field_u32("pc1", pc1, (exp_pc + 32'd4));
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic drive_ctrl(
    input logic stall_v,
    input logic enable_v,
    input logic set_v,
    input logic [31:0] set_pc_v
  );
    stall       = stall_v;
    enable        = enable_v;
    set         = set_v;
    set_pc      = set_pc_v;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    rst_n = 1'b0;
    drive_ctrl(1'b0, 1'b0, 1'b0, 32'd0);
    tick();
    check_pc("reset", "RESET_PC is visible after reset", TB_RESET_PC);

    rst_n = 1'b1;
    tick();
    check_pc("idle_hold", "enable=0 holds PC", TB_RESET_PC);

    drive_ctrl(1'b0, 1'b1, 1'b0, 32'd0);
    tick();
    check_pc("dual_issue_step", "enable=1 => +8 (two insns)", TB_RESET_PC + 32'd8);

    drive_ctrl(1'b1, 1'b1, 1'b0, 32'd0);
    tick();
    check_pc("stall_hold", "stall blocks normal PC advance", TB_RESET_PC + 32'd8);

    drive_ctrl(1'b0, 1'b0, 1'b1, 32'h0000_1237);
    tick();
    check_pc("set_align4", "set target is forced to 4-byte alignment", 32'h0000_1234);

    drive_ctrl(1'b1, 1'b1, 1'b1, 32'h0000_2005);
    tick();
    check_pc("set_priority", "set beats stall and enable controls", 32'h0000_2004);

    drive_ctrl(1'b0, 1'b1, 1'b0, 32'd0);
    tick();
    check_pc("post_set_step", "normal +8 from set PC", 32'h0000_200C);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "pc_tb failed");
    $finish;
  end

endmodule
