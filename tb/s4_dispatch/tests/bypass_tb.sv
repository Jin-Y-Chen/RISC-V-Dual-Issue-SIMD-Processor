`timescale 1ns / 1ps

// Directed TB: bypass_unit (combo ready / age for dual dispatch).
import rv_dis_pkg::*;
import rs_pkg::*;

`include "../../common/utils/tb_console.svh"

module bypass_tb;

  rs_disp_pair_t      disp;
  logic [NUM_PRF-1:0] prf_ready;
  rs_wb_pair_t        wb;
  logic [31:0]        age_q;
  logic               ready [2];
  logic [31:0]        age   [2];

  int pass_cnt, fail_cnt;

  bypass_unit dut (
    .disp, .prf_ready, .wb, .age_q,
    .ready, .age
  );

  function automatic rs_disp_insn_t mk(
      input logic v, input prf_addr_t prd,
      input prf_addr_t ps1, input prf_addr_t ps2
  );
    mk = '0;
    mk.valid     = v;
    mk.reg_write = (prd != '0);
    mk.opcode    = OPC_OP;
    mk.ps1       = ps1;
    mk.ps2       = ps2;
    mk.prd       = prd;
  endfunction

  task automatic clear;
    disp      = '0;
    prf_ready = '1;
    wb        = '0;
    age_q     = '0;
  endtask

  task automatic check(
      input string name, input string detail,
      input logic e0, input logic e1,
      input logic [31:0] a0, input logic [31:0] a1
  );
    bit pass;
    pass = (ready[0] === e0) && (ready[1] === e1)
        && (age[0] === a0) && (age[1] === a1);
    tb_report_open(pass, name, detail);
    tb_log_section("outputs");
    tb_field_bit("ready0", ready[0], e0);
    tb_field_bit("ready1", ready[1], e1);
    tb_field_u32("age0",   age[0],   a0);
    tb_field_u32("age1",   age[1],   a1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    clear();
    tb_banner("bypass_tb - bypass_unit directed");

    // Idle
    #1;
    check("idle", "invalid disp -> not ready", 0, 0, 0, 1);

    // Both sources p0: dual ready
    disp.i0 = mk(1, 6'd32, 6'd0, 6'd0);
    disp.i1 = mk(1, 6'd33, 6'd0, 6'd0);
    age_q   = 32'd5;
    #1;
    check("dual_ready_p0", "p0 sources always ready", 1, 1, 5, 6);

    // I0 ready, I1 waits on unready ps1
    prf_ready[34] = 1'b0;
    disp.i0 = mk(1, 6'd32, 6'd0, 6'd0);
    disp.i1 = mk(1, 6'd33, 6'd34, 6'd0);
    #1;
    check("i1_unready_src", "I1 blocked on unready tag", 1, 0, 5, 6);

    // Same-cycle WB wakes I1
    wb.wb0.en  = 1;
    wb.wb0.prd = 6'd34;
    #1;
    check("wb_wakes_i1", "WB tag makes I1 ready", 1, 1, 5, 6);

    // I1 RAW on I0 dest: force unready even if PRF says ready
    clear();
    age_q = 32'd10;
    disp.i0 = mk(1, 6'd40, 6'd0, 6'd0);
    disp.i1 = mk(1, 6'd41, 6'd40, 6'd0);
    #1;
    check("i1_raw_on_i0", "same-pair RAW blocks I1", 1, 0, 10, 11);

    // I1 RAW on I0 via ps2
    disp.i1 = mk(1, 6'd41, 6'd0, 6'd40);
    #1;
    check("i1_raw_ps2", "RAW on ps2 blocks I1", 1, 0, 10, 11);

    // Unready prf without WB
    clear();
    prf_ready[50] = 0;
    disp.i0 = mk(1, 6'd32, 6'd50, 6'd0);
    #1;
    check("i0_unready", "I0 blocked when ps1 not ready", 0, 0, 0, 1);

    tb_summary(pass_cnt, fail_cnt);
    $finish;
  end

endmodule
