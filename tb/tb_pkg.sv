`timescale 1ns / 1ps

// Global TB types and ROB DPI helpers (import dpi_pkg for raw DPI-C).
package tb_pkg;

  import rv_dis_pkg::*;
  import rob_pkg::*;
  import dpi_pkg::*;

  // ---- ROB stim / obs (unit + CPU env) ----
  typedef struct packed {
    logic      flush;
    logic      alloc0_en, alloc1_en;
    logic      i0_reg_write, i1_reg_write;
    logic      i0_is_brnch, i1_is_brnch;
    logic      i0_is_store, i1_is_store;
    logic      i0_spec_en, i1_spec_en;
    logic      i0_state_valid, i1_state_valid;
    br_state_t i0_brch_state, i1_brch_state;
    gpr_addr_t i0_rd_addr, i1_rd_addr;
    logic      wback0_en, wback1_en;
    prf_addr_t i0_rob_idx_wb, i1_rob_idx_wb;
    logic      i0_brch_taken_wb, i1_brch_taken_wb;
    logic      retire0_en, retire1_en;
  } rob_stim_t;

  typedef struct packed {
    prf_addr_t  i0_rob_idx, i1_rob_idx;
    logic       stall;
    logic       i0_can_retire, i1_can_retire;
    logic       rrat0_en, rrat1_en;
    gpr_addr_t  i0_rd_addr_cmt, i1_rd_addr_cmt;
    prf_addr_t  i0_rob_idx_cmt, i1_rob_idx_cmt;
    logic       rat0_en, rat1_en;
    logic       i0_path_sel, i1_path_sel;
    logic       stb0_en, stb1_en;
    logic [5:0] head, tail, occ;
    logic       active_spec;
  } rob_obs_t;

  // ---- CPU / commit / memory lightweight txn fields ----
  typedef struct packed {
    logic        valid;
    logic        flush;
    logic        enable;
    word_t       pc0;
    word_t       pc1;
  } cpu_txn_t;

  typedef struct packed {
    logic        rrat0_en, rrat1_en;
    logic        stb0_en, stb1_en;
    logic        rat0_en, rat1_en;
    gpr_addr_t   rd0, rd1;
    prf_addr_t   rob0, rob1;
    logic        path0, path1;
  } commit_txn_t;

  typedef struct packed {
    logic        req;
    logic        we;
    word_t       addr;
    word_t       wdata;
    word_t       rdata;
    logic        rvalid;
  } memory_txn_t;

  function automatic rob_stim_t rob_stim_clear();
    rob_stim_clear = '0;
  endfunction

  function automatic rob_stim_t stim_clear();
    return rob_stim_clear();
  endfunction

  function automatic string rob_obs_str(input rob_obs_t o);
    return $sformatf(
      "stall=%0d can=%0d%0d rrat=%0d%0d rat=%0d%0d stb=%0d%0d rd=%0d/%0d idx=%02h/%02h ht=%0d/%0d occ=%0d spec=%0d",
      o.stall, o.i0_can_retire, o.i1_can_retire,
      o.rrat0_en, o.rrat1_en, o.rat0_en, o.rat1_en,
      o.stb0_en, o.stb1_en,
      o.i0_rd_addr_cmt, o.i1_rd_addr_cmt,
      o.i0_rob_idx_cmt, o.i1_rob_idx_cmt,
      o.head, o.tail, o.occ, o.active_spec);
  endfunction

  function automatic string obs_str(input rob_obs_t o);
    return rob_obs_str(o);
  endfunction

  function automatic rob_obs_t rob_gm_eval(input chandle h, input rob_stim_t s);
    rob_obs_t o;
    int i0i, i1i, st, c0, c1, r0, r1, rd0, rd1, ci0, ci1;
    int ra0, ra1, ps0, ps1, s0, s1, hd, tl, oc, sp;
    rob_dpi_eval(
      h, int'(s.flush),
      int'(s.alloc0_en), int'(s.alloc1_en),
      int'(s.i0_reg_write), int'(s.i1_reg_write),
      int'(s.i0_is_brnch), int'(s.i1_is_brnch),
      int'(s.i0_is_store), int'(s.i1_is_store),
      int'(s.i0_spec_en), int'(s.i1_spec_en),
      int'(s.i0_state_valid), int'(s.i1_state_valid),
      int'(s.i0_brch_state), int'(s.i1_brch_state),
      int'(s.i0_rd_addr), int'(s.i1_rd_addr),
      int'(s.wback0_en), int'(s.wback1_en),
      int'(s.i0_rob_idx_wb), int'(s.i1_rob_idx_wb),
      int'(s.i0_brch_taken_wb), int'(s.i1_brch_taken_wb),
      int'(s.retire0_en), int'(s.retire1_en),
      i0i, i1i, st, c0, c1, r0, r1, rd0, rd1, ci0, ci1,
      ra0, ra1, ps0, ps1, s0, s1, hd, tl, oc, sp);
    o.i0_rob_idx     = prf_addr_t'(i0i);
    o.i1_rob_idx     = prf_addr_t'(i1i);
    o.stall          = st[0];
    o.i0_can_retire  = c0[0];
    o.i1_can_retire  = c1[0];
    o.rrat0_en       = r0[0];
    o.rrat1_en       = r1[0];
    o.i0_rd_addr_cmt = gpr_addr_t'(rd0);
    o.i1_rd_addr_cmt = gpr_addr_t'(rd1);
    o.i0_rob_idx_cmt = prf_addr_t'(ci0);
    o.i1_rob_idx_cmt = prf_addr_t'(ci1);
    o.rat0_en        = ra0[0];
    o.rat1_en        = ra1[0];
    o.i0_path_sel    = ps0[0];
    o.i1_path_sel    = ps1[0];
    o.stb0_en        = s0[0];
    o.stb1_en        = s1[0];
    o.head           = hd[5:0];
    o.tail           = tl[5:0];
    o.occ            = oc[5:0];
    o.active_spec    = sp[0];
    return o;
  endfunction

  task automatic rob_gm_commit(input chandle h, input rob_stim_t s);
    rob_dpi_commit(
      h, int'(s.flush),
      int'(s.alloc0_en), int'(s.alloc1_en),
      int'(s.i0_reg_write), int'(s.i1_reg_write),
      int'(s.i0_is_brnch), int'(s.i1_is_brnch),
      int'(s.i0_is_store), int'(s.i1_is_store),
      int'(s.i0_spec_en), int'(s.i1_spec_en),
      int'(s.i0_state_valid), int'(s.i1_state_valid),
      int'(s.i0_brch_state), int'(s.i1_brch_state),
      int'(s.i0_rd_addr), int'(s.i1_rd_addr),
      int'(s.wback0_en), int'(s.wback1_en),
      int'(s.i0_rob_idx_wb), int'(s.i1_rob_idx_wb),
      int'(s.i0_brch_taken_wb), int'(s.i1_brch_taken_wb),
      int'(s.retire0_en), int'(s.retire1_en));
  endtask

endpackage
