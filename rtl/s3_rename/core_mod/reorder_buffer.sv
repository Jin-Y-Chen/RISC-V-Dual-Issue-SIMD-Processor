`timescale 1ns / 1ps

// ROB — 32-entry circular queue, banked rob[16][2] (one storage bank).
//
// Head (retire) and tail (alloc) are independent: new entries start incomplete,
// so both are computed from the current registered state (no posedge stage).
//
//   Combo   — retire eligibility / commit + rename indices / next pointers
//   Negedge — WB complete/br_taken, then commit reclaim + rename alloc
//
// WB may bypass into the head read so complete is visible the same half-cycle
// it is presented on the writeback ports (before the negedge latch).
import rv_dis_pkg::*;
import rob_pkg::*;

module reorder_buffer (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  // (2) alloc at tail — rename (one or two instructions)
  input  logic        alloc0_en,
  input  logic        alloc1_en,
  input  logic        i0_reg_write,
  input  logic        i1_reg_write,
  input  logic        i0_is_brnch,
  input  logic        i1_is_brnch,
  input  logic        i0_is_store,
  input  logic        i1_is_store,
  input  logic        i0_spec_en,
  input  logic        i1_spec_en,
  input  gpr_addr_t   i0_rd_addr,
  input  gpr_addr_t   i1_rd_addr,
  output prf_addr_t   i0_rob_idx,
  output prf_addr_t   i1_rob_idx,
  output logic        stall,

  // (3) writeback — retirement control only
  input  logic        wback0_en,
  input  logic        wback1_en,
  input  prf_addr_t   i0_rob_idx_wb,
  input  prf_addr_t   i1_rob_idx_wb,
  input  logic        i0_brch_taken_wb,
  input  logic        i1_brch_taken_wb,

  // (1) retire handshake + commit buses
  input  logic        retire0_en,
  input  logic        retire1_en,
  output logic        i0_can_retire,
  output logic        i1_can_retire,

  output logic        rrat0_en,
  output logic        rrat1_en,
  output gpr_addr_t   i0_rd_addr_cmt,
  output gpr_addr_t   i1_rd_addr_cmt,
  output prf_addr_t   i0_rob_idx_cmt,
  output prf_addr_t   i1_rob_idx_cmt,

  output logic        rat0_en,
  output logic        rat1_en,
  output logic        i0_path_sel,
  output logic        i1_path_sel,

  output logic        stb0_en,
  output logic        stb1_en
);

  // ---- one storage bank (updated only on negedge) ----
  rob_payload_t rob_q [ROB_SETS][ROB_WAYS];
  logic [ROB_SETS-1:0][ROB_WAYS-1:0] valid_q;

  rob_ptr_t head_q, head_n, tail_q, tail_n;
  logic     active_spec_q, active_spec_n;

  rob_ptr_t  occ;
  logic [1:0] n_alloc;
  rob_flat_t alloc_base, a0_flat, a1_flat;
  rob_set_t  a0_row, a1_row;
  rob_way_t  a0_col, a1_col;

  rob_flat_t h0, h1;
  rob_set_t  h0_row, h1_row;
  rob_way_t  h0_col, h1_col;

  rob_set_t  wb0_row, wb1_row;
  rob_way_t  wb0_col, wb1_col;
  logic      wb0_hit, wb1_hit;
  logic      wb0_to_h0, wb0_to_h1, wb1_to_h0, wb1_to_h1;

  rob_payload_t p0_bank, p1_bank, p0, p1;
  logic         v0, v1;

  logic on_path0, on_path1;
  logic ready0, ready1;
  logic br0_ready, br1_ready;
  logic spec_after0, spec_after1;
  logic cmt0, cmt1;

  // ---- occupancy / rename indices from registered tail ----
  assign occ     = tail_q - head_q;
  assign stall   = (occ > rob_ptr_t'(ROB_DEPTH - 2));
  assign n_alloc = {1'b0, alloc0_en} + {1'b0, alloc1_en};

  // Pack allocates contiguously at tail (single or dual)
  assign alloc_base = tail_q[ROB_INDEX_W-1:0];
  assign a0_flat    = alloc_base;
  assign a1_flat    = rob_flat_t'(alloc_base + (alloc0_en ? 1'b1 : 1'b0));
  assign i0_rob_idx = rob_to_prf(a0_flat);
  assign i1_rob_idx = rob_to_prf(a1_flat);
  assign a0_row     = rob_row(a0_flat);
  assign a0_col     = rob_col(a0_flat);
  assign a1_row     = rob_row(a1_flat);
  assign a1_col     = rob_col(a1_flat);

  assign h0     = head_q[ROB_INDEX_W-1:0];
  assign h1     = rob_flat_t'(h0 + 1'b1);
  assign h0_row = rob_row(h0);
  assign h1_row = rob_row(h1);
  assign h0_col = rob_col(h0);
  assign h1_col = rob_col(h1);

  assign wb0_row = rob_set(i0_rob_idx_wb);
  assign wb0_col = rob_way(i0_rob_idx_wb);
  assign wb1_row = rob_set(i1_rob_idx_wb);
  assign wb1_col = rob_way(i1_rob_idx_wb);

  assign wb0_hit = wback0_en && valid_q[wb0_row][wb0_col];
  assign wb1_hit = wback1_en && valid_q[wb1_row][wb1_col];

  assign wb0_to_h0 = wb0_hit && (wb0_row == h0_row) && (wb0_col == h0_col);
  assign wb0_to_h1 = wb0_hit && (wb0_row == h1_row) && (wb0_col == h1_col);
  assign wb1_to_h0 = wb1_hit && (wb1_row == h0_row) && (wb1_col == h0_col);
  assign wb1_to_h1 = wb1_hit && (wb1_row == h1_row) && (wb1_col == h1_col);

  // =========================================================================
  // Combinational — retire/commit + next pointers (no storage shadow)
  // =========================================================================
  assign v0      = valid_q[h0_row][h0_col];
  assign v1      = valid_q[h1_row][h1_col];
  assign p0_bank = rob_q[h0_row][h0_col];
  assign p1_bank = rob_q[h1_row][h1_col];

  always_comb begin
    if (!v0)
      p0 = '0;
    else if (wb0_to_h0)
      p0 = rob_wback(p0_bank, i0_brch_taken_wb);
    else if (wb1_to_h0)
      p0 = rob_wback(p0_bank, i1_brch_taken_wb);
    else
      p0 = p0_bank;

    if (!v1)
      p1 = '0;
    else if (wb0_to_h1)
      p1 = rob_wback(p1_bank, i0_brch_taken_wb);
    else if (wb1_to_h1)
      p1 = rob_wback(p1_bank, i1_brch_taken_wb);
    else
      p1 = p1_bank;
  end

  assign on_path0 = !v0 || rob_on_path(p0.spec_en, active_spec_q);
  assign ready0   = (occ >= rob_ptr_t'(1)) && (!v0 || p0.complete);
  assign br0_ready   = ready0 && v0 && on_path0 && p0.is_branch;
  assign spec_after0 = br0_ready ? p0.br_taken : active_spec_q;

  assign on_path1 = !v1 || rob_on_path(p1.spec_en, spec_after0);
  assign ready1   = ready0 && (occ >= rob_ptr_t'(2)) && (!v1 || p1.complete);
  assign br1_ready   = ready1 && v1 && on_path1 && p1.is_branch;
  assign spec_after1 = br1_ready ? p1.br_taken : spec_after0;

  assign i0_can_retire = ready0;
  assign i1_can_retire = ready1;

  // True commits only (valid + on-path); drives reclaim / head advance
  assign cmt0 = retire0_en && v0 && on_path0;
  assign cmt1 = retire1_en && v1 && on_path1;

  assign rrat0_en       = cmt0 && p0.reg_write;
  assign rrat1_en       = cmt1 && p1.reg_write;
  assign i0_rd_addr_cmt = p0.rd;
  assign i1_rd_addr_cmt = p1.rd;
  assign i0_rob_idx_cmt = rob_to_prf(h0);
  assign i1_rob_idx_cmt = rob_to_prf(h1);

  assign stb0_en = cmt0 && p0.is_store;
  assign stb1_en = cmt1 && p1.is_store;

  assign rat0_en     = cmt0 && p0.is_branch;
  assign rat1_en     = cmt1 && p1.is_branch;
  assign i0_path_sel = p0.br_taken;
  assign i1_path_sel = p1.br_taken;

  // Next pointers: commit at head, packed alloc at tail
  always_comb begin
    head_n        = head_q;
    tail_n        = tail_q;
    active_spec_n = active_spec_q;

    unique case ({cmt1, cmt0})
      2'b11: begin
        active_spec_n = spec_after1;
        head_n        = head_q + 2'd2;
      end
      2'b01: begin
        active_spec_n = spec_after0;
        head_n        = head_q + 1'b1;
      end
      default: ; // 2'b10: in-order commit never fires i1 without i0
    endcase

    if (n_alloc != 2'b00)
      tail_n = tail_q + rob_ptr_t'(n_alloc);
  end

  // =========================================================================
  // Negedge storage — WB, then commit reclaim + rename alloc
  // =========================================================================
  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      head_q        <= '0;
      tail_q        <= '0;
      valid_q       <= '0;
      active_spec_q <= 1'b0;
    end else begin
      // writeback first — retirement control only
      if (wb0_hit)
        rob_q[wb0_row][wb0_col] <=
            rob_wback(rob_q[wb0_row][wb0_col], i0_brch_taken_wb);
      if (wb1_hit)
        rob_q[wb1_row][wb1_col] <=
            rob_wback(rob_q[wb1_row][wb1_col], i1_brch_taken_wb);

      // commit reclaim (alloc may reuse the same slot on wrap)
      if (cmt0)
        valid_q[h0_row][h0_col] <= 1'b0;
      if (cmt1)
        valid_q[h1_row][h1_col] <= 1'b0;

      // packed rename alloc — only enabled lanes
      if (alloc0_en) begin
        rob_q[a0_row][a0_col]   <= rob_entry(
            i0_reg_write, i0_is_brnch, i0_is_store, i0_spec_en, i0_rd_addr);
        valid_q[a0_row][a0_col] <= 1'b1;
      end
      if (alloc1_en) begin
        rob_q[a1_row][a1_col]   <= rob_entry(
            i1_reg_write, i1_is_brnch, i1_is_store, i1_spec_en, i1_rd_addr);
        valid_q[a1_row][a1_col] <= 1'b1;
      end

      head_q        <= head_n;
      tail_q        <= tail_n;
      active_spec_q <= active_spec_n;
    end
  end

endmodule
