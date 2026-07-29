`timescale 1ns / 1ps

// RS alloc — path filter, free selected bank ways, store unselected bypass.
// Unselected dispatch (valid && !pick.bypass*) is written into free RS ways.
import rv_dis_pkg::*;
import rs_pkg::*;

module rs_alloc (
  input  logic               enable,
  input  logic               flush,
  input  logic               stall_dp,
  input  logic               path_en,
  input  logic               path_sel,

  input  rs_entry_t          bank_w [RS_SETS][RS_WAYS],
  input  logic [NUM_PRF-1:0] prf_ready_w,
  input  logic [31:0]        age_q,

  input  rs_pick_t           pick,
  input  rs_disp_pair_t      disp,

  output rs_entry_t          bank_n [RS_SETS][RS_WAYS],
  output logic [NUM_PRF-1:0] prf_ready_n,
  output logic [31:0]        age_n
);

  rs_mask_t valid_after;
  rs_mask_t free_m;
  rs_way_t  free0, free1, slot;
  logic     dep_rs1, dep_rs2;
  logic     store0, store1;

  // Store every valid dispatch lane the selector did not issue via bypass.
  assign store0 = disp.i0.valid && !pick.bypass0;
  assign store1 = disp.i1.valid && !pick.bypass1;

  always_comb begin
    bank_n      = bank_w;
    prf_ready_n = prf_ready_w;
    age_n       = age_q;

    if (path_en) begin
      for (int i = 0; i < RS_WAYS; i++) begin
        if (bank_n[0][i].valid && (bank_n[0][i].spec_en != path_sel))
          bank_n[0][i] = '0;
      end
    end

    // Free bank ways the selector issued from the reservation station.
    if (pick.fire0 && !pick.src0_disp) bank_n[0][pick.sel0] = '0;
    if (pick.fire1 && !pick.src1_disp) bank_n[0][pick.sel1] = '0;

    for (int i = 0; i < RS_WAYS; i++)
      valid_after[i] = bank_n[0][i].valid;
    free_m = ~valid_after;
    free0  = rs_pe_lo(free_m);
    free1  = rs_pe_lo2(free_m);

    if (enable && !flush && !stall_dp) begin
      if (store0) begin
        bank_n[0][free0] = rs_make_entry(
          disp.i0, age_n, prf_ready_n, '{default: '0}, 1'b0, 1'b0);
        age_n = age_n + 1'b1;
      end

      if (store1) begin
        slot    = store0 ? free1 : free0;
        dep_rs1 = disp.i0.valid && disp.i0.reg_write &&
                  (disp.i0.prd != '0) && (disp.i1.ps1 == disp.i0.prd);
        dep_rs2 = disp.i0.valid && disp.i0.reg_write &&
                  (disp.i0.prd != '0) && (disp.i1.ps2 == disp.i0.prd);
        bank_n[0][slot] = rs_make_entry(
          disp.i1, age_n, prf_ready_n, '{default: '0}, dep_rs1, dep_rs2);
        age_n = age_n + 1'b1;
      end

      // Dest not ready once accepted (stored or bypass-issued this cycle).
      if (disp.i0.valid && disp.i0.reg_write && (disp.i0.prd != 6'd0))
        prf_ready_n[disp.i0.prd] = 1'b0;
      if (disp.i1.valid && disp.i1.reg_write && (disp.i1.prd != 6'd0))
        prf_ready_n[disp.i1.prd] = 1'b0;
    end

    prf_ready_n[0] = 1'b1;
  end

endmodule
