`timescale 1ns / 1ps

// Golden model for rtl/s3_rename/core_mod/reorder_buffer.sv
// Flat circular LUT (index 0..31) — independent of DUT set/way banking.
// Combo: retire eligibility / commit / alloc indices.
// Negedge: WB control, commit reclaim, rename alloc (matches DUT).
import rv_dis_pkg::*;
import rob_pkg::*;

module reorder_buffer_gm (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

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

  input  logic        wback0_en,
  input  logic        wback1_en,
  input  prf_addr_t   i0_rob_idx_wb,
  input  prf_addr_t   i1_rob_idx_wb,
  input  logic        i0_brch_taken_wb,
  input  logic        i1_brch_taken_wb,

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

  // ---- flat LUT (one row per ROB flat index) ----
  rob_payload_t entry_q [ROB_DEPTH];
  logic         valid_q [ROB_DEPTH];

  rob_ptr_t head_q, head_n, tail_q, tail_n;
  logic     active_spec_q, active_spec_n;

  rob_ptr_t   occ;
  logic [1:0] n_alloc;
  rob_flat_t  alloc_base, a0_flat, a1_flat;
  rob_flat_t  h0, h1;
  rob_flat_t  wb0_flat, wb1_flat;

  rob_payload_t p0_bank, p1_bank, p0, p1;
  logic         v0, v1;
  logic         wb0_hit, wb1_hit;
  logic         wb0_to_h0, wb0_to_h1, wb1_to_h0, wb1_to_h1;

  logic on_path0, on_path1;
  logic ready0, ready1;
  logic br0_ready, br1_ready;
  logic spec_after0, spec_after1;
  logic cmt0, cmt1;

  assign occ     = tail_q - head_q;
  assign stall   = (occ > rob_ptr_t'(ROB_DEPTH - 2));
  assign n_alloc = {1'b0, alloc0_en} + {1'b0, alloc1_en};

  assign alloc_base = tail_q[ROB_INDEX_W-1:0];
  assign a0_flat    = alloc_base;
  assign a1_flat    = rob_flat_t'(alloc_base + (alloc0_en ? 1'b1 : 1'b0));
  assign i0_rob_idx = rob_to_prf(a0_flat);
  assign i1_rob_idx = rob_to_prf(a1_flat);

  assign h0 = head_q[ROB_INDEX_W-1:0];
  assign h1 = rob_flat_t'(h0 + 1'b1);

  assign wb0_flat = rob_flat(i0_rob_idx_wb);
  assign wb1_flat = rob_flat(i1_rob_idx_wb);

  assign wb0_hit = wback0_en && valid_q[wb0_flat];
  assign wb1_hit = wback1_en && valid_q[wb1_flat];

  assign wb0_to_h0 = wb0_hit && (wb0_flat == h0);
  assign wb0_to_h1 = wb0_hit && (wb0_flat == h1);
  assign wb1_to_h0 = wb1_hit && (wb1_flat == h0);
  assign wb1_to_h1 = wb1_hit && (wb1_flat == h1);

  assign v0      = valid_q[h0];
  assign v1      = valid_q[h1];
  assign p0_bank = entry_q[h0];
  assign p1_bank = entry_q[h1];

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

  assign on_path0    = !v0 || rob_on_path(p0.spec_en, active_spec_q);
  assign ready0      = (occ >= rob_ptr_t'(1)) && (!v0 || p0.complete);
  assign br0_ready   = ready0 && v0 && on_path0 && p0.is_branch;
  assign spec_after0 = br0_ready ? p0.br_taken : active_spec_q;

  assign on_path1    = !v1 || rob_on_path(p1.spec_en, spec_after0);
  assign ready1      = ready0 && (occ >= rob_ptr_t'(2)) && (!v1 || p1.complete);
  assign br1_ready   = ready1 && v1 && on_path1 && p1.is_branch;
  assign spec_after1 = br1_ready ? p1.br_taken : spec_after0;

  assign i0_can_retire = ready0;
  assign i1_can_retire = ready1;

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
      default: ;
    endcase

    if (n_alloc != 2'b00)
      tail_n = tail_q + rob_ptr_t'(n_alloc);
  end

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      head_q        <= '0;
      tail_q        <= '0;
      active_spec_q <= 1'b0;
      for (int i = 0; i < ROB_DEPTH; i++) begin
        valid_q[i] <= 1'b0;
        entry_q[i] <= '0;
      end
    end else begin
      if (wb0_hit)
        entry_q[wb0_flat] <= rob_wback(entry_q[wb0_flat], i0_brch_taken_wb);
      if (wb1_hit)
        entry_q[wb1_flat] <= rob_wback(entry_q[wb1_flat], i1_brch_taken_wb);

      if (cmt0)
        valid_q[h0] <= 1'b0;
      if (cmt1)
        valid_q[h1] <= 1'b0;

      if (alloc0_en) begin
        entry_q[a0_flat] <= rob_entry(
            i0_reg_write, i0_is_brnch, i0_is_store, i0_spec_en, i0_rd_addr);
        valid_q[a0_flat] <= 1'b1;
      end
      if (alloc1_en) begin
        entry_q[a1_flat] <= rob_entry(
            i1_reg_write, i1_is_brnch, i1_is_store, i1_spec_en, i1_rd_addr);
        valid_q[a1_flat] <= 1'b1;
      end

      head_q        <= head_n;
      tail_q        <= tail_n;
      active_spec_q <= active_spec_n;
    end
  end

endmodule
