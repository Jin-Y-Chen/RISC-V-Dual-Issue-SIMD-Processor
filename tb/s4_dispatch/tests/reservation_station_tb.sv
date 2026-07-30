`timescale 1ns / 1ps

// Directed TB: reservation_station (bank + wakeup + alloc).
// pick / stall_dp are driven as if from selector_unit.
import rv_dis_pkg::*;
import rs_pkg::*;

`include "../../common/utils/tb_console.svh"

module reservation_station_tb;

  localparam int CLK_PERIOD = 10;

  logic               clk, rst_n, enable, flush;
  logic               path_en, path_sel, stall_dp;
  rs_disp_pair_t      disp;
  rs_wb_pair_t        wb;
  rs_pick_t           pick;
  rs_entry_t          bank_q [RS_SETS][RS_WAYS];
  logic [NUM_PRF-1:0] prf_ready_q;
  logic [31:0]        age_q;

  int pass_cnt, fail_cnt;

  reservation_station dut (
    .clk, .rst_n, .enable, .flush,
    .path_en, .path_sel, .stall_dp,
    .disp, .wb, .pick,
    .bank_q, .prf_ready_q, .age_q
  );

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  function automatic rs_disp_insn_t mk(
      input logic v, input prf_addr_t prd,
      input prf_addr_t ps1, input prf_addr_t ps2,
      input logic spec
  );
    mk = '0;
    mk.valid     = v;
    mk.reg_write = (prd != '0);
    mk.spec_en   = spec;
    mk.opcode    = OPC_OP;
    mk.ps1       = ps1;
    mk.ps2       = ps2;
    mk.prd       = prd;
  endfunction

  task automatic clear_stim;
    flush    = 0;
    path_en  = 0;
    path_sel = 0;
    stall_dp = 0;
    enable   = 1;
    disp     = '0;
    wb       = '0;
    pick     = '0;
  endtask

  task automatic cycle_hold;
    @(negedge clk);
    #1;
    clear_stim();
    #0;
  endtask

  function automatic int count_valid;
    int n;
    n = 0;
    for (int w = 0; w < RS_WAYS; w++)
      if (bank_q[0][w].valid) n++;
    return n;
  endfunction

  function automatic int count_path(input logic spec);
    int n;
    n = 0;
    for (int w = 0; w < RS_WAYS; w++)
      if (bank_q[0][w].valid && (bank_q[0][w].spec_en == spec)) n++;
    return n;
  endfunction

  function automatic int find_prd(input prf_addr_t prd);
    find_prd = -1;
    for (int w = 0; w < RS_WAYS; w++)
      if (bank_q[0][w].valid && (bank_q[0][w].prd == prd))
        return w;
  endfunction

  task automatic expect_ok(
      input string name, input string detail, input bit pass
  );
    tb_report_open(pass, name, detail);
    tb_log_section("rs state");
    tb_field_in_u32("valid_cnt", count_valid());
    tb_field_in_u32("age_q",     age_q);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    rst_n = 0;
    clear_stim();
    tb_banner("reservation_station_tb - RS bank/wakeup/alloc");

    repeat (2) @(posedge clk);
    rst_n = 1;
    @(negedge clk);
    #1;
    expect_ok("reset", "empty bank, age=0, prf ready",
              (count_valid() == 0) && (age_q == 0) && prf_ready_q[1]);

    // ---- store dual unready (no bypass) ----
    @(posedge clk);
    disp.i0 = mk(1, 6'd32, 6'd50, 6'd0, 0);
    disp.i1 = mk(1, 6'd33, 6'd50, 6'd0, 0);
    // mark producer unready already so stored entries stay blocked
    // (prd becomes unready on accept; ps1=50 needs prior clear)
    // Force via: first accept producer that marks 50 unready
    clear_stim();
    @(posedge clk);
    disp.i0 = mk(1, 6'd50, 6'd0, 6'd0, 0);
    pick.bypass0 = 1;  // issue without storing
    pick.fire0   = 1;
    pick.src0_disp = 1;
    #0;
    cycle_hold;

    @(posedge clk);
    expect_ok("after_bypass_accept", "prd50 unready, bank still empty",
              (count_valid() == 0) && !prf_ready_q[50]);

    @(posedge clk);
    disp.i0 = mk(1, 6'd32, 6'd50, 6'd0, 0);
    disp.i1 = mk(1, 6'd33, 6'd50, 6'd0, 0);
    // no bypass -> both store
    #0;
    cycle_hold;

    @(posedge clk);
    expect_ok("store_dual_unready", "two entries waiting on p50",
              (count_valid() == 2)
              && (find_prd(6'd32) >= 0) && (find_prd(6'd33) >= 0)
              && !bank_q[0][find_prd(6'd32)].rs1_ready);

    // ---- WB wakeup ----
    @(posedge clk);
    wb.wb0.en  = 1;
    wb.wb0.prd = 6'd50;
    #0;
    cycle_hold;

    @(posedge clk);
    begin
      int w0, w1;
      bit pass;
      w0 = find_prd(6'd32);
      w1 = find_prd(6'd33);
      pass = (w0 >= 0) && (w1 >= 0)
          && bank_q[0][w0].rs1_ready && bank_q[0][w1].rs1_ready
          && prf_ready_q[50];
      expect_ok("wb_wakeup", "WB sets rs1_ready + prf_ready", pass);
    end

    // ---- free bank way via pick ----
    begin
      int w0;
      w0 = find_prd(6'd32);
      @(posedge clk);
      pick.fire0     = 1;
      pick.sel0_v    = 1;
      pick.sel0      = rs_way_t'(w0);
      pick.src0_disp = 0;
      #0;
      cycle_hold;
      @(posedge clk);
      expect_ok("free_issued_way", "issued bank way cleared",
                (find_prd(6'd32) < 0) && (find_prd(6'd33) >= 0));
    end

    // clear remaining
    flush = 1;
    @(negedge clk);
    #1;
    flush = 0;
    #0;
    expect_ok("flush", "bank cleared", count_valid() == 0);

    // ---- selective path squash ----
    @(posedge clk);
    disp.i0 = mk(1, 6'd36, 6'd1, 6'd0, 0);  // path0, ps1=p1 ready
    disp.i1 = mk(1, 6'd37, 6'd2, 6'd0, 0);
    // make unready so they stay queued: use missing tag
    // Use prd accept then dependents - simpler: store with unready ps1
    clear_stim();
    // Mark p60 unready via bypass accept
    @(posedge clk);
    disp.i0 = mk(1, 6'd60, 6'd0, 6'd0, 0);
    pick.bypass0 = 1; pick.fire0 = 1; pick.src0_disp = 1;
    #0;
    cycle_hold;

    @(posedge clk);
    disp.i0 = mk(1, 6'd36, 6'd60, 6'd0, 0);  // path0
    disp.i1 = mk(1, 6'd37, 6'd60, 6'd0, 1);  // path1
    #0;
    cycle_hold;

    @(posedge clk);
    expect_ok("queued_both_paths", "one path0 + one path1",
              (count_path(0) == 1) && (count_path(1) == 1));

    @(posedge clk);
    path_en  = 1;
    path_sel = 1;  // keep path1
    #0;
    cycle_hold;

    @(posedge clk);
    expect_ok("path_squash", "only path1 remains",
              (count_path(0) == 0) && (count_path(1) == 1));

    flush = 1;
    @(negedge clk);
    #1;
    flush = 0;

    // ---- stall_dp blocks alloc ----
    @(posedge clk);
    disp.i0 = mk(1, 6'd70, 6'd0, 6'd0, 0);
    stall_dp = 1;
    #0;
    cycle_hold;
    @(posedge clk);
    expect_ok("stall_blocks_store", "stall_dp prevents alloc",
              count_valid() == 0);

    // ---- fill to capacity (16) then prove full ----
    // Accept unready producer once
    @(posedge clk);
    disp.i0 = mk(1, 6'd61, 6'd0, 6'd0, 0);
    pick.bypass0 = 1; pick.fire0 = 1; pick.src0_disp = 1;
    #0;
    cycle_hold;

    for (int p = 0; p < 8; p++) begin
      @(posedge clk);
      disp.i0 = mk(1, prf_addr_t'(32 + 2 * p), 6'd61, 6'd0, 0);
      disp.i1 = mk(1, prf_addr_t'(33 + 2 * p), 6'd61, 6'd0, 0);
      #0;
      cycle_hold;
    end

    @(posedge clk);
    expect_ok("bank_full", "16 ways occupied", count_valid() == RS_WAYS);

    // Dual store while full without freeing -> still full (stall would
    // normally prevent this; with stall_dp=0 RTL still won't invent ways)
    @(posedge clk);
    disp.i0 = mk(1, 6'd48, 6'd61, 6'd0, 0);
    disp.i1 = mk(1, 6'd49, 6'd61, 6'd0, 0);
    #0;
    cycle_hold;
    @(posedge clk);
    expect_ok("overflow_no_new", "still 16 (free_m empty)",
              count_valid() == RS_WAYS);

    tb_summary(pass_cnt, fail_cnt);
    $finish;
  end

endmodule
