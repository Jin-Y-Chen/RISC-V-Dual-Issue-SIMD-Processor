`timescale 1ns / 1ps

// Directed TB: selector_unit (oldest-ready pick from bank + bypass).
import rv_dis_pkg::*;
import rs_pkg::*;

`include "../../common/utils/tb_console.svh"

module selector_tb;

  logic               enable, flush;
  rs_entry_t          bank_q [RS_SETS][RS_WAYS];
  rs_wb_pair_t        wb;
  rs_disp_pair_t      disp;
  logic               byp_ready [2];
  logic [31:0]        byp_age   [2];
  rs_pick_t           pick;
  logic               stall_dp;
  rs_prf_rd_pair_t    prf;
  rs_iss_pair_t       iss;

  int pass_cnt, fail_cnt;

  selector_unit dut (
    .enable, .flush,
    .bank_q, .wb, .disp,
    .byp_ready, .byp_age,
    .pick, .stall_dp, .prf, .iss
  );

  function automatic rs_disp_insn_t mk_disp(
      input logic v, input prf_addr_t prd,
      input prf_addr_t ps1, input prf_addr_t ps2
  );
    mk_disp = '0;
    mk_disp.valid     = v;
    mk_disp.reg_write = (prd != '0);
    mk_disp.opcode    = OPC_OP;
    mk_disp.ps1       = ps1;
    mk_disp.ps2       = ps2;
    mk_disp.prd       = prd;
  endfunction

  function automatic rs_entry_t mk_ent(
      input logic v, input logic [31:0] age,
      input prf_addr_t prd,
      input logic r1, input logic r2
  );
    mk_ent = '0;
    mk_ent.valid     = v;
    mk_ent.age       = age;
    mk_ent.reg_write = (prd != '0);
    mk_ent.rs1_ready = r1;
    mk_ent.rs2_ready = r2;
    mk_ent.opcode    = OPC_OP;
    mk_ent.prd       = prd;
  endfunction

  task automatic clear;
    enable = 1;
    flush  = 0;
    wb     = '0;
    disp   = '0;
    byp_ready[0] = 0;
    byp_ready[1] = 0;
    byp_age[0]   = '0;
    byp_age[1]   = '0;
    for (int w = 0; w < RS_WAYS; w++)
      bank_q[0][w] = '0;
  endtask

  task automatic check_pick(
      input string name, input string detail,
      input logic e_b0, input logic e_b1,
      input logic e_s0_disp, input logic e_s1_disp,
      input logic e_stall,
      input prf_addr_t e_prd0, input prf_addr_t e_prd1
  );
    bit pass;
    pass = (pick.bypass0 === e_b0) && (pick.bypass1 === e_b1)
        && (pick.src0_disp === e_s0_disp) && (pick.src1_disp === e_s1_disp)
        && (stall_dp === e_stall)
        && (iss.i0.prd === e_prd0) && (iss.i1.prd === e_prd1);
    tb_report_open(pass, name, detail);
    tb_log_section("pick / issue");
    tb_field_bit("bypass0",    pick.bypass0,    e_b0);
    tb_field_bit("bypass1",    pick.bypass1,    e_b1);
    tb_field_bit("src0_disp",  pick.src0_disp,  e_s0_disp);
    tb_field_bit("src1_disp",  pick.src1_disp,  e_s1_disp);
    tb_field_bit("stall_dp",   stall_dp,        e_stall);
    tb_field_u32("iss0_prd",   iss.i0.prd,      e_prd0);
    tb_field_u32("iss1_prd",   iss.i1.prd,      e_prd1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    clear();
    tb_banner("selector_tb - selector_unit directed");

    #1;
    check_pick("idle", "no candidates", 0, 0, 0, 0, 0, 6'd0, 6'd0);

    // Dual bypass issue (both ready, empty bank)
    disp.i0 = mk_disp(1, 6'd32, 6'd0, 6'd0);
    disp.i1 = mk_disp(1, 6'd33, 6'd0, 6'd0);
    byp_ready[0] = 1;
    byp_ready[1] = 1;
    byp_age[0]   = 32'd10;
    byp_age[1]   = 32'd11;
    #1;
    check_pick("dual_bypass", "both from dispatch", 1, 1, 1, 1, 0, 6'd32, 6'd33);

    // Oldest bank entry beats younger bypass
    clear();
    bank_q[0][3] = mk_ent(1, 32'd1, 6'd40, 1, 1);
    bank_q[0][7] = mk_ent(1, 32'd4, 6'd41, 1, 1);
    disp.i0 = mk_disp(1, 6'd50, 6'd0, 6'd0);
    byp_ready[0] = 1;
    byp_age[0]   = 32'd8;
    #1;
    // oldest=way3 (age1), then way7 (age4); bypass age8 loses
    begin
      bit pass;
      pass = pick.fire0 && !pick.src0_disp && (pick.sel0 == 4'd3)
          && pick.fire1 && !pick.src1_disp && (pick.sel1 == 4'd7)
          && !pick.bypass0 && (iss.i0.prd == 6'd40) && (iss.i1.prd == 6'd41);
      tb_report_open(pass, "bank_oldest", "bank ages beat bypass");
      tb_field_u32("sel0", pick.sel0, 4'd3);
      tb_field_u32("sel1", pick.sel1, 4'd7);
      tb_field_u32("iss0", iss.i0.prd, 6'd40);
      tb_field_u32("iss1", iss.i1.prd, 6'd41);
      tb_field_bit("bypass0", pick.bypass0, 0);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    // One bank + one bypass (bypass younger age still second)
    clear();
    bank_q[0][2] = mk_ent(1, 32'd2, 6'd44, 1, 1);
    disp.i0 = mk_disp(1, 6'd45, 6'd0, 6'd0);
    byp_ready[0] = 1;
    byp_age[0]   = 32'd9;
    #1;
    begin
      bit pass;
      pass = pick.fire0 && !pick.src0_disp && (pick.sel0 == 4'd2)
          && pick.fire1 && pick.src1_disp && !pick.src1_d1
          && pick.bypass0 && (iss.i0.prd == 6'd44) && (iss.i1.prd == 6'd45);
      tb_report_open(pass, "bank_then_bypass", "oldest bank then bypass");
      tb_field_u32("iss0", iss.i0.prd, 6'd44);
      tb_field_u32("iss1", iss.i1.prd, 6'd45);
      tb_field_bit("bypass0", pick.bypass0, 1);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    // Flush suppresses issue
    flush = 1;
    #1;
    check_pick("flush_blocks", "flush clears candidates", 0, 0, 0, 0, 0, 6'd0, 6'd0);
    flush = 0;

    // Full bank + dual unselected store demand -> stall (need space)
    clear();
    for (int w = 0; w < RS_WAYS; w++) begin
      bank_q[0][w] = mk_ent(1, 32'(w + 1), prf_addr_t'(32 + w), 0, 1);
      bank_q[0][w].ps1 = 6'd55;  // unready src (no WB) so bank cannot issue
    end
    disp.i0 = mk_disp(1, 6'd60, 6'd0, 6'd0);
    disp.i1 = mk_disp(1, 6'd61, 6'd0, 6'd0);
    byp_ready[0] = 0;
    byp_ready[1] = 0;
    #1;
    begin
      bit pass;
      pass = stall_dp && !pick.fire0 && !pick.fire1;
      tb_report_open(pass, "full_stall", "no free ways + no bypass -> stall");
      tb_field_bit("stall_dp", stall_dp, 1);
      tb_field_bit("fire0", pick.fire0, 0);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    // Full bank but both bypass ready -> can issue without stall
    byp_ready[0] = 1;
    byp_ready[1] = 1;
    byp_age[0]   = 32'd100;
    byp_age[1]   = 32'd101;
    #1;
    check_pick("full_dual_bypass", "bypass frees need", 1, 1, 1, 1, 0, 6'd60, 6'd61);

    // WB wakes a bank entry for issue
    clear();
    bank_q[0][1] = mk_ent(1, 32'd3, 6'd48, 0, 1);
    bank_q[0][1].ps1 = 6'd55;
    wb.wb0.en  = 1;
    wb.wb0.prd = 6'd55;
    #1;
    begin
      bit pass;
      pass = pick.fire0 && !pick.src0_disp && (pick.sel0 == 4'd1)
          && (iss.i0.prd == 6'd48);
      tb_report_open(pass, "wb_wakes_bank", "same-cycle WB enables bank issue");
      tb_field_u32("sel0", pick.sel0, 4'd1);
      tb_field_u32("iss0", iss.i0.prd, 6'd48);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    tb_summary(pass_cnt, fail_cnt);
    $finish;
  end

endmodule
