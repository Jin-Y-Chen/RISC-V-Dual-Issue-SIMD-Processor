`timescale 1ns / 1ps

// Directed TB: selector_unit (oldest-ready pick from bank + rename).
// src_en=1 → RS op on channel; store_en + !src_en → rename→RS.
import rv_dis_pkg::*;
import rs_pkg::*;

`include "../../common/utils/tb_console.svh"

module selector_tb;

  logic        enable, flush;
  logic        path_en, path_sel;
  logic        bank_valid    [RS_WAYS];
  rs_way_t     bank_rs_tag   [RS_WAYS];
  rs_age_t     bank_age      [RS_WAYS];
  logic        bank_lane_sel [RS_WAYS];
  logic        bank_spec     [RS_WAYS];
  logic        bank_rs1_rdy  [RS_WAYS];
  logic        bank_rs2_rdy  [RS_WAYS];
  opcode_t     bank_opcode   [RS_WAYS];
  funct3_t     bank_funct3   [RS_WAYS];
  funct7_t     bank_funct7   [RS_WAYS];
  prf_addr_t   bank_ps1      [RS_WAYS];
  prf_addr_t   bank_ps2      [RS_WAYS];
  prf_addr_t   bank_prd      [RS_WAYS];
  word_t       bank_imm      [RS_WAYS];
  word_t       bank_pc       [RS_WAYS];

  logic        wb_en      [2];
  prf_addr_t   rob_tag_wb [2];

  logic        valid_dp    [2];
  logic        path_use_dp [2];
  logic        lane_sel_dp [2];
  opcode_t     opcode_dp   [2];
  funct3_t     funct3_dp   [2];
  funct7_t     funct7_dp   [2];
  prf_addr_t   ps1_dp      [2];
  prf_addr_t   ps2_dp      [2];
  prf_addr_t   prd_dp      [2];
  word_t       imm_dp      [2];
  word_t       pc_dp       [2];

  logic        src_en   [2];
  logic        store_en [2];
  rs_way_t     rs_tag   [2];
  logic        stall_dp;

  logic        iss_valid    [2];
  logic        iss_lane_sel [2];
  opcode_t     iss_opcode   [2];
  funct3_t     iss_funct3   [2];
  funct7_t     iss_funct7   [2];
  prf_addr_t   iss_prd      [2];
  word_t       iss_imm      [2];
  word_t       iss_pc       [2];
  prf_addr_t   ps1_prf      [2];
  prf_addr_t   ps2_prf      [2];

  int pass_cnt, fail_cnt;

  selector_unit dut (.*);

  function automatic logic any_rs_clear(input rs_way_t w);
    return (src_en[0] && !store_en[0] && rs_tag[0] == w) ||
           (src_en[1] && !store_en[1] && rs_tag[1] == w);
  endfunction

  task automatic set_disp(
      input int lane,
      input logic v, input prf_addr_t prd,
      input prf_addr_t ps1, input prf_addr_t ps2,
      input logic spec
  );
    valid_dp[lane]    = v;
    path_use_dp[lane] = spec;
    lane_sel_dp[lane] = 0;
    opcode_dp[lane]   = OPC_OP;
    funct3_dp[lane]   = '0;
    funct7_dp[lane]   = '0;
    ps1_dp[lane]      = ps1;
    ps2_dp[lane]      = ps2;
    prd_dp[lane]      = prd;
    imm_dp[lane]      = '0;
    pc_dp[lane]       = '0;
  endtask

  task automatic set_ent(
      input int w,
      input logic v, input rs_age_t age,
      input prf_addr_t prd,
      input logic r1, input logic r2,
      input logic spec
  );
    bank_valid[w]    = v;
    bank_rs_tag[w]   = rs_way_t'(w);
    bank_age[w]      = age;
    bank_lane_sel[w] = 0;
    bank_spec[w]     = spec;
    bank_rs1_rdy[w]  = r1;
    bank_rs2_rdy[w]  = r2;
    bank_opcode[w]   = OPC_OP;
    bank_funct3[w]   = '0;
    bank_funct7[w]   = '0;
    bank_ps1[w]      = '0;
    bank_ps2[w]      = '0;
    bank_prd[w]      = prd;
    bank_imm[w]      = '0;
    bank_pc[w]       = '0;
  endtask

  task automatic clear;
    enable = 1;
    flush  = 0;
    path_en  = 0;
    path_sel = 0;
    for (int i = 0; i < 2; i++) begin
      wb_en[i] = 0; rob_tag_wb[i] = '0;
      valid_dp[i] = 0; path_use_dp[i] = 0; lane_sel_dp[i] = 0;
      opcode_dp[i] = '0; funct3_dp[i] = '0; funct7_dp[i] = '0;
      ps1_dp[i] = '0; ps2_dp[i] = '0; prd_dp[i] = '0;
      imm_dp[i] = '0; pc_dp[i] = '0;
    end
    for (int w = 0; w < RS_WAYS; w++) begin
      bank_valid[w] = 0; bank_rs_tag[w] = '0; bank_age[w] = '0;
      bank_lane_sel[w] = 0; bank_spec[w] = 0;
      bank_rs1_rdy[w] = 0; bank_rs2_rdy[w] = 0;
      bank_opcode[w] = '0; bank_funct3[w] = '0; bank_funct7[w] = '0;
      bank_ps1[w] = '0; bank_ps2[w] = '0; bank_prd[w] = '0;
      bank_imm[w] = '0; bank_pc[w] = '0;
    end
  endtask

  task automatic check_pick(
      input string name, input string detail,
      input logic e_v0, input logic e_v1,
      input logic e_stall,
      input prf_addr_t e_prd0, input prf_addr_t e_prd1
  );
    bit pass;
    pass = (iss_valid[0] === e_v0) && (iss_valid[1] === e_v1)
        && (stall_dp === e_stall)
        && (iss_prd[0] === e_prd0) && (iss_prd[1] === e_prd1);
    tb_report_open(pass, name, detail);
    tb_log_section("pick / issue");
    tb_field_bit("iss0",     iss_valid[0], e_v0);
    tb_field_bit("iss1",     iss_valid[1], e_v1);
    tb_field_bit("stall_dp", stall_dp,     e_stall);
    tb_field_u32("iss0_prd", iss_prd[0],   e_prd0);
    tb_field_u32("iss1_prd", iss_prd[1],   e_prd1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    clear();
    tb_banner("selector_tb - selector_unit directed");

    #1;
    check_pick("idle", "no candidates", 0, 0, 0, 6'd0, 6'd0);

    set_disp(0, 1, 6'd32, 6'd0, 6'd0, 1'b0);
    set_disp(1, 1, 6'd33, 6'd0, 6'd0, 1'b0);

    #1;
    check_pick("dual_bypass", "both from dispatch", 1, 1, 0, 6'd32, 6'd33);

    clear();
    set_ent(3, 1, 32'd1, 6'd40, 1, 1, 1'b0);
    set_ent(7, 1, 32'd4, 6'd41, 1, 1, 1'b0);
    set_disp(0, 1, 6'd50, 6'd0, 6'd0, 1'b0);

    #1;
    begin
      bit pass;
      // 2 RS + 1 rename store = 3 ctl → shrink to 1 RS + rename issue.
      pass = any_rs_clear(4'd3)
          && (iss_prd[0] == 6'd40)
          && ((iss_prd[1] == 6'd50) || store_en[0])
          && !stall_dp;
      tb_report_open(pass, "bank_oldest",
                     "oldest RS + fit rename; shrink if ctl overflow");
      tb_field_bit("rs_way3", any_rs_clear(4'd3), 1);
      tb_field_u32("iss0", iss_prd[0], 6'd40);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    clear();
    set_ent(2, 1, 32'd2, 6'd44, 1, 1, 1'b0);
    set_disp(0, 1, 6'd45, 6'd0, 6'd0, 1'b0);

    #1;
    begin
      bit pass;
      pass = any_rs_clear(4'd2)
          && (iss_prd[0] == 6'd44) && (iss_prd[1] == 6'd45);
      tb_report_open(pass, "bank_then_bypass", "oldest bank then bypass");
      tb_field_u32("iss0", iss_prd[0], 6'd44);
      tb_field_u32("iss1", iss_prd[1], 6'd45);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    flush = 1;
    #1;
    check_pick("flush_blocks", "flush clears candidates", 0, 0, 0, 6'd0, 6'd0);
    flush = 0;

    clear();
    for (int w = 0; w < RS_WAYS; w++) begin
      set_ent(w, 1, 32'(w + 1), prf_addr_t'(32 + w), 0, 1, 1'b0);
      bank_ps1[w] = 6'd32; // wait on bank_prd[0]
    end
    set_disp(0, 1, 6'd60, 6'd32, 6'd0, 1'b0);
    set_disp(1, 1, 6'd61, 6'd32, 6'd0, 1'b0);
    #1;
    begin
      bit pass;
      pass = stall_dp && !iss_valid[0] && !iss_valid[1];
      tb_report_open(pass, "full_stall", "no free ways + unready disp -> stall");
      tb_field_bit("stall_dp", stall_dp, 1);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    // WB frees two dests and wakes dependents — may issue from RS; no stall
    // for ready rename (no stub room needed).
    wb_en[0] = 1; rob_tag_wb[0] = 6'd32;
    wb_en[1] = 1; rob_tag_wb[1] = 6'd33;
    set_disp(0, 1, 6'd60, 6'd0, 6'd0, 1'b0);
    set_disp(1, 1, 6'd61, 6'd0, 6'd0, 1'b0);

    #1;
    begin
      bit pass;
      pass = !stall_dp && (iss_valid[0] || iss_valid[1]);
      tb_report_open(pass, "full_dual_bypass",
                     "WB frees room / wakes; ready work issues; no stall");
      tb_field_bit("stall_dp", stall_dp, 0);
      tb_field_bit("iss0", iss_valid[0], iss_valid[0]);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    clear();
    set_ent(1, 1, 32'd3, 6'd48, 0, 1, 1'b0);
    bank_ps1[1] = 6'd55;
    wb_en[0] = 1;
    rob_tag_wb[0] = 6'd55;
    #1;
    begin
      bit pass;
      pass = any_rs_clear(4'd1) && (iss_prd[0] == 6'd48);
      tb_report_open(pass, "wb_wakes_bank", "same-cycle WB enables bank issue");
      tb_field_bit("rs_way1", any_rs_clear(4'd1), 1);
      tb_field_u32("iss0", iss_prd[0], 6'd48);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    clear();
    set_ent(1, 1, 32'd1, 6'd40, 1, 1, 1'b0);
    set_ent(2, 1, 32'd2, 6'd41, 1, 1, 1'b0);
    set_ent(3, 1, 32'd3, 6'd42, 1, 1, 1'b0);
    set_disp(0, 1, 6'd50, 6'd0, 6'd0, 1'b0);
    set_disp(1, 1, 6'd51, 6'd0, 6'd0, 1'b0);

    #1;
    begin
      bit pass;
      int n_clear, n_store;
      n_clear = (src_en[0] && !store_en[0]) + (src_en[1] && !store_en[1]);
      n_store = (!src_en[0] && store_en[0]) + (!src_en[1] && store_en[1]);
      // 2 RS + 2 store cannot fit → shrink RS; still progress.
      pass = !stall_dp && (n_clear + n_store <= 2)
          && (iss_valid[0] || store_en[0] || store_en[1]);
      tb_report_open(pass, "ctl_fit_shrink",
                     "clears+stores fit in 2 channels");
      tb_field_in_u32("n_clear", n_clear);
      tb_field_in_u32("n_store", n_store);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    clear();
    set_disp(0, 1, 6'd40, 6'd0, 6'd0, 1'b0);
    set_disp(1, 1, 6'd41, 6'd40, 6'd0, 1'b0);

    #1;
    begin
      bit pass;
      // Without stub, I0 issues and leaves no CAM block → I1 also ready.
      // RAW force still blocks I1 same-cycle via rs_disp_raw.
      pass = iss_valid[0] && !iss_valid[1] && store_en[1]
          && (iss_prd[0] == 6'd40);
      tb_report_open(pass, "disp_raw_blocks_i1",
                     "selector uses RAW for bypass ready");
      tb_field_bit("store1", store_en[1], 1);
      tb_field_u32("iss0", iss_prd[0], 6'd40);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    clear();
    path_en  = 1;
    path_sel = 1;
    set_ent(0, 1, 32'd1, 6'd40, 1, 1, 1'b0);
    set_ent(1, 1, 32'd2, 6'd41, 1, 1, 1'b1);
    set_disp(0, 1, 6'd50, 6'd0, 6'd0, 1'b0);
    set_disp(1, 1, 6'd51, 6'd0, 6'd0, 1'b1);

    #1;
    begin
      bit pass;
      pass = any_rs_clear(4'd1)
          && !store_en[0] && !store_en[1]
          && (iss_prd[0] == 6'd41) && (iss_prd[1] == 6'd51)
          && !stall_dp;
      tb_report_open(pass, "path_filter_issue",
                     "wrong path neither issued nor store-selected");
      tb_field_bit("rs_way1", any_rs_clear(4'd1), 1);
      tb_field_u32("iss0", iss_prd[0], 6'd41);
      tb_field_u32("iss1", iss_prd[1], 6'd51);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    clear();
    path_en  = 1;
    path_sel = 0;
    set_disp(0, 1, 6'd60, 6'd0, 6'd0, 1'b1);
    set_disp(1, 1, 6'd61, 6'd0, 6'd0, 1'b1);

    #1;
    begin
      bit pass;
      pass = !iss_valid[0] && !iss_valid[1]
          && !store_en[0] && !store_en[1] && !stall_dp;
      tb_report_open(pass, "path_kill_disp_nostore",
                     "wrong-path rename dropped; no RS store / stall");
      tb_field_bit("stall_dp", stall_dp, 0);
      tb_field_bit("store0", store_en[0], 0);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    clear();
    set_ent(1, 1, 32'd1, 6'd40, 1, 1, 1'b0);
    set_ent(2, 1, 32'd2, 6'd41, 1, 1, 1'b0);
    set_disp(0, 1, 6'd50, 6'd0, 6'd0, 1'b0);
    set_disp(1, 1, 6'd51, 6'd0, 6'd0, 1'b0);

    #1;
    begin
      bit pass;
      int n_ctl;
      n_ctl = (src_en[0] || store_en[0]) + (src_en[1] || store_en[1]);
      // Prefer: 1 RS clear + 1 rename issue (after shrink from 2+2).
      pass = !stall_dp && any_rs_clear(4'd1)
          && (iss_valid[0] && iss_valid[1])
          && (n_ctl <= 2);
      tb_report_open(pass, "rename_fit_with_rs",
                     "shrink keeps clears+stores ≤ 2");
      tb_field_bit("rs_way1", any_rs_clear(4'd1), 1);
      tb_report_close(pass);
      if (pass) pass_cnt++; else fail_cnt++;
    end

    tb_summary(pass_cnt, fail_cnt);
    $finish;
  end

endmodule
