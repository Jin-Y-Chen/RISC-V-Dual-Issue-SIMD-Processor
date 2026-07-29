`timescale 1ns / 1ps

// Bypass unit — evaluate dual dispatch as same-cycle issue candidates.
// Ready lanes compete with the RS bank in selector_unit; unselected /
// unready lanes are stored into the reservation station.
import rv_dis_pkg::*;
import rs_pkg::*;

module bypass_unit (
  input  rs_disp_pair_t      disp,
  input  logic [NUM_PRF-1:0] prf_ready,
  input  rs_wb_pair_t        wb,
  input  logic [31:0]        age_q,

  output logic               ready [2],
  output logic [31:0]        age   [2]
);

  logic [NUM_PRF-1:0] prf_w;
  logic               dep_rs1, dep_rs2;

  always_comb begin
    prf_w = prf_ready;
    if (wb.wb0.en) prf_w[wb.wb0.prd] = 1'b1;
    if (wb.wb1.en) prf_w[wb.wb1.prd] = 1'b1;
    prf_w[0] = 1'b1;
  end

  // I1 may RAW-depend on I0's dest in the same dual-dispatch pair.
  assign dep_rs1 = disp.i0.valid && disp.i0.reg_write &&
                   (disp.i0.prd != '0) && (disp.i1.ps1 == disp.i0.prd);
  assign dep_rs2 = disp.i0.valid && disp.i0.reg_write &&
                   (disp.i0.prd != '0) && (disp.i1.ps2 == disp.i0.prd);

  assign ready[0] = rs_disp_ready(disp.i0, prf_w, wb, 1'b0, 1'b0);
  assign ready[1] = rs_disp_ready(disp.i1, prf_w, wb, dep_rs1, dep_rs2);

  // Bypass is younger than every queued RS entry.
  assign age[0] = age_q;
  assign age[1] = age_q + 32'd1;

endmodule
