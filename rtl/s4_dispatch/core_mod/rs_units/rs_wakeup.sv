`timescale 1ns / 1ps

// RS wakeup — OR writeback hits onto registered ready bits.
import rv_dis_pkg::*;
import rs_pkg::*;

module rs_wakeup (
  input  logic      bank_valid_q   [RS_WAYS],
  input  logic      bank_rs1_rdy_q [RS_WAYS],
  input  logic      bank_rs2_rdy_q [RS_WAYS],
  input  prf_addr_t bank_ps1_q     [RS_WAYS],
  input  prf_addr_t bank_ps2_q     [RS_WAYS],
  input  logic      wb_en          [2],
  input  prf_addr_t rob_tag_wb     [2],

  output logic      bank_rs1_rdy_w [RS_WAYS],
  output logic      bank_rs2_rdy_w [RS_WAYS]
);

  genvar w;
  generate
    for (w = 0; w < RS_WAYS; w++) begin : g_wake
      assign bank_rs1_rdy_w[w] = bank_rs1_rdy_q[w] ||
        (bank_valid_q[w] && rs_wb_hit(bank_ps1_q[w], wb_en, rob_tag_wb));
      assign bank_rs2_rdy_w[w] = bank_rs2_rdy_q[w] ||
        (bank_valid_q[w] && rs_wb_hit(bank_ps2_q[w], wb_en, rob_tag_wb));
    end
  endgenerate

endmodule
