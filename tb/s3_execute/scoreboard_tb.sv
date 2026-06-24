`timescale 1ns / 1ps

// scoreboard_tb — issue gate (GPR RAW, I1 buffer stall).
module scoreboard_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  logic        i0_reg_write;
  logic [4:0]  i0_rd;
  logic [6:0]  i0_opcode;

  logic        i1_rs1_use;
  logic        i1_rs2_use;
  logic [4:0]  i1_rs1;
  logic [4:0]  i1_rs2;

  logic        buf_valid;
  logic        issue_i1_from_hold;

  logic        suppress_bundle_raw;

  logic        issue_i0;
  logic        issue_i1;
  logic        stall_id;
  logic        set_i1_hold;
  logic [1:0]  i1_stall_cycles;

  int pass_cnt;
  int fail_cnt;

  scoreboard dut (.*);

  task automatic clear_inputs;
    i0_reg_write = 1'b0;
    i0_rd = '0;
    i0_opcode = '0;
    i1_rs1_use = 1'b0;
    i1_rs2_use = 1'b0;
    i1_rs1 = '0;
    i1_rs2 = '0;
    buf_valid = 1'b0;
    issue_i1_from_hold = 1'b0;
    suppress_bundle_raw = 1'b0;
  endtask

  task automatic check_issue(
    input string name,
    input string detail,
    input logic  exp_i0,
    input logic  exp_i1,
    input logic  exp_stall,
    input logic  exp_hold,
    input logic [1:0] exp_stall_cycles
  );
    bit pass;
    #1;
    pass = (issue_i0 === exp_i0) && (issue_i1 === exp_i1) &&
           (stall_id === exp_stall) && (set_i1_hold === exp_hold) &&
           (i1_stall_cycles === exp_stall_cycles);
    tb_report_open(pass, name, detail);
    tb_field_bit("issue_i0", issue_i0, exp_i0);
    tb_field_bit("issue_i1", issue_i1, exp_i1);
    tb_field_bit("stall_id", stall_id, exp_stall);
    tb_field_bit("set_i1_hold", set_i1_hold, exp_hold);
    tb_field_u32("i1_stall_cycles", {30'd0, i1_stall_cycles}, {30'd0, exp_stall_cycles});
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    clear_inputs();

    tb_banner("scoreboard_tb - buffer stall counter");

    i0_reg_write = 1'b1; i0_rd = 5'd5;
    i1_rs1 = 5'd6;
    check_issue("dual_issue_clean", "no hazard: issue both",
                1'b1, 1'b1, 1'b0, 1'b0, 2'd1);

    clear_inputs();
    i0_reg_write = 1'b1; i0_rd = 5'd5;
    i1_rs1_use = 1'b1; i1_rs1 = 5'd5;
    check_issue("bundle_raw_partial", "ALU RAW: I0 only, buffer I1, stall 1",
                1'b1, 1'b0, 1'b1, 1'b1, 2'd1);

    clear_inputs();
    i0_reg_write = 1'b1; i0_rd = 5'd2;
    i0_opcode = OPC_LOAD;
    i1_rs1_use = 1'b1; i1_rs1 = 5'd2;
    check_issue("load_use_capture", "load-use RAW: buffer I1, stall 2",
                1'b1, 1'b0, 1'b1, 1'b1, 2'd2);

    clear_inputs();
    buf_valid = 1'b1;
    issue_i1_from_hold = 1'b0;
    check_issue("buf_wait_count", "buffer valid: full stall while waiting",
                1'b0, 1'b0, 1'b1, 1'b0, 2'd1);

    issue_i1_from_hold = 1'b1;
    check_issue("buf_replay_ready", "replay pulse: issue buffered I1",
                1'b0, 1'b1, 1'b0, 1'b0, 2'd1);

    clear_inputs();
    i0_reg_write = 1'b1; i0_rd = 5'd5;
    i1_rs1_use = 1'b1; i1_rs1 = 5'd5;
    suppress_bundle_raw = 1'b1;
    check_issue("suppress_bundle_raw", "ignore RAW after buffered replay",
                1'b1, 1'b1, 1'b0, 1'b0, 2'd1);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "scoreboard_tb failed");
    $finish;
  end

endmodule
