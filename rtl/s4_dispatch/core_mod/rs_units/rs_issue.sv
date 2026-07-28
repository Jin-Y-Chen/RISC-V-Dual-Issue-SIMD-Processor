`timescale 1ns / 1ps

// RS issue — single-cycle wakeup / select with dispatch bypass.
// Candidates: woken bank entries + ready dispatch (PRF ready + WB).
// Oldest-first; dispatch is youngest. Bypassed disp skips RS allocate.
import rv_dis_pkg::*;
import rs_pkg::*;

module rs_issue (
  input  logic               enable,
  input  logic               flush,

  input  rs_entry_t          bank_q [RS_SETS][RS_WAYS],
  input  logic [31:0]        age_q,
  input  rs_wb_pair_t        wb,
  input  rs_disp_pair_t      disp,
  input  logic               issue_en,

  output rs_pick_t           pick,
  output logic               stall_dp,
  output rs_prf_rd_pair_t    prf,
  output rs_iss_pair_t       iss
);

  localparam int N_CAND = RS_WAYS + 2;

  logic               d0_rdy, d1_rdy;

  rs_mask_t           bank_ready;
  logic [31:0]        bank_ages [RS_WAYS];
  rs_mask_t           bank_valid;

  logic [N_CAND-1:0]  cand_full, cand_bank;
  logic [31:0]        age_full [N_CAND];
  logic [31:0]        age_bank [N_CAND];

  rs_entry_t          e0, e1;
  rs_disp_insn_t      dd0, dd1;

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

  assign d0_rdy = rs_disp_ready(disp.i0, wb);
  assign d1_rdy = rs_disp_ready(disp.i1, wb);

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
    cand_full[RS_WAYS]       = enable && !flush && issue_en && d0_rdy;
    cand_full[RS_WAYS+1]     = enable && !flush && issue_en && d1_rdy;
    age_full[RS_WAYS]        = age_q;
    age_full[RS_WAYS+1]      = age_q + 32'd1;
    cand_bank[RS_WAYS]       = 1'b0;
    cand_bank[RS_WAYS+1]     = 1'b0;
    age_bank[RS_WAYS]        = age_q;
    age_bank[RS_WAYS+1]      = age_q + 32'd1;
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

    // Tentative: bank + dispatch bypass candidates
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
    p.fire0 = p.sel0_v && issue_en;
    p.fire1 = p.sel1_v && issue_en;
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
      // Cannot place remaining disp → bank-only select; pair must allocate
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
      p.fire0 = p.sel0_v && issue_en;
      p.fire1 = p.sel1_v && issue_en;
      av   = RS_WAYS - u + p.fire0 + p.fire1;
      need = disp.i0.valid + disp.i1.valid;
    end

    pick     = p;
    stall_dp = !flush && (need > av);
  end

  always_comb begin
    iss = '0;
    prf = '0;
    e0  = bank_q[0][pick.sel0];
    e1  = bank_q[0][pick.sel1];
    dd0 = pick.src0_d1 ? disp.i1 : disp.i0;
    dd1 = pick.src1_d1 ? disp.i1 : disp.i0;

    if (pick.sel0_v) begin
      if (pick.src0_disp) begin
        iss.i0.valid     = 1'b1;
        iss.i0.lane_sel  = dd0.lane_sel;
        iss.i0.reg_write = dd0.reg_write;
        iss.i0.opcode    = dd0.opcode;
        iss.i0.funct3    = dd0.funct3;
        iss.i0.funct7    = dd0.funct7;
        iss.i0.ps1       = dd0.ps1;
        iss.i0.ps2       = dd0.ps2;
        iss.i0.prd       = dd0.prd;
        iss.i0.imm       = dd0.imm;
        iss.i0.pc        = dd0.pc;
        prf.i0.ps1       = dd0.ps1;
        prf.i0.ps2       = dd0.ps2;
      end else begin
        iss.i0.valid     = 1'b1;
        iss.i0.lane_sel  = e0.lane_sel;
        iss.i0.reg_write = e0.reg_write;
        iss.i0.opcode    = e0.opcode;
        iss.i0.funct3    = e0.funct3;
        iss.i0.funct7    = e0.funct7;
        iss.i0.ps1       = e0.ps1;
        iss.i0.ps2       = e0.ps2;
        iss.i0.prd       = e0.prd;
        iss.i0.imm       = e0.imm;
        iss.i0.pc        = e0.pc;
        prf.i0.ps1       = e0.ps1;
        prf.i0.ps2       = e0.ps2;
      end
    end

    if (pick.sel1_v) begin
      if (pick.src1_disp) begin
        iss.i1.valid     = 1'b1;
        iss.i1.lane_sel  = dd1.lane_sel;
        iss.i1.reg_write = dd1.reg_write;
        iss.i1.opcode    = dd1.opcode;
        iss.i1.funct3    = dd1.funct3;
        iss.i1.funct7    = dd1.funct7;
        iss.i1.ps1       = dd1.ps1;
        iss.i1.ps2       = dd1.ps2;
        iss.i1.prd       = dd1.prd;
        iss.i1.imm       = dd1.imm;
        iss.i1.pc        = dd1.pc;
        prf.i1.ps1       = dd1.ps1;
        prf.i1.ps2       = dd1.ps2;
      end else begin
        iss.i1.valid     = 1'b1;
        iss.i1.lane_sel  = e1.lane_sel;
        iss.i1.reg_write = e1.reg_write;
        iss.i1.opcode    = e1.opcode;
        iss.i1.funct3    = e1.funct3;
        iss.i1.funct7    = e1.funct7;
        iss.i1.ps1       = e1.ps1;
        iss.i1.ps2       = e1.ps2;
        iss.i1.prd       = e1.prd;
        iss.i1.imm       = e1.imm;
        iss.i1.pc        = e1.pc;
        prf.i1.ps1       = e1.ps1;
        prf.i1.ps2       = e1.ps2;
      end
    end
  end

endmodule
