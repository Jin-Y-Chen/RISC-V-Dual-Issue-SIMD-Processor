`timescale 1ns / 1ps

// Selector unit — pick up to 2 oldest-ready instructions from:
//   (1) reservation-station bank ready entries
//   (2) bypass-unit candidates
// Outputs the dual-issue pair. Unselected bypass lanes are marked so the
// reservation station stores them; selected bank ways are marked for free.
import rv_dis_pkg::*;
import rs_pkg::*;

module selector_unit (
  input  logic               enable,
  input  logic               flush,

  input  rs_entry_t          bank_q [RS_SETS][RS_WAYS],
  input  rs_wb_pair_t        wb,
  input  rs_disp_pair_t      disp,

  input  logic               byp_ready [2],
  input  logic [31:0]        byp_age   [2],

  output rs_pick_t           pick,
  output logic               stall_dp,
  output rs_prf_rd_pair_t    prf,
  output rs_iss_pair_t       iss
);

  localparam int N_CAND = RS_WAYS + 2;

  rs_mask_t          bank_ready;
  logic [31:0]       bank_ages [RS_WAYS];
  rs_mask_t          bank_valid;

  logic [N_CAND-1:0] cand_full, cand_bank;
  logic [31:0]       age_full [N_CAND];
  logic [31:0]       age_bank [N_CAND];

  function automatic int pe_oldest(
    input logic [N_CAND-1:0] m,
    input logic [31:0]       ages [N_CAND]
  );
    logic        found;
    logic [31:0] best;
    found     = 1'b0;
    best      = '1;
    pe_oldest = 0;
    for (int i = 0; i < N_CAND; i++) begin
      if (m[i] && (!found || (ages[i] < best))) begin
        found     = 1'b1;
        best      = ages[i];
        pe_oldest = i;
      end
    end
  endfunction

  genvar w;
  generate
    for (w = 0; w < RS_WAYS; w++) begin : g_way
      assign bank_ready[w] = rs_calc_issue_ready(bank_q[0][w], wb);
      assign bank_ages[w]  = bank_q[0][w].age;
      assign bank_valid[w] = bank_q[0][w].valid;
    end
  endgenerate

  always_comb begin
    cand_full = '0;
    cand_bank = '0;
    for (int i = 0; i < RS_WAYS; i++) begin
      cand_full[i] = enable && !flush && bank_ready[i];
      cand_bank[i] = cand_full[i];
      age_full[i]  = bank_ages[i];
      age_bank[i]  = bank_ages[i];
    end
    cand_full[RS_WAYS]   = enable && !flush && byp_ready[0];
    cand_full[RS_WAYS+1] = enable && !flush && byp_ready[1];
    age_full[RS_WAYS]    = byp_age[0];
    age_full[RS_WAYS+1]  = byp_age[1];
    cand_bank[RS_WAYS]   = 1'b0;
    cand_bank[RS_WAYS+1] = 1'b0;
    age_bank[RS_WAYS]    = byp_age[0];
    age_bank[RS_WAYS+1]  = byp_age[1];
  end

  always_comb begin
    logic [N_CAND-1:0] m_use, m_rest;
    int                i0, i1;
    int                u, av, need;
    logic              b0, b1, ok;
    rs_pick_t          p;

    u = 0;
    for (int i = 0; i < RS_WAYS; i++)
      u += bank_valid[i];

    m_use = cand_full;
    p     = '0;
    if (|m_use) begin
      i0 = pe_oldest(m_use, age_full);
      p.sel0_v = 1'b1;
      if (i0 < RS_WAYS)
        p.sel0 = rs_way_t'(i0);
      else begin
        p.src0_disp = 1'b1;
        p.src0_d1   = (i0 == RS_WAYS + 1);
      end
      m_rest = m_use & ~({N_CAND{1'b0}} | ({{(N_CAND-1){1'b0}}, 1'b1} << i0));
      if (|m_rest) begin
        i1 = pe_oldest(m_rest, age_full);
        p.sel1_v = 1'b1;
        if (i1 < RS_WAYS)
          p.sel1 = rs_way_t'(i1);
        else begin
          p.src1_disp = 1'b1;
          p.src1_d1   = (i1 == RS_WAYS + 1);
        end
      end
    end
    p.fire0 = p.sel0_v;
    p.fire1 = p.sel1_v;
    b0 = (p.fire0 && p.src0_disp && !p.src0_d1) ||
         (p.fire1 && p.src1_disp && !p.src1_d1);
    b1 = (p.fire0 && p.src0_disp &&  p.src0_d1) ||
         (p.fire1 && p.src1_disp &&  p.src1_d1);
    p.bypass0 = b0;
    p.bypass1 = b1;

    av   = RS_WAYS - u
         + (p.fire0 && !p.src0_disp)
         + (p.fire1 && !p.src1_disp);
    need = (disp.i0.valid && !b0) + (disp.i1.valid && !b1);
    ok   = (need <= av);

    if (!ok) begin
      m_use = cand_bank;
      p     = '0;
      if (|m_use) begin
        i0 = pe_oldest(m_use, age_bank);
        p.sel0_v = 1'b1;
        p.sel0   = rs_way_t'(i0);
        m_rest = m_use & ~({N_CAND{1'b0}} | ({{(N_CAND-1){1'b0}}, 1'b1} << i0));
        if (|m_rest) begin
          i1 = pe_oldest(m_rest, age_bank);
          p.sel1_v = 1'b1;
          p.sel1   = rs_way_t'(i1);
        end
      end
      p.fire0 = p.sel0_v;
      p.fire1 = p.sel1_v;
      av   = RS_WAYS - u + p.fire0 + p.fire1;
      need = disp.i0.valid + disp.i1.valid;
    end

    pick     = p;
    stall_dp = !flush && (need > av);
  end

  rs_issue u_issue (
    .bank_q, .disp, .pick,
    .prf, .iss
  );

endmodule
