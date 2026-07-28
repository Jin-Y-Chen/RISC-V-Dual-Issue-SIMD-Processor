`timescale 1ns / 1ps

// RS alloc / wakeup — bank wakeup, free issued bank ways, allocate non-bypass.
// Bypassed dispatch (pick.bypass*) is not written into the bank.
import rv_dis_pkg::*;
import rs_pkg::*;

module rs_alloc (
  input  logic               enable,
  input  logic               flush,
  input  logic               stall_dp,

  input  rs_entry_t          bank_q [RS_SETS][RS_WAYS],
  input  logic [NUM_PRF-1:0] prf_ready_q,
  input  logic [31:0]        age_q,

  input  rs_wb_pair_t        wb,
  input  rs_pick_t           pick,
  input  rs_disp_pair_t      disp,

  output rs_entry_t          bank_n [RS_SETS][RS_WAYS],
  output logic [NUM_PRF-1:0] prf_ready_n,
  output logic [31:0]        age_n
);

  rs_entry_t way_n [RS_WAYS];
  rs_mask_t  valid_after;
  rs_mask_t  free_m;
  rs_way_t   free0, free1, slot;
  logic      ins0, ins1;

  // Existing-entry wakeup from WB broadcast.
  genvar w;
  generate
    for (w = 0; w < RS_WAYS; w++) begin : g_wake
      always_comb begin
        way_n[w] = bank_q[0][w];
        if (way_n[w].valid) begin
          if (!way_n[w].rs1_ready && rs_wb_hit(way_n[w].ps1, wb))
            way_n[w].rs1_ready = 1'b1;
          if (!way_n[w].rs2_ready && rs_wb_hit(way_n[w].ps2, wb))
            way_n[w].rs2_ready = 1'b1;
        end
      end
    end
  endgenerate

  assign ins0 = disp.i0.valid && !pick.bypass0;
  assign ins1 = disp.i1.valid && !pick.bypass1;

  always_comb begin
    bank_n      = '{default: '0};
    prf_ready_n = prf_ready_q;
    age_n       = age_q;

    for (int i = 0; i < RS_WAYS; i++)
      bank_n[0][i] = way_n[i];

    if (wb.wb0.en) prf_ready_n[wb.wb0.prd] = 1'b1;
    if (wb.wb1.en) prf_ready_n[wb.wb1.prd] = 1'b1;

    // Free only bank-sourced issues (bypass never occupied a way).
    if (pick.fire0 && !pick.src0_disp) bank_n[0][pick.sel0] = '0;
    if (pick.fire1 && !pick.src1_disp) bank_n[0][pick.sel1] = '0;

    for (int i = 0; i < RS_WAYS; i++)
      valid_after[i] = bank_n[0][i].valid;
    free_m = ~valid_after;
    free0  = rs_pe_lo(free_m);
    free1  = rs_pe_lo2(free_m);

    if (enable && !flush && !stall_dp) begin
      if (ins0) begin
        bank_n[0][free0] = rs_make_entry(disp.i0, age_n, wb);
        age_n = age_n + 1'b1;
      end

      if (ins1) begin
        slot = ins0 ? free1 : free0;
        bank_n[0][slot] = rs_make_entry(disp.i1, age_n, wb);
        age_n = age_n + 1'b1;
      end

      // Dest not ready once accepted (allocated or bypassed this cycle).
      if (disp.i0.valid && disp.i0.reg_write && (disp.i0.prd != 6'd0))
        prf_ready_n[disp.i0.prd] = 1'b0;
      if (disp.i1.valid && disp.i1.reg_write && (disp.i1.prd != 6'd0))
        prf_ready_n[disp.i1.prd] = 1'b0;
    end

    prf_ready_n[0] = 1'b1;
  end

endmodule
