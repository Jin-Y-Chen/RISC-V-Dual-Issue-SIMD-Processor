`timescale 1ns / 1ps

// Directed TB: alias_table (RAT/RRAT) vs C++ golden model.
import rv_dis_pkg::*;
import rat_pkg::*;

`include "../../common/utils/tb_console.svh"

module alias_table_tb;

  localparam int CLK_PERIOD = 10;

  logic        clk, rst_n, flush;
  logic        spec_en       [2];
  logic        rs1_use       [2];
  logic        rs2_use       [2];
  gpr_addr_t   rs1_addr      [2];
  gpr_addr_t   rs2_addr      [2];
  logic        path_use      [2];
  prf_addr_t   ps1_tag       [2];
  prf_addr_t   ps2_tag       [2];
  logic        alloc_en      [2];
  gpr_addr_t   alloc_rd_addr [2];
  prf_addr_t   alloc_rob_tag [2];
  logic        rrat_en       [2];
  gpr_addr_t   rd_addr_cmt   [2];
  prf_addr_t   rob_tag_cmt   [2];
  logic        rat_en        [2];
  logic        path_sel      [2];

  logic        ref_path_use  [2];
  prf_addr_t   ref_ps1_tag   [2];
  prf_addr_t   ref_ps2_tag   [2];

  int pass_cnt, fail_cnt;

  alias_table dut (
    .clk, .rst_n, .flush, .spec_en,
    .rs1_use, .rs2_use, .rs1_addr, .rs2_addr,
    .path_use, .ps1_tag, .ps2_tag,
    .alloc_en, .alloc_rd_addr, .alloc_rob_tag,
    .rrat_en, .rd_addr_cmt, .rob_tag_cmt,
    .rat_en, .path_sel
  );

  alias_table_gm u_gm (
    .clk, .rst_n, .flush, .spec_en,
    .rs1_use, .rs2_use, .rs1_addr, .rs2_addr,
    .path_use(ref_path_use), .ps1_tag(ref_ps1_tag), .ps2_tag(ref_ps2_tag),
    .alloc_en, .alloc_rd_addr, .alloc_rob_tag,
    .rrat_en, .rd_addr_cmt, .rob_tag_cmt,
    .rat_en, .path_sel
  );

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  task automatic clear_stim;
    flush = 0;
    for (int i = 0; i < 2; i++) begin
      spec_en[i]       = 0;
      rs1_use[i]       = 0;
      rs2_use[i]       = 0;
      rs1_addr[i]      = '0;
      rs2_addr[i]      = '0;
      alloc_en[i]      = 0;
      alloc_rd_addr[i] = '0;
      alloc_rob_tag[i] = '0;
      rrat_en[i]       = 0;
      rd_addr_cmt[i]   = '0;
      rob_tag_cmt[i]   = '0;
      rat_en[i]        = 0;
      path_sel[i]      = 0;
    end
  endtask

  task automatic check_outs(input string name, input string detail);
    bit pass;
    pass = (path_use[0] === ref_path_use[0]) && (path_use[1] === ref_path_use[1])
        && (ps1_tag[0]  === ref_ps1_tag[0])  && (ps1_tag[1]  === ref_ps1_tag[1])
        && (ps2_tag[0]  === ref_ps2_tag[0])  && (ps2_tag[1]  === ref_ps2_tag[1]);

    tb_report_open(pass, name, detail);

    tb_log_section("inputs");
    tb_field_in_clk(clk);
    tb_field_in_bit("rst_n",        rst_n);
    tb_field_in_bit("flush",        flush);
    tb_field_in_bit("spec_en0",     spec_en[0]);
    tb_field_in_bit("spec_en1",     spec_en[1]);
    tb_field_in_bit("rs1_use0",     rs1_use[0]);
    tb_field_in_bit("rs1_use1",     rs1_use[1]);
    tb_field_in_bit("rs2_use0",     rs2_use[0]);
    tb_field_in_bit("rs2_use1",     rs2_use[1]);
    tb_field_in_u32("rs1_addr0",    rs1_addr[0]);
    tb_field_in_u32("rs1_addr1",    rs1_addr[1]);
    tb_field_in_u32("rs2_addr0",    rs2_addr[0]);
    tb_field_in_u32("rs2_addr1",    rs2_addr[1]);
    tb_field_in_bit("alloc_en0",    alloc_en[0]);
    tb_field_in_bit("alloc_en1",    alloc_en[1]);
    tb_field_in_u32("alloc_rd0",    alloc_rd_addr[0]);
    tb_field_in_u32("alloc_rd1",    alloc_rd_addr[1]);
    tb_field_in_u32("alloc_tag0",   alloc_rob_tag[0]);
    tb_field_in_u32("alloc_tag1",   alloc_rob_tag[1]);
    tb_field_in_bit("rrat_en0",     rrat_en[0]);
    tb_field_in_bit("rrat_en1",     rrat_en[1]);
    tb_field_in_u32("rd_cmt0",      rd_addr_cmt[0]);
    tb_field_in_u32("rd_cmt1",      rd_addr_cmt[1]);
    tb_field_in_u32("tag_cmt0",     rob_tag_cmt[0]);
    tb_field_in_u32("tag_cmt1",     rob_tag_cmt[1]);
    tb_field_in_bit("rat_en0",      rat_en[0]);
    tb_field_in_bit("rat_en1",      rat_en[1]);
    tb_field_in_bit("path_sel0",    path_sel[0]);
    tb_field_in_bit("path_sel1",    path_sel[1]);
    $display("");

    tb_log_section("outputs (DUT vs GM)");
    tb_field_bit("path_use0", path_use[0], ref_path_use[0]);
    tb_field_bit("path_use1", path_use[1], ref_path_use[1]);
    tb_field_u32("ps1_tag0",  ps1_tag[0],  ref_ps1_tag[0]);
    tb_field_u32("ps1_tag1",  ps1_tag[1],  ref_ps1_tag[1]);
    tb_field_u32("ps2_tag0",  ps2_tag[0],  ref_ps2_tag[0]);
    tb_field_u32("ps2_tag1",  ps2_tag[1],  ref_ps2_tag[1]);
    tb_report_close(pass);

    if (pass) pass_cnt++;
    else      fail_cnt++;
  endtask

  // Hold through DUT/GM negedge update, then idle.
  task automatic cycle_hold;
    @(negedge clk);
    #1;
    clear_stim();
    #0;
  endtask

  // Probe a source mapping on the given path after maps have latched.
  task automatic probe_lookup(
      input logic       path,
      input gpr_addr_t  rs,
      input string      name,
      input string      detail
  );
    @(posedge clk);
    spec_en[0]  = path;
    rs1_use[0]  = 1;
    rs1_addr[0] = rs;
    #0;
    check_outs(name, detail);
    cycle_hold;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    rst_n = 0;
    clear_stim();
    tb_banner("alias_table_tb - DUT vs C++ golden model");

    repeat (2) @(posedge clk);
    rst_n = 1;
    @(negedge clk);
    #1;
    check_outs("reset", "identity maps; unused src -> p0");

    // ---- idle path_use follows spec_en ----
    @(posedge clk);
    spec_en[0] = 1; spec_en[1] = 0;
    #0;
    check_outs("path_use_passthru", "path_use == spec_en");
    cycle_hold;

    // ---- x0 / unused stay p0 ----
    @(posedge clk);
    rs1_use[0] = 1; rs1_addr[0] = 5'd0;
    rs2_use[1] = 0; rs2_addr[1] = 5'd5;
    #0;
    check_outs("x0_and_unused", "x0 and !rs_use -> p0");
    cycle_hold;

    // ---- single alloc path0 (map_br1) ----
    @(posedge clk);
    alloc_en[0]      = 1;
    alloc_rd_addr[0] = 5'd1;
    alloc_rob_tag[0] = 6'd32;
    spec_en[0]       = 0;
    #0;
    check_outs("alloc0_path0_idx", "combo still sees old map");
    cycle_hold;
    probe_lookup(1'b0, 5'd1, "after_alloc0_path0", "x1 path0 -> p32");

    // ---- single alloc path1 (map_br0) ----
    @(posedge clk);
    alloc_en[0]      = 1;
    alloc_rd_addr[0] = 5'd2;
    alloc_rob_tag[0] = 6'd33;
    spec_en[0]       = 1;
    #0;
    cycle_hold;
    probe_lookup(1'b1, 5'd2, "after_alloc0_path1", "x2 path1 -> p33");

    // ---- dual alloc distinct rds same path ----
    @(posedge clk);
    alloc_en[0] = 1; alloc_en[1] = 1;
    alloc_rd_addr[0] = 5'd3; alloc_rd_addr[1] = 5'd4;
    alloc_rob_tag[0] = 6'd34; alloc_rob_tag[1] = 6'd35;
    spec_en[0] = 0; spec_en[1] = 0;
    #0;
    cycle_hold;
    @(posedge clk);
    spec_en[0] = 0; spec_en[1] = 0;
    rs1_use[0] = 1; rs1_addr[0] = 5'd3;
    rs1_use[1] = 1; rs1_addr[1] = 5'd4;
    #0;
    check_outs("dual_alloc_distinct", "x3->p34 x4->p35 path0");
    cycle_hold;

    // ---- dual alloc same rd: I1 wins ----
    @(posedge clk);
    alloc_en[0] = 1; alloc_en[1] = 1;
    alloc_rd_addr[0] = 5'd5; alloc_rd_addr[1] = 5'd5;
    alloc_rob_tag[0] = 6'd36; alloc_rob_tag[1] = 6'd37;
    spec_en[0] = 0; spec_en[1] = 0;
    #0;
    cycle_hold;
    probe_lookup(1'b0, 5'd5, "dual_same_rd_i1_wins", "x5 path0 -> p37 (I1)");

    // ---- x0 alloc ignored ----
    @(posedge clk);
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd0;
    alloc_rob_tag[0] = 6'd40;
    #0;
    cycle_hold;
    @(posedge clk);
    rs1_use[0] = 1; rs1_addr[0] = 5'd0;
    #0;
    check_outs("x0_alloc_ignored", "x0 stays p0");
    cycle_hold;

    // ---- I1 same-path RAW bypass ----
    @(posedge clk);
    alloc_en[0]      = 1;
    alloc_rd_addr[0] = 5'd6;
    alloc_rob_tag[0] = 6'd38;
    spec_en[0] = 0; spec_en[1] = 0;
    rs1_use[1] = 1; rs1_addr[1] = 5'd6;
    #0;
    check_outs("i1_raw_bypass", "I1 rs1 sees I0 alloc tag combo");
    cycle_hold;

    // ---- no cross-path bypass ----
    @(posedge clk);
    alloc_en[0]      = 1;
    alloc_rd_addr[0] = 5'd7;
    alloc_rob_tag[0] = 6'd39;
    spec_en[0] = 0; spec_en[1] = 1;  // different paths
    rs1_use[1] = 1; rs1_addr[1] = 5'd7;
    #0;
    check_outs("no_cross_path_bypass", "I1 reads own map, not I0 alloc");
    cycle_hold;

    // ---- I0 no same-cycle self-bypass ----
    @(posedge clk);
    alloc_en[0]      = 1;
    alloc_rd_addr[0] = 5'd8;
    alloc_rob_tag[0] = 6'd41;
    spec_en[0] = 0;
    rs1_use[0] = 1; rs1_addr[0] = 5'd8;
    #0;
    check_outs("i0_no_self_bypass", "I0 reads old map same cycle");
    cycle_hold;
    probe_lookup(1'b0, 5'd8, "after_i0_alloc", "x8 path0 -> p41 next cycle");

    // ---- RRAT commit does not change speculative lookup ----
    @(posedge clk);
    rrat_en[0]     = 1;
    rd_addr_cmt[0] = 5'd1;
    rob_tag_cmt[0] = 6'd50;
    #0;
    cycle_hold;
    probe_lookup(1'b0, 5'd1, "rrat_no_spec_change", "spec map still p32 after RRAT");

    // ---- dual RRAT same rd: I1 wins in RRAT ----
    @(posedge clk);
    rrat_en[0] = 1; rrat_en[1] = 1;
    rd_addr_cmt[0] = 5'd9; rd_addr_cmt[1] = 5'd9;
    rob_tag_cmt[0] = 6'd51; rob_tag_cmt[1] = 6'd52;
    #0;
    cycle_hold;

    // Flush restores speculative maps from RRAT (x9 -> p52)
    @(posedge clk);
    flush = 1;
    #0;
    @(negedge clk);
    #1;
    flush = 0;
    #0;
    check_outs("flush_from_rrat", "spec maps <- RRAT after dual commit");
    probe_lookup(1'b0, 5'd9, "after_flush_x9", "x9 -> p52 on both paths");
    probe_lookup(1'b1, 5'd9, "after_flush_x9_p1", "x9 path1 -> p52");

    // ---- path_sel=1: copy map_br0 -> map_br1 ----
    @(posedge clk);
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd10;
    alloc_rob_tag[0] = 6'd53;
    spec_en[0] = 1;  // write path1/map_br0
    #0;
    cycle_hold;

    @(posedge clk);
    rat_en[0]   = 1;
    path_sel[0] = 1;  // path1 wins -> map_br1 <= map_br0
    #0;
    cycle_hold;
    probe_lookup(1'b0, 5'd10, "path_sel1_copy", "path0 sees path1 map (p53)");

    // ---- path_sel=0: copy map_br1 -> map_br0 ----
    @(posedge clk);
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd11;
    alloc_rob_tag[0] = 6'd54;
    spec_en[0] = 0;  // write path0/map_br1
    #0;
    cycle_hold;

    @(posedge clk);
    rat_en[0]   = 1;
    path_sel[0] = 0;
    #0;
    cycle_hold;
    probe_lookup(1'b1, 5'd11, "path_sel0_copy", "path1 sees path0 map (p54)");

    // ---- both rat_en: younger (I1) wins ----
    @(posedge clk);
    alloc_en[0] = 1; alloc_en[1] = 1;
    alloc_rd_addr[0] = 5'd12; alloc_rd_addr[1] = 5'd13;
    alloc_rob_tag[0] = 6'd55; alloc_rob_tag[1] = 6'd56;
    spec_en[0] = 1; spec_en[1] = 0;  // x12->path1, x13->path0
    #0;
    cycle_hold;

    @(posedge clk);
    rat_en[0] = 1; rat_en[1] = 1;
    path_sel[0] = 1;  // would copy br0->br1
    path_sel[1] = 0;  // younger: copy br1->br0
    #0;
    cycle_hold;
    probe_lookup(1'b1, 5'd13, "younger_rat_wins", "I1 path_sel=0 applied");

    // ---- same-cycle path then alloc (alloc wins entry) ----
    @(posedge clk);
    // seed path1 with x14=p57
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd14;
    alloc_rob_tag[0] = 6'd57;
    spec_en[0] = 1;
    #0;
    cycle_hold;

    @(posedge clk);
    rat_en[0] = 1; path_sel[0] = 1;  // copy path1 -> path0
    alloc_en[1] = 1;
    alloc_rd_addr[1] = 5'd14;
    alloc_rob_tag[1] = 6'd58;
    spec_en[1] = 0;  // alloc into path0 after path copy
    #0;
    cycle_hold;
    probe_lookup(1'b0, 5'd14, "path_then_alloc", "alloc overrides path copy on x14");

    // ---- final flush recovery ----
    @(posedge clk);
    rrat_en[0] = 1;
    rd_addr_cmt[0] = 5'd15;
    rob_tag_cmt[0] = 6'd59;
    #0;
    cycle_hold;

    @(posedge clk);
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd15;
    alloc_rob_tag[0] = 6'd60;
    spec_en[0] = 0;
    #0;
    cycle_hold;

    @(posedge clk);
    flush = 1;
    #0;
    @(negedge clk);
    #1;
    flush = 0;
    #0;
    check_outs("flush_recovers_rrat", "spec x15 restored to RRAT p59");
    probe_lookup(1'b0, 5'd15, "post_flush_x15", "x15 -> p59");

    // ============================================================
    // Corner / hazard cases (flush priority, dual RAW, path races)
    // ============================================================

    // flush beats concurrent alloc: maps restore RRAT, alloc dropped
    @(posedge clk);
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd20;
    alloc_rob_tag[0] = 6'd61;
    spec_en[0] = 0;
    flush = 1;
    #0;
    check_outs("flush_vs_alloc_combo", "flush asserted with alloc (combo)");
    @(negedge clk);
    #1;
    flush = 0;
    clear_stim();
    #0;
    probe_lookup(1'b0, 5'd20, "flush_beats_alloc", "x20 still RRAT/identity, not p61");

    // flush beats concurrent RRAT commit (RRAT update skipped this cycle)
    @(posedge clk);
    rrat_en[0] = 1;
    rd_addr_cmt[0] = 5'd21;
    rob_tag_cmt[0] = 6'd62;
    flush = 1;
    #0;
    @(negedge clk);
    #1;
    flush = 0;
    clear_stim();
    #0;
    // second cycle: commit RRAT without flush, then flush to publish
    @(posedge clk);
    rrat_en[0] = 1;
    rd_addr_cmt[0] = 5'd21;
    rob_tag_cmt[0] = 6'd62;
    #0;
    cycle_hold;
    @(posedge clk);
    flush = 1;
    #0;
    @(negedge clk);
    #1;
    flush = 0;
    #0;
    probe_lookup(1'b0, 5'd21, "rrat_then_flush", "x21 -> p62 after deferred RRAT+flush");

    // flush + path resolve same cycle: flush wins
    @(posedge clk);
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd22;
    alloc_rob_tag[0] = 6'd63;
    spec_en[0] = 1;
    #0;
    cycle_hold;
    @(posedge clk);
    rat_en[0] = 1; path_sel[0] = 1;
    flush = 1;
    #0;
    @(negedge clk);
    #1;
    flush = 0;
    clear_stim();
    #0;
    probe_lookup(1'b0, 5'd22, "flush_beats_path", "path copy suppressed by flush");

    // I1 dual RAW: rs1 and rs2 both match I0 rd
    @(posedge clk);
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd23;
    alloc_rob_tag[0] = 6'd40;
    spec_en[0] = 0; spec_en[1] = 0;
    rs1_use[1] = 1; rs1_addr[1] = 5'd23;
    rs2_use[1] = 1; rs2_addr[1] = 5'd23;
    #0;
    check_outs("i1_dual_raw_bypass", "I1 rs1+rs2 both see I0 tag");
    cycle_hold;

    // I1 bypass on rs2 only
    @(posedge clk);
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd24;
    alloc_rob_tag[0] = 6'd41;
    spec_en[0] = 1; spec_en[1] = 1;
    rs2_use[1] = 1; rs2_addr[1] = 5'd24;
    rs1_use[1] = 1; rs1_addr[1] = 5'd1;  // mapped earlier or identity
    #0;
    check_outs("i1_rs2_raw_bypass", "only rs2 bypasses I0");
    cycle_hold;

    // alloc_en[0] with x0 rd: no I1 bypass even if rs matches 0
    @(posedge clk);
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd0;
    alloc_rob_tag[0] = 6'd42;
    spec_en[0] = 0; spec_en[1] = 0;
    rs1_use[1] = 1; rs1_addr[1] = 5'd0;
    #0;
    check_outs("no_bypass_x0_alloc", "x0 alloc never bypasses");
    cycle_hold;

    // dual alloc same rd, opposite paths — independent maps
    @(posedge clk);
    alloc_en[0] = 1; alloc_en[1] = 1;
    alloc_rd_addr[0] = 5'd25; alloc_rd_addr[1] = 5'd25;
    alloc_rob_tag[0] = 6'd43; alloc_rob_tag[1] = 6'd44;
    spec_en[0] = 0; spec_en[1] = 1;
    #0;
    cycle_hold;
    probe_lookup(1'b0, 5'd25, "split_path_rd_p0", "x25 path0 -> p43");
    probe_lookup(1'b1, 5'd25, "split_path_rd_p1", "x25 path1 -> p44");

    // same-cycle path + RRAT + alloc (all three); flush not set
    @(posedge clk);
    rat_en[0] = 1; path_sel[0] = 0;           // copy path0 -> path1
    rrat_en[0] = 1;
    rd_addr_cmt[0] = 5'd26;
    rob_tag_cmt[0] = 6'd45;
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd26;
    alloc_rob_tag[0] = 6'd46;
    spec_en[0] = 0;                            // alloc into path0
    #0;
    cycle_hold;
    // speculative path0 sees alloc p46; RRAT has p45 until flush
    probe_lookup(1'b0, 5'd26, "triple_hazard_spec", "alloc wins speculative x26");
    @(posedge clk);
    flush = 1;
    #0;
    @(negedge clk);
    #1;
    flush = 0;
    #0;
    probe_lookup(1'b0, 5'd26, "triple_hazard_flush", "flush publishes RRAT p45");
    probe_lookup(1'b1, 5'd26, "triple_hazard_flush_p1", "both paths see RRAT p45");

    // back-to-back opposite path selects
    @(posedge clk);
    alloc_en[0] = 1; alloc_rd_addr[0] = 5'd27; alloc_rob_tag[0] = 6'd47; spec_en[0] = 1;
    #0;
    cycle_hold;
    @(posedge clk);
    rat_en[0] = 1; path_sel[0] = 1;  // path1 -> path0
    #0;
    cycle_hold;
    @(posedge clk);
    alloc_en[0] = 1; alloc_rd_addr[0] = 5'd27; alloc_rob_tag[0] = 6'd48; spec_en[0] = 0;
    #0;
    cycle_hold;
    @(posedge clk);
    rat_en[0] = 1; path_sel[0] = 0;  // path0 -> path1
    #0;
    cycle_hold;
    probe_lookup(1'b1, 5'd27, "pingpong_path", "path1 sees latest path0 tag p48");

    // four-source dual lookup while I0 allocates (I1 RAW on rs1 only)
    @(posedge clk);
    alloc_en[0] = 1;
    alloc_rd_addr[0] = 5'd28;
    alloc_rob_tag[0] = 6'd49;
    spec_en[0] = 0; spec_en[1] = 0;
    rs1_use[0] = 1; rs1_addr[0] = 5'd1;
    rs2_use[0] = 1; rs2_addr[0] = 5'd2;
    rs1_use[1] = 1; rs1_addr[1] = 5'd28;
    rs2_use[1] = 1; rs2_addr[1] = 5'd3;
    #0;
    check_outs("quad_src_with_raw", "I0 map reads + I1 RAW rs1");
    cycle_hold;

    // RRAT commit of x0 ignored
    @(posedge clk);
    rrat_en[0] = 1;
    rd_addr_cmt[0] = 5'd0;
    rob_tag_cmt[0] = 6'd50;
    #0;
    cycle_hold;
    @(posedge clk);
    flush = 1;
    #0;
    @(negedge clk);
    #1;
    flush = 0;
    #0;
    @(posedge clk);
    rs1_use[0] = 1; rs1_addr[0] = 5'd0;
    #0;
    check_outs("rrat_x0_ignored", "x0 remains p0 after bogus RRAT+flush");
    cycle_hold;

    // ============================================================
    // Random stress: random legal ops, DUT vs GM every cycle
    // ============================================================
    begin
      int n;
      for (n = 0; n < 80; n++) begin
        @(posedge clk);
        flush            = ($urandom_range(0, 19) == 0);
        spec_en[0]       = $urandom_range(0, 1);
        spec_en[1]       = $urandom_range(0, 1);
        rs1_use[0]       = $urandom_range(0, 1);
        rs1_use[1]       = $urandom_range(0, 1);
        rs2_use[0]       = $urandom_range(0, 1);
        rs2_use[1]       = $urandom_range(0, 1);
        rs1_addr[0]      = gpr_addr_t'($urandom_range(0, 31));
        rs1_addr[1]      = gpr_addr_t'($urandom_range(0, 31));
        rs2_addr[0]      = gpr_addr_t'($urandom_range(0, 31));
        rs2_addr[1]      = gpr_addr_t'($urandom_range(0, 31));
        alloc_en[0]      = !flush && ($urandom_range(0, 1));
        alloc_en[1]      = !flush && ($urandom_range(0, 1));
        alloc_rd_addr[0] = gpr_addr_t'($urandom_range(0, 31));
        alloc_rd_addr[1] = gpr_addr_t'($urandom_range(0, 31));
        alloc_rob_tag[0] = prf_addr_t'($urandom_range(32, 63));
        alloc_rob_tag[1] = prf_addr_t'($urandom_range(32, 63));
        rrat_en[0]       = !flush && ($urandom_range(0, 3) == 0);
        rrat_en[1]       = !flush && ($urandom_range(0, 3) == 0);
        rd_addr_cmt[0]   = gpr_addr_t'($urandom_range(0, 31));
        rd_addr_cmt[1]   = gpr_addr_t'($urandom_range(0, 31));
        rob_tag_cmt[0]   = prf_addr_t'($urandom_range(32, 63));
        rob_tag_cmt[1]   = prf_addr_t'($urandom_range(32, 63));
        rat_en[0]        = !flush && ($urandom_range(0, 7) == 0);
        rat_en[1]        = !flush && ($urandom_range(0, 7) == 0);
        path_sel[0]      = $urandom_range(0, 1);
        path_sel[1]      = $urandom_range(0, 1);
        #0;
        check_outs($sformatf("stress_%0d", n), "random dual-issue RAT cycle");
        if (flush) begin
          @(negedge clk);
          #1;
          flush = 0;
          clear_stim();
          #0;
        end else
          cycle_hold;
      end
    end

    tb_summary(pass_cnt, fail_cnt);
    $finish;
  end

endmodule
