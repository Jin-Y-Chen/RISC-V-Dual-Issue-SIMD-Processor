`timescale 1ns / 1ps

// Directed TB: reorder_buffer vs flat LUT golden model.
// Stim/observe use the same [2] array ports as reorder_buffer (I0=0, I1=1).
import rv_dis_pkg::*;
import rob_pkg::*;

`include "../../common/utils/tb_console.svh"

module reorder_buffer_tb;

  localparam int CLK_PERIOD = 10;

  // ---- DUT ports (match reorder_buffer.sv) ----
  logic        clk, rst_n, flush;

  logic        alloc_en      [2];
  logic        reg_write     [2];
  logic        is_brnch      [2];
  logic        is_store      [2];
  logic        spec_en       [2];
  logic        state_valid   [2];
  br_state_t   brch_state    [2];
  gpr_addr_t   rd_addr       [2];
  prf_addr_t   rob_tag       [2];
  logic        rob_valid     [2];
  logic        stall;

  logic        wback_en      [2];
  prf_addr_t   rob_tag_wb    [2];
  logic        brch_taken_wb [2];

  logic        retire_en     [2];

  logic        rrat_en       [2];
  gpr_addr_t   rd_addr_cmt   [2];
  prf_addr_t   rob_tag_cmt   [2];

  logic        rat_en        [2];
  logic        path_sel      [2];

  logic        stb_en        [2];

  // ---- GM mirrors ----
  prf_addr_t   ref_rob_tag     [2];
  logic        ref_stall;
  logic        ref_can_retire  [2];
  logic        ref_rrat_en     [2];
  gpr_addr_t   ref_rd_addr_cmt [2];
  prf_addr_t   ref_rob_tag_cmt [2];
  logic        ref_rat_en      [2];
  logic        ref_path_sel    [2];
  logic        ref_stb_en      [2];

  int pass_cnt, fail_cnt;

  reorder_buffer dut (
    .clk, .rst_n, .flush,
    .alloc_en, .reg_write, .is_brnch, .is_store, .spec_en,
    .state_valid, .brch_state, .rd_addr,
    .rob_tag, .rob_valid, .stall,
    .wback_en, .rob_tag_wb, .brch_taken_wb,
    .retire_en,
    .rrat_en, .rd_addr_cmt, .rob_tag_cmt,
    .rat_en, .path_sel, .stb_en
  );

  reorder_buffer_gm u_gm (
    .clk, .rst_n, .flush,
    .alloc_en, .reg_write, .is_brnch, .is_store, .spec_en,
    .state_valid, .brch_state, .rd_addr,
    .rob_tag(ref_rob_tag), .stall(ref_stall),
    .wback_en, .rob_tag_wb, .brch_taken_wb,
    .retire_en,
    .can_retire(ref_can_retire),
    .rrat_en(ref_rrat_en),
    .rd_addr_cmt(ref_rd_addr_cmt),
    .rob_tag_cmt(ref_rob_tag_cmt),
    .rat_en(ref_rat_en),
    .path_sel(ref_path_sel),
    .stb_en(ref_stb_en)
  );

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  task automatic clear_stim;
    flush = 0;
    for (int i = 0; i < 2; i++) begin
      alloc_en[i]      = 0;
      reg_write[i]     = 0;
      is_brnch[i]      = 0;
      is_store[i]      = 0;
      spec_en[i]       = 0;
      state_valid[i]   = 0;
      brch_state[i]    = '0;
      // Keep last rd_addr so idle/retire dumps stay identifiable.
      wback_en[i]      = 0;
      rob_tag_wb[i]    = '0;
      brch_taken_wb[i] = 0;
      retire_en[i]     = 0;
    end
  endtask

  task automatic check_outs(input string name, input string detail);
    bit pass;
    // rob_valid tracks alloc_en in rob_alloc (GM has no rob_valid port)
    pass = (rob_tag[0] === ref_rob_tag[0]) && (rob_tag[1] === ref_rob_tag[1])
        && (rob_valid[0] === alloc_en[0]) && (rob_valid[1] === alloc_en[1])
        && (stall === ref_stall)
        && (rrat_en[0] === ref_rrat_en[0]) && (rrat_en[1] === ref_rrat_en[1])
        && (rd_addr_cmt[0] === ref_rd_addr_cmt[0])
        && (rd_addr_cmt[1] === ref_rd_addr_cmt[1])
        && (rob_tag_cmt[0] === ref_rob_tag_cmt[0])
        && (rob_tag_cmt[1] === ref_rob_tag_cmt[1])
        && (rat_en[0] === ref_rat_en[0]) && (rat_en[1] === ref_rat_en[1])
        && (path_sel[0] === ref_path_sel[0]) && (path_sel[1] === ref_path_sel[1])
        && (stb_en[0] === ref_stb_en[0]) && (stb_en[1] === ref_stb_en[1]);

    tb_report_open(pass, name, detail);

    tb_log_section("inputs");
    tb_field_in_clk(clk);
    tb_field_in_bit("rst_n",            rst_n);
    tb_field_in_bit("flush",            flush);
    tb_field_in_bit("alloc_en[0]",      alloc_en[0]);
    tb_field_in_bit("alloc_en[1]",      alloc_en[1]);
    tb_field_in_bit("reg_write[0]",     reg_write[0]);
    tb_field_in_bit("reg_write[1]",     reg_write[1]);
    tb_field_in_bit("is_brnch[0]",      is_brnch[0]);
    tb_field_in_bit("is_brnch[1]",      is_brnch[1]);
    tb_field_in_bit("is_store[0]",      is_store[0]);
    tb_field_in_bit("is_store[1]",      is_store[1]);
    tb_field_in_bit("spec_en[0]",       spec_en[0]);
    tb_field_in_bit("spec_en[1]",       spec_en[1]);
    tb_field_in_bit("state_valid[0]",   state_valid[0]);
    tb_field_in_bit("state_valid[1]",   state_valid[1]);
    tb_field_in_u32("brch_state[0]",    brch_state[0]);
    tb_field_in_u32("brch_state[1]",    brch_state[1]);
    tb_field_in_u32("rd_addr[0]",       rd_addr[0]);
    tb_field_in_u32("rd_addr[1]",       rd_addr[1]);
    tb_field_in_bit("wback_en[0]",      wback_en[0]);
    tb_field_in_bit("wback_en[1]",      wback_en[1]);
    tb_field_in_u32("rob_tag_wb[0]",    rob_tag_wb[0]);
    tb_field_in_u32("rob_tag_wb[1]",    rob_tag_wb[1]);
    tb_field_in_bit("brch_taken_wb[0]", brch_taken_wb[0]);
    tb_field_in_bit("brch_taken_wb[1]", brch_taken_wb[1]);
    tb_field_in_bit("retire_en[0]",     retire_en[0]);
    tb_field_in_bit("retire_en[1]",     retire_en[1]);
    $display("");

    tb_log_section("outputs (DUT vs GM)");
    tb_field_u32("rob_tag[0]",     rob_tag[0],     ref_rob_tag[0]);
    tb_field_u32("rob_tag[1]",     rob_tag[1],     ref_rob_tag[1]);
    tb_field_bit("rob_valid[0]",   rob_valid[0],   alloc_en[0]);
    tb_field_bit("rob_valid[1]",   rob_valid[1],   alloc_en[1]);
    tb_field_bit("stall",          stall,          ref_stall);
    tb_field_bit("rrat_en[0]",     rrat_en[0],     ref_rrat_en[0]);
    tb_field_bit("rrat_en[1]",     rrat_en[1],     ref_rrat_en[1]);
    tb_field_u32("rd_addr_cmt[0]", rd_addr_cmt[0], ref_rd_addr_cmt[0]);
    tb_field_u32("rd_addr_cmt[1]", rd_addr_cmt[1], ref_rd_addr_cmt[1]);
    tb_field_u32("rob_tag_cmt[0]", rob_tag_cmt[0], ref_rob_tag_cmt[0]);
    tb_field_u32("rob_tag_cmt[1]", rob_tag_cmt[1], ref_rob_tag_cmt[1]);
    tb_field_bit("rat_en[0]",      rat_en[0],      ref_rat_en[0]);
    tb_field_bit("rat_en[1]",      rat_en[1],      ref_rat_en[1]);
    tb_field_bit("path_sel[0]",    path_sel[0],    ref_path_sel[0]);
    tb_field_bit("path_sel[1]",    path_sel[1],    ref_path_sel[1]);
    tb_field_bit("stb_en[0]",      stb_en[0],      ref_stb_en[0]);
    tb_field_bit("stb_en[1]",      stb_en[1],      ref_stb_en[1]);
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
    rd_addr[0] = '0;
    rd_addr[1] = '0;
    tb_banner("reorder_buffer_tb - DUT vs LUT golden model");

    repeat (2) @(posedge clk);
    rst_n = 1;
    @(negedge clk);
    #1;
    check_outs("reset", "empty ROB, next tags p32/p33");

    // ---- dual alloc ALU pair ----
    @(posedge clk);
    alloc_en[0] = 1; alloc_en[1] = 1;
    reg_write[0] = 1; reg_write[1] = 1;
    rd_addr[0] = 5'd1; rd_addr[1] = 5'd2;
    #0;
    check_outs("dual_alloc_idx", "combo tags p32/p33 before latch");
    cycle_hold;
    check_outs("after_dual_alloc", "tail advanced; next tags p34/p35");

    // ---- WB both, then retire next cycle ----
    @(posedge clk);
    wback_en[0] = 1; wback_en[1] = 1;
    rob_tag_wb[0] = rob_to_prf(5'd0);
    rob_tag_wb[1] = rob_to_prf(5'd1);
    #0;
    check_outs("wb_assert", "WB tags presented; complete not latched yet");
    cycle_hold;
    check_outs("after_wb", "entries complete; ready to retire");

    @(posedge clk);
    retire_en[0] = 1; retire_en[1] = 1;
    #0;
    check_outs("dual_commit", "RRAT dual commit p32/p33 rd=1/2");
    cycle_hold;
    check_outs("after_dual_commit", "head advanced; queue empty");

    // ---- single-instruction alloc (I0 only) ----
    @(posedge clk);
    alloc_en[0]  = 1;
    reg_write[0] = 1;
    rd_addr[0]   = 5'd3;
    #0;
    check_outs("single_alloc0_idx", "only I0 -> tag at current tail");
    cycle_hold;
    check_outs("after_single_alloc0", "tail +1");

    // ---- single alloc I1-only (bubble in I0) ----
    @(posedge clk);
    alloc_en[1] = 1;
    reg_write[1] = 1;
    is_store[1] = 1;
    rd_addr[1]  = 5'd4;
    #0;
    check_outs("single_alloc1_idx", "I1 packs at tail (same as I0 slot)");
    cycle_hold;

    @(posedge clk);
    wback_en[0] = 1; rob_tag_wb[0] = rob_to_prf(5'd2);
    #0;
    cycle_hold;

    @(posedge clk);
    retire_en[0] = 1;
    #0;
    check_outs("commit_single_alu", "commit head ALU (rd=3)");
    cycle_hold;

    @(posedge clk);
    wback_en[0] = 1; rob_tag_wb[0] = rob_to_prf(5'd3);
    #0;
    cycle_hold;

    @(posedge clk);
    retire_en[0] = 1;
    #0;
    check_outs("commit_store", "stb_en[0] on store commit");
    cycle_hold;

    // ---- branch alloc + taken WB + path commit ----
    begin
      prf_addr_t br_tag;
      @(posedge clk);
      alloc_en[0] = 1;
      is_brnch[0] = 1;
      spec_en[0]  = 0;
      rd_addr[0]  = 5'd7;
      br_tag      = rob_tag[0];
      #0;
      cycle_hold;

      @(posedge clk);
      wback_en[0]      = 1;
      rob_tag_wb[0]    = br_tag;
      brch_taken_wb[0] = 1;
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1;
      #0;
      check_outs("branch_taken_commit", "rat_en[0] + path_sel[0]=1");
      cycle_hold;
    end

    // ---- fill until stall (occ > DEPTH-2) ----
    begin
      int k;
      for (k = 0; k < 16; k++) begin
        @(posedge clk);
        alloc_en[0] = 1; alloc_en[1] = 1;
        reg_write[0] = 1; reg_write[1] = 1;
        rd_addr[0] = 5'(1 + ((8 + 2 * k) % 31));
        rd_addr[1] = 5'(1 + ((9 + 2 * k) % 31));
        #0;
        cycle_hold;
      end
      @(posedge clk);
      #0;
      check_outs("full_stall", "32 entries -> stall");
      if ($test$plusargs("rob_dump")) begin
        string dump_path;
        dump_path = "rob_bank.txt";
        if (!$value$plusargs("rob_dump=%s", dump_path))
          dump_path = "rob_bank.txt";
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

    // ---- branch not-taken ----
    begin
      prf_addr_t br_tag;
      @(posedge clk);
      alloc_en[0] = 1;
      is_brnch[0] = 1;
      rd_addr[0]  = 5'd8;
      br_tag      = rob_tag[0];
      #0;
      cycle_hold;

      @(posedge clk);
      wback_en[0]      = 1;
      rob_tag_wb[0]    = br_tag;
      brch_taken_wb[0] = 0;
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1;
      #0;
      check_outs("branch_not_taken", "rat_en[0] + path_sel[0]=0");
      cycle_hold;
    end

    // ---- retire before complete ----
    begin
      prf_addr_t t0;
      @(posedge clk);
      alloc_en[0]  = 1;
      reg_write[0] = 1;
      rd_addr[0]   = 5'd9;
      t0           = rob_tag[0];
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1;
      #0;
      check_outs("retire_before_wb", "head incomplete -> no RRAT");
      cycle_hold;

      @(posedge clk);
      wback_en[0]   = 1;
      rob_tag_wb[0] = t0;
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1;
      #0;
      check_outs("retire_after_wb", "RRAT after registered complete");
      cycle_hold;
    end

    // ---- OOO WB, in-order retire ----
    begin
      prf_addr_t t0, t1;
      @(posedge clk);
      alloc_en[0] = 1; alloc_en[1] = 1;
      reg_write[0] = 1; reg_write[1] = 1;
      rd_addr[0] = 5'd10; rd_addr[1] = 5'd11;
      t0 = rob_tag[0]; t1 = rob_tag[1];
      #0;
      check_outs("ooo_dual_alloc", "pair for OOO writeback");
      cycle_hold;

      @(posedge clk);
      wback_en[0]   = 1;
      rob_tag_wb[0] = t1;
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1; retire_en[1] = 1;
      #0;
      check_outs("ooo_retire_blocked", "head incomplete blocks dual retire");
      cycle_hold;

      @(posedge clk);
      wback_en[0]   = 1;
      rob_tag_wb[0] = t0;
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1; retire_en[1] = 1;
      #0;
      check_outs("ooo_dual_commit", "in-order dual RRAT after both complete");
      cycle_hold;
    end

    // ---- dual store commit ----
    begin
      prf_addr_t t0, t1;
      @(posedge clk);
      alloc_en[0] = 1; alloc_en[1] = 1;
      is_store[0] = 1; is_store[1] = 1;
      rd_addr[0] = 5'd12; rd_addr[1] = 5'd13;
      t0 = rob_tag[0]; t1 = rob_tag[1];
      #0;
      cycle_hold;

      @(posedge clk);
      wback_en[0] = 1; wback_en[1] = 1;
      rob_tag_wb[0] = t0; rob_tag_wb[1] = t1;
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1; retire_en[1] = 1;
      #0;
      check_outs("dual_store_commit", "stb_en[0] + stb_en[1]");
      cycle_hold;
    end

    // ---- dual: ALU + branch taken ----
    begin
      prf_addr_t t0, t1;
      @(posedge clk);
      alloc_en[0] = 1; alloc_en[1] = 1;
      reg_write[0] = 1; rd_addr[0] = 5'd14;
      is_brnch[1]  = 1; rd_addr[1] = 5'd15;
      t0 = rob_tag[0]; t1 = rob_tag[1];
      #0;
      cycle_hold;

      @(posedge clk);
      wback_en[0] = 1; wback_en[1] = 1;
      rob_tag_wb[0] = t0; rob_tag_wb[1] = t1;
      brch_taken_wb[1] = 1;
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1; retire_en[1] = 1;
      #0;
      check_outs("alu_branch_dual_cmt", "rrat_en[0] + rat_en[1] path_sel[1]=1");
      cycle_hold;
    end

    // ---- speculative path: taken branch then on/off-path ALU ----
    begin
      prf_addr_t br_tag, alu_tag;
      @(posedge clk);
      flush = 1;
      #0;
      @(negedge clk);
      #1;
      flush = 0;
      #0;
      check_outs("flush_before_spec", "reset active_spec to path0");

      @(posedge clk);
      alloc_en[0] = 1;
      is_brnch[0] = 1;
      rd_addr[0]  = 5'd16;
      br_tag      = rob_tag[0];
      #0;
      cycle_hold;

      @(posedge clk);
      wback_en[0] = 1; rob_tag_wb[0] = br_tag; brch_taken_wb[0] = 1;
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1;
      #0;
      check_outs("spec_branch_taken", "active_spec -> path1");
      cycle_hold;

      @(posedge clk);
      alloc_en[0]  = 1;
      reg_write[0] = 1;
      spec_en[0]   = 1;
      rd_addr[0]   = 5'd18;
      alu_tag      = rob_tag[0];
      #0;
      cycle_hold;

      @(posedge clk);
      wback_en[0] = 1; rob_tag_wb[0] = alu_tag;
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1;
      #0;
      check_outs("on_path_commit", "spec_en==active_spec allows RRAT");
      cycle_hold;

      @(posedge clk);
      alloc_en[0]  = 1;
      reg_write[0] = 1;
      spec_en[0]   = 0;
      rd_addr[0]   = 5'd17;
      alu_tag      = rob_tag[0];
      #0;
      cycle_hold;

      @(posedge clk);
      wback_en[0] = 1; rob_tag_wb[0] = alu_tag;
      #0;
      cycle_hold;

      @(posedge clk);
      retire_en[0] = 1;
      #0;
      check_outs("off_path_no_commit", "spec_en!=active_spec blocks retire");
      cycle_hold;

      @(posedge clk);
      flush = 1;
      #0;
      @(negedge clk);
      #1;
      flush = 0;
      #0;
      check_outs("flush_after_spec", "clean ROB after path tests");
    end

    // ---- alloc after flush ----
    @(posedge clk);
    alloc_en[0] = 1; alloc_en[1] = 1;
    reg_write[0] = 1; reg_write[1] = 1;
    rd_addr[0] = 5'd19; rd_addr[1] = 5'd20;
    #0;
    check_outs("realloc_after_flush", "tags restart at p32/p33");
    cycle_hold;
    check_outs("after_realloc", "tail advanced after fresh dual alloc");

    tb_summary(pass_cnt, fail_cnt);
    $finish;
  end

endmodule
