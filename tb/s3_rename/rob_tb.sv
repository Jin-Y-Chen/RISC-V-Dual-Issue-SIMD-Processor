`timescale 1ns / 1ps

// Self-checking ROB TB: DUT ↔ C++ golden model via DPI-C.
// Timing: posedge drive → #0 compare (combo) → negedge commit GM + DUT.
import rv_dis_pkg::*;
import rob_pkg::*;
import dpi_pkg::*;
import tb_pkg::*;

`include "../dpi/tb_console.svh"

module rob_tb;

  localparam int CLK_PERIOD = 10;

  logic clk, rst_n;

  // DUT I/O
  logic        flush;
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

  chandle gm;
  int     cycle_id;
  bit     verbose;

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

  tb_driver u_drv (
    .flush, .alloc0_en, .alloc1_en,
    .i0_reg_write, .i1_reg_write,
    .i0_is_brnch, .i1_is_brnch,
    .i0_is_store, .i1_is_store,
    .i0_spec_en, .i1_spec_en,
    .i0_rd_addr, .i1_rd_addr,
    .wback0_en, .wback1_en,
    .i0_rob_idx_wb, .i1_rob_idx_wb,
    .i0_brch_taken_wb, .i1_brch_taken_wb,
    .retire0_en, .retire1_en
  );

  tb_monitor u_mon (
    .i0_rob_idx, .i1_rob_idx, .stall,
    .i0_can_retire, .i1_can_retire,
    .rrat0_en, .rrat1_en,
    .i0_rd_addr_cmt, .i1_rd_addr_cmt,
    .i0_rob_idx_cmt, .i1_rob_idx_cmt,
    .rat0_en, .rat1_en,
    .i0_path_sel, .i1_path_sel,
    .stb0_en, .stb1_en,
    .head_q(dut.head_q),
    .tail_q(dut.tail_q),
    .occ(dut.occ),
    .active_spec_q(dut.active_spec_q)
  );

  tb_scoreboard u_sb();

  // Protocol assertions (registered-state retire; no WB bypass)
  assert property (@(posedge clk) disable iff (!rst_n)
    i1_can_retire |-> i0_can_retire)
    else $error("protocol: i1_can_retire without i0_can_retire");

  assert property (@(posedge clk) disable iff (!rst_n)
    (rrat0_en || stb0_en || rat0_en) |-> retire0_en)
    else $error("protocol: lane0 commit without retire0_en");

  assert property (@(posedge clk) disable iff (!rst_n)
    (rrat1_en || stb1_en || rat1_en) |-> (retire0_en && retire1_en && i0_can_retire))
    else $error("protocol: lane1 commit without dual-retire handshake");

  assert property (@(posedge clk) disable iff (!rst_n)
    stall == (dut.occ > (ROB_DEPTH - 2)))
    else $error("protocol: stall mismatch vs occupancy");

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  function automatic rob_obs_t gm_eval(input rob_stim_t s);
    return rob_gm_eval(gm, s);
  endfunction

  task automatic gm_commit(input rob_stim_t s);
    rob_gm_commit(gm, s);
  endtask

  // One cycle: drive → compare combo → negedge commit.
  // auto_retire: set retire*_en from can_retire after a peek eval.
  task automatic do_cycle(
    input string    name,
    inout rob_stim_t s,
    input bit       auto_retire = 0,
    input bit       quiet = 0
  );
    rob_obs_t dut_o, exp_o;
    rob_stim_t peek;

    @(posedge clk);
    if (auto_retire && !s.flush) begin
      peek = s;
      peek.retire0_en = 0;
      peek.retire1_en = 0;
      exp_o = gm_eval(peek);
      s.retire0_en = exp_o.i0_can_retire;
      s.retire1_en = exp_o.i1_can_retire;
    end
    u_drv.drive(s);
    #0;
    dut_o = u_mon.sample();
    exp_o = gm_eval(s);
    void'(u_sb.compare($sformatf("%s@%0d", name, cycle_id), dut_o, exp_o,
                        quiet && !verbose));
    // Hold stimulus through the DUT negedge sample (do not clear in this region).
    @(negedge clk);
    gm_commit(s);
    cycle_id++;
    s = stim_clear();
  endtask

  task automatic do_idle(input string name = "idle");
    rob_stim_t s;
    s = stim_clear();
    do_cycle(name, s);
  endtask

  task automatic do_flush(input string name = "flush");
    rob_stim_t s;
    s = stim_clear();
    s.flush = 1;
    do_cycle(name, s);
  endtask

  task automatic alloc_reg(
    input bit dual,
    input gpr_addr_t rd0,
    input gpr_addr_t rd1,
    input string name
  );
    rob_stim_t s;
    s = stim_clear();
    s.alloc0_en    = 1;
    s.alloc1_en    = dual;
    s.i0_reg_write = 1;
    s.i1_reg_write = dual;
    s.i0_rd_addr   = rd0;
    s.i1_rd_addr   = rd1;
    do_cycle(name, s);
  endtask

  task automatic wb_tag(
    input prf_addr_t t0,
    input bit en0,
    input bit taken0,
    input prf_addr_t t1,
    input bit en1,
    input bit taken1,
    input string name
  );
    rob_stim_t s;
    s = stim_clear();
    s.wback0_en        = en0;
    s.wback1_en        = en1;
    s.i0_rob_idx_wb    = t0;
    s.i1_rob_idx_wb    = t1;
    s.i0_brch_taken_wb = taken0;
    s.i1_brch_taken_wb = taken1;
    do_cycle(name, s);
  endtask

  task automatic banner(input string t, input string purpose);
    $display("");
    $display("======== %s ========", t);
    $display("Purpose: %s", purpose);
  endtask

  // -------------------- directed + stress tests --------------------
  task automatic run_all;
    rob_stim_t s;
    prf_addr_t tag0, tag1, tags[$];
    int i, n, lat;
    bit taken;

    // T1 Single allocation
    banner("T1 Single allocation",
           "Allocate one register-write entry; check tags, occ, stall.");
    $display("Stim: C0 alloc0 rd=1; C1 idle");
    alloc_reg(0, 5'd1, 5'd0, "T1.alloc");
    $display("Expect: tail=1 occ=1 stall=0 i0_rob_idx=p32");
    do_idle("T1.idle");

    // T2 Dual allocation
    banner("T2 Dual allocation",
           "Allocate two entries in one cycle; contiguous tags at tail.");
    do_flush("T2.flush");
    alloc_reg(1, 5'd2, 5'd3, "T2.dual");
    $display("Expect: tail=2 occ=2 tags p32/p33");

    // T3 Lane0 only
    banner("T3 Lane0 allocation only",
           "alloc0_en=1, alloc1_en=0 packs a single entry at tail.");
    do_flush();
    alloc_reg(0, 5'd4, 5'd0, "T3.lane0");

    // T4 Long-latency
    banner("T4 Long-latency instruction",
           "Allocate, idle several cycles, then WB; retire one cycle later.");
    do_flush();
    alloc_reg(0, 5'd5, 5'd0, "T4.alloc");
    tag0 = i0_rob_idx; // sampled after clear — need capture before clear
    // Re-capture via known mapping: first alloc after flush → p32
    tag0 = rob_to_prf(5'd0);
    do_idle("T4.lat1");
    do_idle("T4.lat2");
    do_idle("T4.lat3");
    wb_tag(tag0, 1, 0, '0, 0, 0, "T4.wb");
    $display("Expect after WB: still !can_retire (1-cycle delay)");
    s = stim_clear();
    s.retire0_en = 1;
    do_cycle("T4.retire_try", s); // still incomplete on this cycle? WB just applied at prior negedge
    // After T4.wb negedge, complete=1; next posedge can_retire=1
    // The retire_try above was same cycle as... wait:
    // T4.wb: posedge drive WB, #0 compare (complete still 0), negedge apply WB
    // T4.retire_try: posedge can_retire=1
    // Actually I already ran retire_try after wb — at retire_try posedge, complete is set. Good.
    // But I set retire0_en=1 unconditionally — if can_retire, commits.
    do_idle("T4.drain");

    // T5 Head blocking
    banner("T5 Head blocking by incomplete instruction",
           "Older incomplete blocks younger complete from retiring.");
    do_flush();
    alloc_reg(1, 5'd6, 5'd7, "T5.alloc"); // p32,p33
    wb_tag(rob_to_prf(5'd1), 1, 0, '0, 0, 0, "T5.wb_young");
    s = stim_clear();
    s.retire0_en = 1;
    s.retire1_en = 1;
    do_cycle("T5.blocked", s);
    $display("Expect: can_retire=00 (head incomplete)");
    wb_tag(rob_to_prf(5'd0), 1, 0, '0, 0, 0, "T5.wb_head");
    s = stim_clear();
    do_cycle("T5.ready", s, 1);
    $display("Expect: dual retire after head completes");

    // T6 ROB full stall
    banner("T6 ROB full (stall)",
           "Fill to 31+ entries; stall asserts when occ > 30.");
    do_flush();
    for (i = 0; i < 16; i++)
      alloc_reg(1, gpr_addr_t'(i[4:0]), gpr_addr_t'(i[4:0]+1), $sformatf("T6.fill%0d", i));
    $display("Expect: occ=32 stall=1");
    s = stim_clear();
    s.alloc0_en = 1;
    s.i0_reg_write = 1;
    do_cycle("T6.stall_alloc", s); // still allocates in DUT if forced — check stall high

    // T7 Empty retirement
    banner("T7 Empty ROB retirement",
           "Retire enables with empty ROB produce no commit strobes.");
    do_flush();
    s = stim_clear();
    s.retire0_en = 1;
    s.retire1_en = 1;
    do_cycle("T7.empty", s);

    // T8 Fill then drain
    banner("T8 Fill then completely drain ROB",
           "Allocate 8, WB all, auto-retire until empty.");
    do_flush();
    for (i = 0; i < 4; i++)
      alloc_reg(1, 5'd8, 5'd9, $sformatf("T8.a%0d", i));
    for (i = 0; i < 8; i += 2)
      wb_tag(rob_to_prf(rob_flat_t'(i)), 1, 0,
             rob_to_prf(rob_flat_t'(i+1)), 1, 0, $sformatf("T8.wb%0d", i));
    for (i = 0; i < 6; i++) begin
      s = stim_clear();
      do_cycle($sformatf("T8.ret%0d", i), s, 1);
    end

    // T9 Wrap-around
    banner("T9 Head/tail pointer wrap-around",
           "Advance head/tail past 32 to exercise 6-bit wrap.");
    do_flush();
    for (i = 0; i < 16; i++)
      alloc_reg(1, 5'd1, 5'd2, $sformatf("T9.f%0d", i));
    for (i = 0; i < 32; i += 2)
      wb_tag(rob_to_prf(rob_flat_t'(i)), 1, 0,
             rob_to_prf(rob_flat_t'(i+1)), 1, 0, $sformatf("T9.w%0d", i));
    for (i = 0; i < 20; i++) begin
      s = stim_clear();
      do_cycle($sformatf("T9.r%0d", i), s, 1);
    end
    alloc_reg(1, 5'd10, 5'd11, "T9.wrap_alloc");
    $display("Expect: head/tail wrapped; new tags reuse flats");

    // T10 Branch not taken
    banner("T10 Branch not taken",
           "Retire branch with br_taken=0; rat strobe, path_sel=0, spec stays 0.");
    do_flush();
    s = stim_clear();
    s.alloc0_en  = 1;
    s.i0_is_brnch = 1;
    s.i0_spec_en  = 0;
    do_cycle("T10.alloc", s);
    wb_tag(rob_to_prf(5'd0), 1, 0, '0, 0, 0, "T10.wb");
    s = stim_clear();
    do_cycle("T10.ret", s, 1);
    $display("Expect: rat0_en=1 path_sel=0 active_spec=0");

    // T11 Branch taken
    banner("T11 Branch taken",
           "Retire taken branch; active_spec becomes 1.");
    do_flush();
    s = stim_clear();
    s.alloc0_en   = 1;
    s.i0_is_brnch = 1;
    do_cycle("T11.alloc", s);
    wb_tag(rob_to_prf(5'd0), 1, 1, '0, 0, 0, "T11.wb");
    s = stim_clear();
    do_cycle("T11.ret", s, 1);
    $display("Expect: path_sel=1 active_spec=1 after commit");

    // T12 Wrong-path
    banner("T12 Wrong-path retirement",
           "Complete wrong-path entry: can_retire=1 but no commit; flush clears.");
    do_flush();
    // Establish active_spec=1 via taken branch
    s = stim_clear();
    s.alloc0_en = 1; s.i0_is_brnch = 1;
    do_cycle("T12.br_alloc", s);
    wb_tag(rob_to_prf(5'd0), 1, 1, '0, 0, 0, "T12.br_wb");
    s = stim_clear();
    do_cycle("T12.br_ret", s, 1); // active_spec=1
    // Wrong-path ALU (spec_en=0 while active_spec=1)
    s = stim_clear();
    s.alloc0_en = 1; s.i0_reg_write = 1; s.i0_spec_en = 0; s.i0_rd_addr = 5'd12;
    do_cycle("T12.wp_alloc", s);
    wb_tag(rob_to_prf(5'd1), 1, 0, '0, 0, 0, "T12.wp_wb");
    s = stim_clear();
    s.retire0_en = 1;
    do_cycle("T12.wp_try", s);
    $display("Expect: can_retire=1 but rrat0_en=0 (off-path); head stuck");
    do_flush("T12.flush");

    // T13 Store commit
    banner("T13 Store commit", "Store retirement asserts stb0_en.");
    do_flush();
    s = stim_clear();
    s.alloc0_en = 1; s.i0_is_store = 1;
    do_cycle("T13.alloc", s);
    wb_tag(rob_to_prf(5'd0), 1, 0, '0, 0, 0, "T13.wb");
    s = stim_clear();
    do_cycle("T13.ret", s, 1);
    $display("Expect: stb0_en=1");

    // T14 Register-write commit
    banner("T14 Register-write commit", "RRAT enable + rd/rob idx on retire.");
    do_flush();
    alloc_reg(0, 5'd14, 5'd0, "T14.alloc");
    wb_tag(rob_to_prf(5'd0), 1, 0, '0, 0, 0, "T14.wb");
    s = stim_clear();
    do_cycle("T14.ret", s, 1);
    $display("Expect: rrat0_en=1 rd=14 idx=p32");

    // T15 Branch + store
    banner("T15 Branch + store combination",
           "Dual alloc branch+store; dual WB; dual retire.");
    do_flush();
    s = stim_clear();
    s.alloc0_en = 1; s.alloc1_en = 1;
    s.i0_is_brnch = 1; s.i1_is_store = 1;
    do_cycle("T15.alloc", s);
    wb_tag(rob_to_prf(5'd0), 1, 0, rob_to_prf(5'd1), 1, 0, "T15.wb");
    s = stim_clear();
    do_cycle("T15.ret", s, 1);
    $display("Expect: rat0_en + stb1_en");

    // T16 Simultaneous dual retire and dual allocate
    banner("T16 Simultaneous dual retire and dual allocate",
           "Same cycle: retire two completed + allocate two new.");
    do_flush();
    alloc_reg(1, 5'd1, 5'd2, "T16.seed");
    wb_tag(rob_to_prf(5'd0), 1, 0, rob_to_prf(5'd1), 1, 0, "T16.wb");
    s = stim_clear();
    s.alloc0_en = 1; s.alloc1_en = 1;
    s.i0_reg_write = 1; s.i1_reg_write = 1;
    s.i0_rd_addr = 5'd3; s.i1_rd_addr = 5'd4;
    do_cycle("T16.both", s, 1);
    $display("Expect: head+=2 tail+=2; new entries incomplete");

    // T17 Single retirement
    banner("T17 Single retirement", "Only retire0 when one entry ready.");
    do_flush();
    alloc_reg(0, 5'd17, 5'd0, "T17.alloc");
    wb_tag(rob_to_prf(5'd0), 1, 0, '0, 0, 0, "T17.wb");
    s = stim_clear();
    s.retire0_en = 1;
    do_cycle("T17.ret", s);

    // T18 Dual retirement
    banner("T18 Dual retirement", "Two completed head entries retire together.");
    do_flush();
    alloc_reg(1, 5'd18, 5'd19, "T18.alloc");
    wb_tag(rob_to_prf(5'd0), 1, 0, rob_to_prf(5'd1), 1, 0, "T18.wb");
    s = stim_clear();
    do_cycle("T18.ret", s, 1);

    // T19 Flush
    banner("T19 Flush", "Flush clears pointers, valid, and active_spec.");
    do_flush();
    alloc_reg(1, 5'd1, 5'd2, "T19.alloc");
    do_flush("T19.flush");
    $display("Expect: head=tail=occ=0");

    // T20 Flush during writeback
    banner("T20 Flush during writeback",
           "Same-cycle flush+WB: flush wins at negedge; state cleared.");
    do_flush();
    alloc_reg(0, 5'd20, 5'd0, "T20.alloc");
    s = stim_clear();
    s.flush = 1;
    s.wback0_en = 1;
    s.i0_rob_idx_wb = rob_to_prf(5'd0);
    do_cycle("T20.flush_wb", s);

    // T21 Writeback after flush (ignored)
    banner("T21 Writeback after flush (ignored)",
           "WB to a flushed tag must not resurrect an entry.");
    do_flush();
    alloc_reg(0, 5'd21, 5'd0, "T21.alloc");
    tag0 = rob_to_prf(5'd0);
    do_flush("T21.flush");
    wb_tag(tag0, 1, 0, '0, 0, 0, "T21.wb_stale");
    s = stim_clear();
    s.retire0_en = 1;
    do_cycle("T21.no_retire", s);
    $display("Expect: can_retire=0");

    // T22 Random latencies, in-order retirement
    banner("T22 Random instruction latencies with in-order retirement",
           "Allocate N ops with staggered WB; retire in order only.");
    do_flush();
    n = 10;
    for (i = 0; i < n; i++) begin
      s = stim_clear();
      s.alloc0_en = 1;
      s.i0_reg_write = 1;
      s.i0_rd_addr = gpr_addr_t'(i[4:0]);
      do_cycle($sformatf("T22.a%0d", i), s);
      tags.push_back(rob_to_prf(rob_flat_t'(i)));
    end
    // WB in scrambled latency order but retire only when head ready
    for (i = n - 1; i >= 0; i--) begin
      wb_tag(tags[i], 1, 0, '0, 0, 0, $sformatf("T22.wb%0d", i));
      repeat (2) begin
        s = stim_clear();
        do_cycle("T22.try", s, 1, 1);
      end
    end
    for (i = 0; i < n + 2; i++) begin
      s = stim_clear();
      do_cycle("T22.drain", s, 1, 1);
    end

    // T23 Stress
    banner("T23 10k constrained-random stress",
           "Random alloc/WB/retire/flush; compare every cycle.");
    do_flush();
    for (i = 0; i < 10000; i++) begin
      s = stim_clear();
      if ($urandom_range(0, 99) < 3) begin
        s.flush = 1;
      end else begin
        if (!stall && $urandom_range(0, 1)) begin
          s.alloc0_en = 1;
          s.i0_reg_write = $urandom_range(0, 1);
          s.i0_is_brnch  = !s.i0_reg_write && $urandom_range(0, 3) == 0;
          s.i0_is_store  = !s.i0_reg_write && !s.i0_is_brnch && $urandom_range(0, 3) == 0;
          s.i0_spec_en   = dut.active_spec_q;
          s.i0_rd_addr   = gpr_addr_t'($urandom_range(1, 31));
          if (!stall && $urandom_range(0, 1)) begin
            s.alloc1_en = 1;
            s.i1_reg_write = $urandom_range(0, 1);
            s.i1_is_brnch  = !s.i1_reg_write && $urandom_range(0, 3) == 0;
            s.i1_is_store  = !s.i1_reg_write && !s.i1_is_brnch && $urandom_range(0, 3) == 0;
            s.i1_spec_en   = dut.active_spec_q;
            s.i1_rd_addr   = gpr_addr_t'($urandom_range(1, 31));
          end
        end
        // Random WB to a live flat index (best-effort)
        if (dut.occ != 0 && $urandom_range(0, 1)) begin
          s.wback0_en = 1;
          s.i0_rob_idx_wb = rob_to_prf(rob_flat_t'($urandom_range(0, 31)));
          s.i0_brch_taken_wb = $urandom_range(0, 1);
        end
      end
      do_cycle("T23", s, !s.flush, 1);
    end
  endtask

  initial begin
    verbose = $test$plusargs("VERBOSE");
    gm = rob_dpi_create();
    if (gm == null) begin
      $fatal(1, "DPI: rob_dpi_create failed");
    end

    rst_n = 0;
    u_drv.clear();
    cycle_id = 0;
    repeat (4) @(negedge clk);
    rob_dpi_reset(gm);
    rst_n = 1;
    @(posedge clk);

    run_all();

    u_sb.summary();
    rob_dpi_destroy(gm);
    if (u_sb.fail_cnt != 0)
      $fatal(1, "ROB TB failed");
    $finish;
  end

endmodule
