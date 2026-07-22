`timescale 1ns / 1ps

// Directed TB: reorder_buffer vs flat LUT golden model (gm/reorder_buffer_gm.sv).
import rv_dis_pkg::*;
import rob_pkg::*;

`include "../include/tb_console.svh"

module reorder_buffer_tb;

  localparam int CLK_PERIOD = 10;

  logic        clk, rst_n, flush;
  logic        alloc0_en, alloc1_en;
  logic        i0_reg_write, i1_reg_write;
  logic        i0_is_brnch, i1_is_brnch;
  logic        i0_is_store, i1_is_store;
  logic        i0_spec_en, i1_spec_en;
  gpr_addr_t   i0_rd_addr, i1_rd_addr;
  prf_addr_t   i0_rob_idx, i1_rob_idx;
  logic        stall;

  logic        wback0_en, wback1_en;
  prf_addr_t   i0_rob_idx_wb, i1_rob_idx_wb;
  logic        i0_brch_taken_wb, i1_brch_taken_wb;

  logic        retire0_en, retire1_en;
  logic        i0_can_retire, i1_can_retire;
  logic        rrat0_en, rrat1_en;
  gpr_addr_t   i0_rd_addr_cmt, i1_rd_addr_cmt;
  prf_addr_t   i0_rob_idx_cmt, i1_rob_idx_cmt;
  logic        rat0_en, rat1_en;
  logic        i0_path_sel, i1_path_sel;
  logic        stb0_en, stb1_en;

  prf_addr_t   ref_i0_rob_idx, ref_i1_rob_idx;
  logic        ref_stall;
  logic        ref_i0_can_retire, ref_i1_can_retire;
  logic        ref_rrat0_en, ref_rrat1_en;
  gpr_addr_t   ref_i0_rd_addr_cmt, ref_i1_rd_addr_cmt;
  prf_addr_t   ref_i0_rob_idx_cmt, ref_i1_rob_idx_cmt;
  logic        ref_rat0_en, ref_rat1_en;
  logic        ref_i0_path_sel, ref_i1_path_sel;
  logic        ref_stb0_en, ref_stb1_en;

  int pass_cnt, fail_cnt;

  reorder_buffer dut (
    .clk, .rst_n, .flush,
    .alloc0_en, .alloc1_en,
    .i0_reg_write, .i1_reg_write,
    .i0_is_brnch, .i1_is_brnch,
    .i0_is_store, .i1_is_store,
    .i0_spec_en, .i1_spec_en,
    .i0_rd_addr, .i1_rd_addr,
    .i0_rob_idx, .i1_rob_idx,
    .stall,
    .wback0_en, .wback1_en,
    .i0_rob_idx_wb, .i1_rob_idx_wb,
    .i0_brch_taken_wb, .i1_brch_taken_wb,
    .retire0_en, .retire1_en,
    .i0_can_retire, .i1_can_retire,
    .rrat0_en, .rrat1_en,
    .i0_rd_addr_cmt, .i1_rd_addr_cmt,
    .i0_rob_idx_cmt, .i1_rob_idx_cmt,
    .rat0_en, .rat1_en,
    .i0_path_sel, .i1_path_sel,
    .stb0_en, .stb1_en
  );

  reorder_buffer_gm u_gm (
    .clk, .rst_n, .flush,
    .alloc0_en, .alloc1_en,
    .i0_reg_write, .i1_reg_write,
    .i0_is_brnch, .i1_is_brnch,
    .i0_is_store, .i1_is_store,
    .i0_spec_en, .i1_spec_en,
    .i0_rd_addr, .i1_rd_addr,
    .i0_rob_idx(ref_i0_rob_idx), .i1_rob_idx(ref_i1_rob_idx),
    .stall(ref_stall),
    .wback0_en, .wback1_en,
    .i0_rob_idx_wb, .i1_rob_idx_wb,
    .i0_brch_taken_wb, .i1_brch_taken_wb,
    .retire0_en, .retire1_en,
    .i0_can_retire(ref_i0_can_retire), .i1_can_retire(ref_i1_can_retire),
    .rrat0_en(ref_rrat0_en), .rrat1_en(ref_rrat1_en),
    .i0_rd_addr_cmt(ref_i0_rd_addr_cmt), .i1_rd_addr_cmt(ref_i1_rd_addr_cmt),
    .i0_rob_idx_cmt(ref_i0_rob_idx_cmt), .i1_rob_idx_cmt(ref_i1_rob_idx_cmt),
    .rat0_en(ref_rat0_en), .rat1_en(ref_rat1_en),
    .i0_path_sel(ref_i0_path_sel), .i1_path_sel(ref_i1_path_sel),
    .stb0_en(ref_stb0_en), .stb1_en(ref_stb1_en)
  );

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  task automatic clear_stim;
    flush            = 0;
    alloc0_en        = 0;
    alloc1_en        = 0;
    i0_reg_write     = 0;
    i1_reg_write     = 0;
    i0_is_brnch      = 0;
    i1_is_brnch      = 0;
    i0_is_store      = 0;
    i1_is_store      = 0;
    i0_spec_en       = 0;
    i1_spec_en       = 0;
    i0_rd_addr       = '0;
    i1_rd_addr       = '0;
    wback0_en        = 0;
    wback1_en        = 0;
    i0_rob_idx_wb    = '0;
    i1_rob_idx_wb    = '0;
    i0_brch_taken_wb = 0;
    i1_brch_taken_wb = 0;
    retire0_en       = 0;
    retire1_en       = 0;
  endtask

  task automatic check_outs(input string name, input string detail);
    bit pass;
    pass = (i0_rob_idx === ref_i0_rob_idx) && (i1_rob_idx === ref_i1_rob_idx)
        && (stall === ref_stall)
        && (i0_can_retire === ref_i0_can_retire)
        && (i1_can_retire === ref_i1_can_retire)
        && (rrat0_en === ref_rrat0_en) && (rrat1_en === ref_rrat1_en)
        && (i0_rd_addr_cmt === ref_i0_rd_addr_cmt)
        && (i1_rd_addr_cmt === ref_i1_rd_addr_cmt)
        && (i0_rob_idx_cmt === ref_i0_rob_idx_cmt)
        && (i1_rob_idx_cmt === ref_i1_rob_idx_cmt)
        && (rat0_en === ref_rat0_en) && (rat1_en === ref_rat1_en)
        && (i0_path_sel === ref_i0_path_sel)
        && (i1_path_sel === ref_i1_path_sel)
        && (stb0_en === ref_stb0_en) && (stb1_en === ref_stb1_en);

    tb_report_open(pass, name, detail);

    tb_log_section("inputs");
    tb_field_in_bit("clk",             clk);
    tb_field_in_bit("rst_n",           rst_n);
    tb_field_in_bit("flush",           flush);
    tb_field_in_bit("alloc0_en",       alloc0_en);
    tb_field_in_bit("alloc1_en",       alloc1_en);
    tb_field_in_bit("i0_reg_write",    i0_reg_write);
    tb_field_in_bit("i1_reg_write",    i1_reg_write);
    tb_field_in_bit("i0_is_brnch",     i0_is_brnch);
    tb_field_in_bit("i1_is_brnch",     i1_is_brnch);
    tb_field_in_bit("i0_is_store",     i0_is_store);
    tb_field_in_bit("i1_is_store",     i1_is_store);
    tb_field_in_bit("i0_spec_en",      i0_spec_en);
    tb_field_in_bit("i1_spec_en",      i1_spec_en);
    tb_field_in_u32("i0_rd_addr",      i0_rd_addr);
    tb_field_in_u32("i1_rd_addr",      i1_rd_addr);
    tb_field_in_bit("wback0_en",       wback0_en);
    tb_field_in_bit("wback1_en",       wback1_en);
    tb_field_in_u32("i0_rob_idx_wb",   i0_rob_idx_wb);
    tb_field_in_u32("i1_rob_idx_wb",   i1_rob_idx_wb);
    tb_field_in_bit("i0_brch_taken_wb", i0_brch_taken_wb);
    tb_field_in_bit("i1_brch_taken_wb", i1_brch_taken_wb);
    tb_field_in_bit("retire0_en",      retire0_en);
    tb_field_in_bit("retire1_en",      retire1_en);
    $display("");

    tb_log_section("outputs (DUT vs GM)");
    tb_field_u32("i0_rob_idx",     i0_rob_idx,     ref_i0_rob_idx);
    tb_field_u32("i1_rob_idx",     i1_rob_idx,     ref_i1_rob_idx);
    tb_field_bit("stall",          stall,          ref_stall);
    tb_field_bit("i0_can_retire",  i0_can_retire,  ref_i0_can_retire);
    tb_field_bit("i1_can_retire",  i1_can_retire,  ref_i1_can_retire);
    tb_field_bit("rrat0_en",       rrat0_en,       ref_rrat0_en);
    tb_field_bit("rrat1_en",       rrat1_en,       ref_rrat1_en);
    tb_field_u32("i0_rd_addr_cmt", i0_rd_addr_cmt, ref_i0_rd_addr_cmt);
    tb_field_u32("i1_rd_addr_cmt", i1_rd_addr_cmt, ref_i1_rd_addr_cmt);
    tb_field_u32("i0_rob_idx_cmt", i0_rob_idx_cmt, ref_i0_rob_idx_cmt);
    tb_field_u32("i1_rob_idx_cmt", i1_rob_idx_cmt, ref_i1_rob_idx_cmt);
    tb_field_bit("rat0_en",        rat0_en,        ref_rat0_en);
    tb_field_bit("rat1_en",        rat1_en,        ref_rat1_en);
    tb_field_bit("i0_path_sel",    i0_path_sel,    ref_i0_path_sel);
    tb_field_bit("i1_path_sel",    i1_path_sel,    ref_i1_path_sel);
    tb_field_bit("stb0_en",        stb0_en,        ref_stb0_en);
    tb_field_bit("stb1_en",        stb1_en,        ref_stb1_en);
    tb_report_close(pass);

    if (pass) pass_cnt++;
    else      fail_cnt++;
  endtask

  task automatic dump_rob_txt(input string path);
    int fd;
    rob_payload_t p;
    logic         v;
    rob_flat_t    flat;
    rob_ptr_t     occ_now;

    fd = $fopen(path, "w");
    if (fd == 0) begin
      $error("dump_rob_txt: cannot open %s", path);
      return;
    end

    occ_now = dut.tail_q - dut.head_q;
    $fdisplay(fd, "# reorder_buffer DUT bank");
    $fdisplay(fd, "# ROB_DEPTH=%0d ROB_SETS=%0d ROB_WAYS=%0d",
              ROB_DEPTH, ROB_SETS, ROB_WAYS);
    $fdisplay(fd, "# head=0x%0h tail=0x%0h occ=%0d stall=%0d active_spec=%0d",
              dut.head_q, dut.tail_q, occ_now, dut.stall, dut.active_spec_q);
    $fdisplay(fd, "# columns: flat  set  way  V  complete  reg_wr  br  st  spec  rd  br_taken  prf");
    $fdisplay(fd, "");

    for (int s = 0; s < ROB_SETS; s++) begin
      $fdisplay(fd, "# set %0d", s);
      for (int w = 0; w < ROB_WAYS; w++) begin
        flat = {s[ROB_SET_AW-1:0], w[ROB_WAY_AW-1:0]};
        v    = dut.valid_q[s][w];
        p    = dut.rob_q[s][w];
        if (v)
          $fdisplay(fd,
              "  %02d  %02d  %0d  %0d  %0d  %0d  %0d  %0d  %0d  x%-2d  %0d  p%0d",
              flat, s, w, v, p.complete, p.reg_write, p.is_branch, p.is_store,
              p.spec_en, p.rd, p.br_taken, rob_to_prf(flat));
        else
          $fdisplay(fd, "  %02d  %02d  %0d  %0d  -", flat, s, w, v);
      end
      $fdisplay(fd, "");
    end

    $fclose(fd);
    $display("[INFO] ROB dump -> %s", path);
  endtask

  // Hold stimulus through one negedge (DUT/GM update), then idle.
  task automatic cycle_hold;
    @(negedge clk);
    #1;
    clear_stim();
    #0;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    rst_n = 0;
    clear_stim();
    tb_banner("reorder_buffer_tb — DUT vs LUT golden model");

    repeat (2) @(posedge clk);
    rst_n = 1;
    @(negedge clk);
    #1;
    check_outs("reset", "empty ROB, next tags p32/p33");

    // ---- dual alloc ALU pair ----
    @(posedge clk);
    alloc0_en    = 1; alloc1_en = 1;
    i0_reg_write = 1; i1_reg_write = 1;
    i0_rd_addr   = 5'd1; i1_rd_addr = 5'd2;
    #0;
    check_outs("dual_alloc_idx", "combo tags p32/p33 before latch");
    cycle_hold;
    check_outs("after_dual_alloc", "tail advanced; next tags p34/p35");

    // ---- WB both + dual retire/commit ----
    @(posedge clk);
    wback0_en     = 1; wback1_en = 1;
    i0_rob_idx_wb = rob_to_prf(5'd0);
    i1_rob_idx_wb = rob_to_prf(5'd1);
    #0;
    check_outs("wb_bypass_ready", "complete via WB forward → can_retire");
    retire0_en = 1; retire1_en = 1;
    #0;
    check_outs("dual_commit", "RRAT dual commit p32/p33 rd=1/2");
    cycle_hold;
    check_outs("after_dual_commit", "head advanced; queue empty");

    // ---- single-instruction alloc (I0 only) ----
    @(posedge clk);
    alloc0_en    = 1;
    i0_reg_write = 1;
    i0_rd_addr   = 5'd3;
    #0;
    check_outs("single_alloc0_idx", "only I0 → tag at current tail");
    cycle_hold;
    check_outs("after_single_alloc0", "tail +1");

    // ---- single alloc I1-only (bubble in I0) ----
    @(posedge clk);
    alloc1_en    = 1;
    i1_reg_write = 1;
    i1_is_store  = 1;
    i1_rd_addr   = 5'd4;
    #0;
    check_outs("single_alloc1_idx", "I1 packs at tail (same as I0 slot)");
    cycle_hold;

    // WB + retire store (head is rd=3 ALU, then store)
    @(posedge clk);
    wback0_en = 1; i0_rob_idx_wb = rob_to_prf(5'd2); // flat 2 after prior commits
    #0;
    retire0_en = i0_can_retire;
    #0;
    check_outs("commit_single_alu", "commit head ALU (rd=3)");
    cycle_hold;

    @(posedge clk);
    wback0_en = 1; i0_rob_idx_wb = rob_to_prf(5'd3);
    #0;
    retire0_en = i0_can_retire;
    #0;
    check_outs("commit_store", "stb0_en on store commit");
    cycle_hold;

    // ---- branch alloc + taken WB + path commit ----
    begin
      prf_addr_t br_tag;
      @(posedge clk);
      alloc0_en   = 1;
      i0_is_brnch = 1;
      i0_spec_en  = 0;
      i0_rd_addr  = 5'd0;
      br_tag      = i0_rob_idx;
      #0;
      cycle_hold;

      @(posedge clk);
      wback0_en        = 1;
      i0_rob_idx_wb    = br_tag;
      i0_brch_taken_wb = 1;
      #0;
      retire0_en = i0_can_retire;
      #0;
      check_outs("branch_taken_commit", "rat0_en + path_sel=1");
      cycle_hold;
    end

    // ---- fill until stall (occ > DEPTH-2) ----
    begin
      int k;
      for (k = 0; k < 16; k++) begin
        @(posedge clk);
        alloc0_en = 1; alloc1_en = 1;
        i0_reg_write = 1; i1_reg_write = 1;
        i0_rd_addr = 5'd5; i1_rd_addr = 5'd6;
        #0;
        cycle_hold;
      end
      @(posedge clk);
      #0;
      check_outs("full_stall", "32 entries → stall");
      // Snapshot full bank before flush clears it
      if ($test$plusargs("rob_dump")) begin
        string dump_path;
        dump_path = "rob_bank.txt";
        void'($value$plusargs("rob_dump=%s", dump_path));
        dump_rob_txt(dump_path);
      end
    end

    // ---- flush ----
    @(posedge clk);
    flush = 1;
    #0;
    @(negedge clk);
    #1;
    flush = 0;
    #0;
    check_outs("flush", "pointers/valid cleared; tags back to p32/p33");

    tb_summary(pass_cnt, fail_cnt);
    $finish;
  end

endmodule
