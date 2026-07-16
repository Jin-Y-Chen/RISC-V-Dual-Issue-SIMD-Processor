`timescale 1ns / 1ps

// Free List — bitmap + per-path ownership (dual-column RAT).
//   free_q[p]    — PRF p is available
//   own_br0_q[p] — speculative path 0 owns p (exclusive of own_br1)
//   own_br1_q[p] — speculative path 1 owns p (exclusive of own_br0)
// No FIFO / no checkpointed queue copies / no PRF recovery loops.
// Falling edge: Commit free → Kill path(s) → Rename allocate.
// Dual-path (!one_col && both columns live): each rename takes two PRFs,
// one owned by br0 and one by br1. One-col mirror uses one PRF (tip owns).
import rv_dis_pkg::*;
import rat_pkg::*;

module free_list (
  input  logic        clk,
  input  logic        rst_n,

  input  br_map_t     brch_map,
  input  logic        kill_br0,
  input  logic        kill_br1,

  input  logic        rename0_en,
  input  logic        rename1_en,
  // Per-path tags (equal when one-col / single-path).
  output prf_addr_t   i0_alloc_br0,
  output prf_addr_t   i0_alloc_br1,
  output prf_addr_t   i1_alloc_br0,
  output prf_addr_t   i1_alloc_br1,
  output logic        alloc0_valid,
  output logic        alloc1_valid,

  input  logic        free0_en,
  input  logic        free1_en,
  input  prf_addr_t   i0_free_tag,
  input  prf_addr_t   i1_free_tag
);

  logic [NUM_PRF-1:0] free_q;
  logic [NUM_PRF-1:0] own_br0_q;
  logic [NUM_PRF-1:0] own_br1_q;

  wire one_col   = rat_one_col(brch_map);
  wire use_br0   = rat_use_br0(brch_map);
  wire use_br1   = rat_use_br1(brch_map);
  wire tip_is_i1 = rat_tip_is_i1(brch_map);
  // True dual speculation: both columns live and are not a mirrored one-col tip.
  wire dual_path = use_br0 && use_br1 && !one_col;

  // -------------------------------------------------------------------------
  // Combinational free view (commit frees + kill reclaim), p0 masked
  // -------------------------------------------------------------------------
  wire [NUM_PRF-1:0] free_commit =
      ((free0_en && (i0_free_tag != '0)) ? (NUM_PRF'(1) << i0_free_tag) : '0)
    | ((free1_en && (i1_free_tag != '0)) ? (NUM_PRF'(1) << i1_free_tag) : '0);

  // Vector reclaim — no per-entry loops (req 2).
  wire [NUM_PRF-1:0] reclaim_br0  = kill_br0 ? (own_br0_q & ~own_br1_q) : '0;
  wire [NUM_PRF-1:0] reclaim_br1  = kill_br1 ? (own_br1_q & ~own_br0_q) : '0;
  wire [NUM_PRF-1:0] reclaim_both = (kill_br0 && kill_br1)
                                  ? (own_br0_q & own_br1_q) : '0;
  wire [NUM_PRF-1:0] reclaim      = reclaim_br0 | reclaim_br1 | reclaim_both;

  wire [NUM_PRF-1:0] free_vis = (free_q | free_commit | reclaim) & ~NUM_PRF'(1);

  function automatic prf_addr_t find_first(input logic [NUM_PRF-1:0] bits);
    find_first = '0;
    for (int unsigned k = 1; k < NUM_PRF; k++) begin
      if (bits[k]) begin
        find_first = prf_addr_t'(k);
        return;
      end
    end
  endfunction

  // Peel successive free tags for up to 4 allocations (2 lanes × dual-path).
  wire prf_addr_t t0 = find_first(free_vis);
  wire prf_addr_t t1 = find_first(free_vis & ~(NUM_PRF'(1) << t0));
  wire prf_addr_t t2 = find_first(free_vis & ~(NUM_PRF'(1) << t0)
                                           & ~(NUM_PRF'(1) << t1));
  wire prf_addr_t t3 = find_first(free_vis & ~(NUM_PRF'(1) << t0)
                                           & ~(NUM_PRF'(1) << t1)
                                           & ~(NUM_PRF'(1) << t2));

  // Lane0 always takes the first per_lane tag(s); lane1 takes the next.
  wire prf_addr_t i0_a = t0;
  wire prf_addr_t i0_b = dual_path ? t1 : t0;
  wire prf_addr_t i1_a = dual_path ? t2 : (rename0_en ? t1 : t0);
  wire prf_addr_t i1_b = dual_path ? t3 : i1_a;

  // Map peeled tags onto path ports.
  // dual_path: independent tags. one-col / single-path: one tag (mirrored on both ports
  // when one-col so RAT columns stay in sync; ownership is tip-only).
  assign i0_alloc_br0 = dual_path ? i0_a : ((use_br0 || one_col) ? i0_a : '0);
  assign i0_alloc_br1 = dual_path ? i0_b : ((use_br1 || one_col) ? i0_a : '0);
  assign i1_alloc_br0 = dual_path ? i1_a : ((use_br0 || one_col) ? i1_a : '0);
  assign i1_alloc_br1 = dual_path ? i1_b : ((use_br1 || one_col) ? i1_a : '0);

  // Enough free tags for lane0 alone / lane0+lane1.
  assign alloc0_valid = dual_path ? (t0 != '0 && t1 != '0) : (t0 != '0);
  assign alloc1_valid = dual_path ? (t0 != '0 && t1 != '0 && t2 != '0 && t3 != '0)
                                  : (t0 != '0 && t1 != '0);

  // -------------------------------------------------------------------------
  // Falling-edge update — commit → kill → rename (req 4)
  // -------------------------------------------------------------------------
  always_ff @(negedge clk or negedge rst_n) begin
    logic [NUM_PRF-1:0] free_n, own0_n, own1_n;

    if (!rst_n) begin
      free_q    <= {{(NUM_PRF-NUM_GPR){1'b1}}, {NUM_GPR{1'b0}}}; // p32..p63
      own_br0_q <= '0;
      own_br1_q <= '0;
    end else begin
      free_n = free_q;
      own0_n = own_br0_q;
      own1_n = own_br1_q;

      // a) Commit — return old PRFs, clear ownership
      if (free0_en && (i0_free_tag != '0)) begin
        free_n[i0_free_tag] = 1'b1;
        own0_n[i0_free_tag] = 1'b0;
        own1_n[i0_free_tag] = 1'b0;
      end
      if (free1_en && (i1_free_tag != '0)) begin
        free_n[i1_free_tag] = 1'b1;
        own0_n[i1_free_tag] = 1'b0;
        own1_n[i1_free_tag] = 1'b0;
      end

      // b) Branch resolution — vector reclaim, clear killed ownership
      free_n |= (kill_br0 ? (own0_n & ~own1_n) : '0)
              | (kill_br1 ? (own1_n & ~own0_n) : '0)
              | ((kill_br0 && kill_br1) ? (own0_n & own1_n) : '0);
      if (kill_br0) own0_n = '0;
      if (kill_br1) own1_n = '0;

      // c) Rename — exclusive ownership per path (req 5)
      if (rename0_en && alloc0_valid) begin
        if (dual_path) begin
          free_n[i0_a] = 1'b0;
          free_n[i0_b] = 1'b0;
          own0_n[i0_a] = 1'b1;  // br0 only
          own1_n[i0_b] = 1'b1;  // br1 only
        end else begin
          free_n[i0_a] = 1'b0;
          // Exactly one owner: live path, or tip when one-col mirror.
          if (use_br0 && !use_br1)       own0_n[i0_a] = 1'b1;
          else if (use_br1 && !use_br0)  own1_n[i0_a] = 1'b1;
          else if (tip_is_i1)            own1_n[i0_a] = 1'b1;
          else                           own0_n[i0_a] = 1'b1;
        end
      end
      if (rename1_en && (rename0_en ? alloc1_valid : alloc0_valid)) begin
        if (dual_path) begin
          free_n[i1_a] = 1'b0;
          free_n[i1_b] = 1'b0;
          own0_n[i1_a] = 1'b1;
          own1_n[i1_b] = 1'b1;
        end else begin
          free_n[i1_a] = 1'b0;
          if (use_br0 && !use_br1)       own0_n[i1_a] = 1'b1;
          else if (use_br1 && !use_br0)  own1_n[i1_a] = 1'b1;
          else if (tip_is_i1)            own1_n[i1_a] = 1'b1;
          else                           own0_n[i1_a] = 1'b1;
        end
      end

      free_q    <= free_n;
      own_br0_q <= own0_n;
      own_br1_q <= own1_n;
    end
  end

endmodule
