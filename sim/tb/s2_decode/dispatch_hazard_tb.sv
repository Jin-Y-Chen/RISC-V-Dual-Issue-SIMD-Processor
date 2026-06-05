`timescale 1ns / 1ps

// dispatch_hazard_tb — golden dispatch/issue policy (project_outline ID stage).
// No dispatch DUT yet (rtl/issue_dispatch/); documents RAW, lane conflict, stall, forward.
module dispatch_hazard_tb;

  import rv_dis_pkg::*;
  import decode_pkg::*;

  `include "../common/tb_console.svh"

  int pass_cnt;
  int fail_cnt;

  // I1 operand depends on I0 destination (program order: I0 older, I1 younger).
  function automatic bit i1_uses_i0_rd(
    input logic [4:0] i0_rd,
    input logic       i0_reg_write,
    input logic [4:0] i1_rs1,
    input logic [4:0] i1_rs2,
    input logic       i1_rs1_use,
    input logic       i1_rs2_use
  );
    if (!i0_reg_write || i0_rd == 5'd0)
      return 1'b0;
    return (i1_rs1_use && (i1_rs1 == i0_rd)) || (i1_rs2_use && (i1_rs2 == i0_rd));
  endfunction

  function automatic bit lane_conflict(
    input lane_sel_e i0_lane,
    input lane_sel_e i1_lane
  );
    return (i0_lane != LANE_NONE) && (i1_lane == i0_lane);
  endfunction

  // I0 in EX or MEM can forward to I1 in ID (outline: EX/MEM forwarding between lanes).
  function automatic bit forward_in_time(
    input logic i0_ex_valid,
    input logic i0_mem_valid
  );
    return i0_ex_valid || i0_mem_valid;
  endfunction

  function automatic bit grant_i1_issue(
    input logic i0_valid,
    input logic i1_valid,
    input lane_sel_e i0_lane,
    input lane_sel_e i1_lane,
    input logic [4:0] i0_rd,
    input logic       i0_reg_write,
    input logic [4:0] i1_rs1,
    input logic [4:0] i1_rs2,
    input logic       i1_rs1_use,
    input logic       i1_rs2_use,
    input logic       i0_ex_valid,
    input logic       i0_mem_valid
  );
    bit raw;
    bit fwd;
    if (!i0_valid || !i1_valid)
      return 1'b0;
    if (lane_conflict(i0_lane, i1_lane))
      return 1'b0;
    raw = i1_uses_i0_rd(i0_rd, i0_reg_write, i1_rs1, i1_rs2, i1_rs1_use, i1_rs2_use);
    fwd = forward_in_time(i0_ex_valid, i0_mem_valid);
    return !raw || fwd;
  endfunction

  function automatic bit stall_from_i1_block(
    input logic i0_valid,
    input logic i1_valid,
    input logic grant_i1
  );
    return i0_valid && i1_valid && !grant_i1;
  endfunction

  task automatic check_bit(
    input string name,
    input string detail,
    input bit    got,
    input bit    exp
  );
    bit pass;
    pass = (got === exp);
    tb_report_open(pass, name, detail);
    $display("     grant/flag     = %0d (exp: %0d)", got, exp);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("dispatch_hazard_tb - golden issue policy (no DUT)");
    tb_info_msg("Matches project_outline: RAW, lane conflict, I0-only issue, stall, EX/MEM fwd");

    // --- RAW detect ---
    check_bit("raw_rs1", "I1 rs1 uses I0 rd",
      i1_uses_i0_rd(5'd10, 1'b1, 5'd10, 5'd2, 1'b1, 1'b0), 1'b1);
    check_bit("raw_rs2", "I1 rs2 uses I0 rd",
      i1_uses_i0_rd(5'd11, 1'b1, 5'd3, 5'd11, 1'b0, 1'b1), 1'b1);
    check_bit("raw_none", "different rd — no RAW",
      i1_uses_i0_rd(5'd10, 1'b1, 5'd11, 5'd12, 1'b1, 1'b1), 1'b0);
    check_bit("raw_no_wr", "I0 no reg_write — no RAW",
      i1_uses_i0_rd(5'd10, 1'b0, 5'd10, 5'd10, 1'b1, 1'b1), 1'b0);
    check_bit("raw_x0", "I0 rd=x0 — no RAW",
      i1_uses_i0_rd(5'd0, 1'b1, 5'd0, 5'd0, 1'b1, 1'b1), 1'b0);

    // --- Lane conflict ---
    check_bit("lane_ok", "even + odd lanes",
      lane_conflict(LANE_EVEN, LANE_ODD), 1'b0);
    check_bit("lane_conflict", "both need even lane",
      lane_conflict(LANE_EVEN, LANE_EVEN), 1'b1);
    check_bit("lane_conflict2", "both need odd lane",
      lane_conflict(LANE_ODD, LANE_ODD), 1'b1);

    // --- Issue grant: I1 blocked on RAW without forward ---
    check_bit("issue_i1_raw_stall", "RAW, no EX/MEM fwd → no I1 issue",
      grant_i1_issue(1'b1, 1'b1, LANE_EVEN, LANE_ODD,
        5'd5, 1'b1, 5'd5, 5'd8, 1'b1, 1'b0, 1'b0, 1'b0), 1'b0);
    check_bit("stall_set", "stall when I1 blocked",
      stall_from_i1_block(1'b1, 1'b1,
        grant_i1_issue(1'b1, 1'b1, LANE_EVEN, LANE_ODD,
          5'd5, 1'b1, 5'd5, 5'd8, 1'b1, 1'b0, 1'b0, 1'b0)), 1'b1);

    // --- Forward in time → dual-issue allowed ---
    check_bit("issue_i1_fwd_ex", "RAW + I0 in EX → I1 may issue",
      grant_i1_issue(1'b1, 1'b1, LANE_EVEN, LANE_ODD,
        5'd5, 1'b1, 5'd5, 5'd8, 1'b1, 1'b0, 1'b1, 1'b0), 1'b1);
    check_bit("issue_i1_fwd_mem", "RAW + I0 in MEM → I1 may issue",
      grant_i1_issue(1'b1, 1'b1, LANE_EVEN, LANE_ODD,
        5'd5, 1'b1, 5'd5, 5'd8, 1'b1, 1'b0, 1'b0, 1'b1), 1'b1);
    check_bit("no_stall_fwd", "no stall when forward available",
      stall_from_i1_block(1'b1, 1'b1,
        grant_i1_issue(1'b1, 1'b1, LANE_EVEN, LANE_ODD,
          5'd5, 1'b1, 5'd5, 5'd8, 1'b1, 1'b0, 1'b1, 1'b0)), 1'b0);

    // --- Clean dual-issue ---
    check_bit("dual_issue_ok", "no RAW, different lanes",
      grant_i1_issue(1'b1, 1'b1, LANE_EVEN, LANE_ODD,
        5'd3, 1'b1, 5'd4, 5'd5, 1'b1, 1'b1, 1'b0, 1'b0), 1'b1);

    // --- Lane conflict blocks I1 even without RAW ---
    check_bit("issue_i1_lane_block", "lane conflict → I1 not issued",
      grant_i1_issue(1'b1, 1'b1, LANE_ODD, LANE_ODD,
        5'd7, 1'b1, 5'd8, 5'd9, 1'b1, 1'b1, 1'b1, 1'b1), 1'b0);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "dispatch_hazard_tb failed");
    $finish;
  end

endmodule
