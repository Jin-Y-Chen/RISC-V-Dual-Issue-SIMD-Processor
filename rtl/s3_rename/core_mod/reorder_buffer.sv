`timescale 1ns / 1ps

// Reorder Buffer — cache-style bank (1-set × ROB_WAYS).
// bank[way] = {valid, payload}; tag[way] = architectural rd for CAM lookup.
// Dual-issue: every fire allocates exactly two ways (I0 then I1); bubbles use valid=0.
import rv_dis_pkg::*;
import rob_pkg::*;

module reorder_buffer (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls
  input  logic        flush,

  // --- allocate (rename / tail) — always two slots ---
  input  logic        alloc_en,           // fire: reserve I0+I1 ways
  input  logic        alloc0_valid,       // lane has a real insn (else bubble)
  input  logic        alloc1_valid,
  input  logic        alloc0_reg_write,
  input  logic        alloc1_reg_write,
  input  gpr_addr_t   alloc0_rd_addr,
  input  gpr_addr_t   alloc1_rd_addr,
  input  prf_addr_t   alloc0_prd,
  input  prf_addr_t   alloc1_prd,
  input  prf_addr_t   alloc0_prd_old,
  input  prf_addr_t   alloc1_prd_old,
  input  ID_packet_t  alloc0_meta,
  input  ID_packet_t  alloc1_meta,
  output logic [ROB_AW-1:0] alloc0_idx,
  output logic [ROB_AW-1:0] alloc1_idx,
  output logic        alloc_ready,        // free_slots >= 2

  // --- complete (writeback by way index) ---
  input  logic        complete0_en,
  input  logic        complete1_en,
  input  logic [ROB_AW-1:0] complete0_idx,
  input  logic [ROB_AW-1:0] complete1_idx,
  input  word_t       complete0_result,
  input  word_t       complete1_result,

  // --- commit (head retire → Free List reclaim) ---
  output logic        commit0_en,
  output logic        commit1_en,
  output logic        commit0_reg_write,
  output logic        commit1_reg_write,
  output gpr_addr_t   commit0_rd_addr,
  output gpr_addr_t   commit1_rd_addr,
  output prf_addr_t   commit0_prd,
  output prf_addr_t   commit1_prd,
  output prf_addr_t   commit0_prd_old,
  output prf_addr_t   commit1_prd_old,
  output word_t       commit0_result,
  output word_t       commit1_result,

  // exported pointers / bank (TB / rename search)
  output rob_ptr_t    write_ptr,
  output rob_ptr_t    commit_ptr,
  output rob_line_t   bank [ROB_WAYS],
  output gpr_addr_t   tag  [ROB_WAYS]
);

  rob_line_t bank_q [ROB_WAYS];
  gpr_addr_t tag_q  [ROB_WAYS];
  rob_ptr_t  write_ptr_q;
  rob_ptr_t  commit_ptr_q;

  assign write_ptr  = write_ptr_q;
  assign commit_ptr = commit_ptr_q;
  assign bank       = bank_q;
  assign tag        = tag_q;

  wire rob_ptr_t occ        = write_ptr_q - commit_ptr_q;
  wire rob_ptr_t free_slots = rob_ptr_t'(ROB_DEPTH) - occ;

  // Dual-issue: always need / take two ROB ways.
  assign alloc_ready = (free_slots >= rob_ptr_t'(2));
  assign alloc0_idx  = write_ptr_q[ROB_AW-1:0];
  assign alloc1_idx  = write_ptr_q[ROB_AW-1:0] + 1'b1;

  // -------------------------------------------------------------------------
  // Indexed cache lookup — commit head ways
  // -------------------------------------------------------------------------
  wire [ROB_AW-1:0] cmt_way0 = commit_ptr_q[ROB_AW-1:0];
  wire [ROB_AW-1:0] cmt_way1 = commit_ptr_q[ROB_AW-1:0] + 1'b1;

  rob_payload_t cmt_pay0;
  rob_payload_t cmt_pay1;
  assign cmt_pay0 = rob_cache_payload_read(bank_q[cmt_way0], '0);
  assign cmt_pay1 = rob_cache_payload_read(bank_q[cmt_way1], '0);

  wire cmt_v0 = rob_cache_valid(bank_q[cmt_way0]);
  wire cmt_v1 = rob_cache_valid(bank_q[cmt_way1]);

  // Head is in the live window; invalid bank line = allocated bubble → retire immediately.
  wire head_live0 = (occ != '0);
  wire head_live1 = (occ >= rob_ptr_t'(2));
  wire can_cmt0   = head_live0 && (!cmt_v0 || cmt_pay0.complete);
  wire can_cmt1   = can_cmt0 && head_live1 && (!cmt_v1 || cmt_pay1.complete);

  assign commit0_en        = can_cmt0;
  assign commit1_en        = can_cmt1;
  assign commit0_reg_write = cmt_pay0.reg_write;
  assign commit1_reg_write = cmt_pay1.reg_write;
  assign commit0_rd_addr   = cmt_pay0.rd;
  assign commit1_rd_addr   = cmt_pay1.rd;
  assign commit0_prd       = cmt_pay0.prd;
  assign commit1_prd       = cmt_pay1.prd;
  assign commit0_prd_old   = cmt_pay0.prd_old;
  assign commit1_prd_old   = cmt_pay1.prd_old;
  assign commit0_result    = cmt_pay0.result;
  assign commit1_result    = cmt_pay1.result;

  // -------------------------------------------------------------------------
  // Sequential bank update — allocate / complete / clear (invalidate)
  // -------------------------------------------------------------------------
  integer w;
  always_ff @(posedge clk or negedge rst_n) begin
    rob_payload_t pay;
    rob_line_t    line;

    if (!rst_n || flush) begin
      write_ptr_q  <= '0;
      commit_ptr_q <= '0;
      for (w = 0; w < ROB_WAYS; w++) begin
        bank_q[w] <= '0;
        tag_q[w]  <= '0;
      end
    end else if (enable) begin
      // Complete by indexed way lookup (cache update-in-place).
      if (complete0_en) begin
        line = bank_q[complete0_idx];
        if (rob_cache_valid(line)) begin
          pay          = rob_cache_payload(line);
          pay.complete = 1'b1;
          pay.result   = complete0_result;
          bank_q[complete0_idx] <= rob_cache_pack(1'b1, pay);
        end
      end
      if (complete1_en) begin
        line = bank_q[complete1_idx];
        if (rob_cache_valid(line)) begin
          pay          = rob_cache_payload(line);
          pay.complete = 1'b1;
          pay.result   = complete1_result;
          bank_q[complete1_idx] <= rob_cache_pack(1'b1, pay);
        end
      end

      // Allocate both ways every fire; unused lane is an invalid bubble.
      if (alloc_en) begin
        bank_q[alloc0_idx] <= rob_cache_pack(
          alloc0_valid,
          rob_payload_make(
            1'b0, alloc0_reg_write, alloc0_rd_addr,
            alloc0_prd, alloc0_prd_old, alloc0_meta, '0
          )
        );
        tag_q[alloc0_idx] <= alloc0_rd_addr;

        bank_q[alloc1_idx] <= rob_cache_pack(
          alloc1_valid,
          rob_payload_make(
            1'b0, alloc1_reg_write, alloc1_rd_addr,
            alloc1_prd, alloc1_prd_old, alloc1_meta, '0
          )
        );
        tag_q[alloc1_idx] <= alloc1_rd_addr;

        write_ptr_q <= write_ptr_q + rob_ptr_t'(2);
      end

      // Commit: invalidate head ways (cache clear).
      // Prefer dual commit of allocated pairs when both head entries ready.
      if (can_cmt0) begin
        bank_q[cmt_way0] <= '0;
        tag_q[cmt_way0]  <= '0;
        if (can_cmt1) begin
          bank_q[cmt_way1] <= '0;
          tag_q[cmt_way1]  <= '0;
          commit_ptr_q <= commit_ptr_q + 2'd2;
        end else begin
          commit_ptr_q <= commit_ptr_q + 2'd1;
        end
      end
    end
  end

endmodule
