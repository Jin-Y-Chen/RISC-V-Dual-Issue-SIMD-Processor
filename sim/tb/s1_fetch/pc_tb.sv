`timescale 1ns / 1ps

// pc_tb - fetch PC update policy for dual-issue front-end.
module pc_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;
  localparam logic [31:0] TB_RESET_PC = 32'h0000_1000;

  logic        clk;
  logic        rst_n;
  logic        stall_i;
  logic        advance_i;
  logic        dual_issue_i;
  logic        redirect_i;
  logic [31:0] redirect_pc_i;
  logic [31:0] pc_o;
  logic [31:0] pc_plus4_o;

  int pass_cnt;
  int fail_cnt;

  pc #(
    .RESET_PC(TB_RESET_PC)
  ) dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .stall_i       (stall_i),
    .advance_i     (advance_i),
    .dual_issue_i  (dual_issue_i),
    .redirect_i    (redirect_i),
    .redirect_pc_i (redirect_pc_i),
    .pc_o          (pc_o),
    .pc_plus4_o    (pc_plus4_o)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic check_pc(
    input string       name,
    input string       detail,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (pc_o === exp_pc) && (pc_plus4_o === (exp_pc + 32'd4));
    tb_report_open(pass, name, detail);
    tb_field_u32("pc_o", pc_o, exp_pc);
    tb_field_u32("pc_plus4_o", pc_plus4_o, (exp_pc + 32'd4));
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic drive_ctrl(
    input logic stall_v,
    input logic advance_v,
    input logic dual_issue_v,
    input logic redirect_v,
    input logic [31:0] redirect_pc_v
  );
    stall_i       = stall_v;
    advance_i     = advance_v;
    dual_issue_i  = dual_issue_v;
    redirect_i    = redirect_v;
    redirect_pc_i = redirect_pc_v;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    rst_n = 1'b0;
    drive_ctrl(1'b0, 1'b0, 1'b0, 1'b0, 32'd0);
    tick();
    check_pc("reset", "RESET_PC is visible after reset", TB_RESET_PC);

    rst_n = 1'b1;
    tick();
    check_pc("idle_hold", "No advance holds PC", TB_RESET_PC);

    drive_ctrl(1'b0, 1'b1, 1'b0, 1'b0, 32'd0);
    tick();
    check_pc("single_issue_step", "advance=1 dual_issue=0 => +4", TB_RESET_PC + 32'd4);

    drive_ctrl(1'b0, 1'b1, 1'b1, 1'b0, 32'd0);
    tick();
    check_pc("dual_issue_step", "advance=1 dual_issue=1 => +8", TB_RESET_PC + 32'd12);

    drive_ctrl(1'b1, 1'b1, 1'b1, 1'b0, 32'd0);
    tick();
    check_pc("stall_hold", "stall blocks normal PC advance", TB_RESET_PC + 32'd12);

    drive_ctrl(1'b0, 1'b0, 1'b0, 1'b1, 32'h0000_1237);
    tick();
    check_pc("redirect_align4", "redirect target is forced to 4-byte alignment", 32'h0000_1234);

    drive_ctrl(1'b1, 1'b1, 1'b1, 1'b1, 32'h0000_2005);
    tick();
    check_pc("redirect_priority", "redirect beats stall and advance controls", 32'h0000_2004);

    drive_ctrl(1'b0, 1'b1, 1'b0, 1'b0, 32'd0);
    tick();
    check_pc("post_redirect_step", "normal +4 from redirected PC", 32'h0000_2008);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "pc_tb failed");
    $finish;
  end

endmodule
