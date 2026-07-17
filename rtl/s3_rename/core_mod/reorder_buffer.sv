`timescale 1ns / 1ps

// ROB — 8×2 bank; dual-alloc + dual-commit only (always ±2).
// Posedge: complete / clear / alloc pair; negedge: commit pair.
// Per-slot i0/i1_en: new_tag→RAT, old_tag→free_list (right-path reg-write only).
import rv_dis_pkg::*;
import rob_pkg::*;

module reorder_buffer (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  // dual alloc (fire when either lane en; always both ways of one set)
  input  logic        alloc0_en,
  input  logic        alloc1_en,
  input  logic        alloc0_reg_write,
  input  logic        alloc1_reg_write,
  input  logic        alloc0_is_brnch,
  input  logic        alloc1_is_brnch,
  input  br_map_t     brch_map,
  
  input  gpr_addr_t   i0_alloc_rd_addr,
  input  gpr_addr_t   i1_alloc_rd_addr,
  input  prf_addr_t   i0_alloc_prd_tag,
  input  prf_addr_t   i1_alloc_prd_tag,
  input  prf_addr_t   i0_alloc_prd_old,
  input  prf_addr_t   i1_alloc_prd_old,
  
  output rob_idx_t    i0_rob_idx,
  output rob_idx_t    i1_rob_idx,
  output logic        stall,          // < 2 free slots

  input  logic        wback0_en,
  input  logic        wback1_en,
  input  rob_idx_t    i0_idx_wb,
  input  rob_idx_t    i1_idx_wb,
  input  logic        i0_brch_taken_wb,
  input  logic        i1_brch_taken_wb,

  // dual commit — per slot: new_tag→RAT, old_tag→free_list (tags only)
  output logic        i0_en,
  output logic        i1_en,
  output gpr_addr_t   i0_rd_addr,
  output gpr_addr_t   i1_rd_addr,
  output prf_addr_t   i0_prd_tag,
  output prf_addr_t   i1_prd_tag,
  output prf_addr_t   i0_prd_old,
  output prf_addr_t   i1_prd_old,

  // branch commit → RAT: resolve_en=branch retiring; rat_path=winning column (0/1)
  output logic        resolve_en,
  output logic        rat_path
);

  rob_line_t bank_q [0:ROB_SETS-1][0:ROB_WAYS-1];
  rob_ptr_t  write_ptr_q, commit_ptr_q;
  br_map_t   kill_mask_q;
  logic      retire_q;          // clear head set next posedge
  rob_set_t  retire_set_q;

  wire rob_ptr_t occ = write_ptr_q - commit_ptr_q;

  // Dual-issue needs 2 free slots; stall when fewer remain.
  assign stall      = (occ > rob_ptr_t'(ROB_DEPTH - 2));
  assign i0_rob_idx = {write_ptr_q[ROB_AW-1:1], 1'b0};
  assign i1_rob_idx = {write_ptr_q[ROB_AW-1:1], 1'b1};

  wire rob_set_t alloc_set = rob_idx_set(i0_rob_idx);

  // ---- dual commit head (same set, way0+way1) ----
  wire rob_set_t cmt_set = rob_idx_set(commit_ptr_q[ROB_AW-1:0]);

  wire               v0 = rob_way_valid(bank_q[cmt_set][0]);
  wire               v1 = rob_way_valid(bank_q[cmt_set][1]);
  wire rob_payload_t p0 = rob_way_read(bank_q[cmt_set][0], '0);
  wire rob_payload_t p1 = rob_way_read(bank_q[cmt_set][1], '0);

  function automatic br_map_t kill_next(
    input br_map_t k, input logic v, input rob_payload_t p
  );
    if (v && p.is_branch && p.brch_map != BR_MAP_NONE)
      return p.br_taken ? (k & ~p.brch_map) : (k | p.brch_map);
    return k;
  endfunction

  wire br_map_t k0 = kill_next(kill_mask_q, v0, p0);
  wire br_map_t k1 = kill_next(k0, v1, p1);

  wire w0 = v0 && !p0.is_branch && |(p0.brch_map & kill_mask_q);
  wire w1 = v1 && !p1.is_branch && |(p1.brch_map & k0);

  // Both slots ready (bubble or complete) and at least one pair live.
  wire commit_pair = (occ >= 2'd2) && (!v0 || p0.complete) && (!v1 || p1.complete);

  // Per-slot commit: right-path reg-write retires new→RAT, old→free_list.
  assign i0_en      = commit_pair && v0 && p0.reg_write && !w0;
  assign i1_en      = commit_pair && v1 && p1.reg_write && !w1;

  assign i0_rd_addr  = p0.rd;
  assign i1_rd_addr  = p1.rd;
  assign i0_prd_tag  = p0.prd;
  assign i1_prd_tag  = p1.prd;
  assign i0_prd_old  = p0.prd_old;
  assign i1_prd_old  = p1.prd_old;

  wire br0 = commit_pair && v0 && p0.is_branch && (p0.brch_map != BR_MAP_NONE);
  wire br1 = commit_pair && v1 && p1.is_branch && (p1.brch_map != BR_MAP_NONE);

  assign resolve_en = br0 || br1;
  assign rat_path   = br0 ? rob_branch_rat_path(p0.brch_map, p0.br_taken)
                          : rob_branch_rat_path(p1.brch_map, p1.br_taken);

  // ---- posedge: complete / clear pair / alloc pair ----
  integer s, wy;
  always_ff @(posedge clk or negedge rst_n) begin
    rob_line_t    line;
    rob_payload_t pay;
    rob_set_t     cs0, cs1;
    rob_way_t     cw0, cw1;

    cs0 = rob_idx_set(i0_idx_wb); cw0 = rob_idx_way(i0_idx_wb);
    cs1 = rob_idx_set(i1_idx_wb); cw1 = rob_idx_way(i1_idx_wb);

    if (!rst_n || flush) begin
      write_ptr_q <= '0;
      for (s = 0; s < ROB_SETS; s++)
        for (wy = 0; wy < ROB_WAYS; wy++)
          bank_q[s][wy] <= '0;
    end else begin
      if (wback0_en) begin
        line = bank_q[cs0][cw0];
        if (rob_way_valid(line)) begin
          pay = rob_way_read(line, '0);
          pay.complete  = 1'b1;
          pay.br_taken  = i0_brch_taken_wb;
          bank_q[cs0][cw0] <= rob_way_write(1'b1, pay);
        end
      end
      if (wback1_en) begin
        line = bank_q[cs1][cw1];
        if (rob_way_valid(line)) begin
          pay = rob_way_read(line, '0);
          pay.complete  = 1'b1;
          pay.br_taken  = i1_brch_taken_wb;
          bank_q[cs1][cw1] <= rob_way_write(1'b1, pay);
        end
      end

      if (retire_q) begin
        bank_q[retire_set_q][0] <= '0;
        bank_q[retire_set_q][1] <= '0;
      end

      // Alloc pair whenever an instruction arrives (other lane may be bubble).
      if (alloc0_en || alloc1_en) begin
        bank_q[alloc_set][0] <= rob_way_write(alloc0_en,
          rob_payload_make(
            1'b0, alloc0_reg_write, alloc0_is_brnch,
            alloc0_is_brnch ? BR_MAP_I0 : brch_map,
            i0_alloc_rd_addr, i0_alloc_prd_tag, i0_alloc_prd_old, '0));
        bank_q[alloc_set][1] <= rob_way_write(alloc1_en,
          rob_payload_make(
            1'b0, alloc1_reg_write, alloc1_is_brnch,
            alloc1_is_brnch ? BR_MAP_I1 : brch_map,
            i1_alloc_rd_addr, i1_alloc_prd_tag, i1_alloc_prd_old, '0));
        write_ptr_q <= write_ptr_q + 2'd2;
      end
    end
  end

  // ---- negedge: dual commit ----
  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      commit_ptr_q <= '0;
      kill_mask_q  <= BR_MAP_NONE;
      retire_q     <= 1'b0;
      retire_set_q <= '0;
    end else begin
      retire_q     <= commit_pair;
      retire_set_q <= cmt_set;
      if (commit_pair) begin
        kill_mask_q  <= k1;
        commit_ptr_q <= commit_ptr_q + 2'd2;
      end
    end
  end

endmodule
