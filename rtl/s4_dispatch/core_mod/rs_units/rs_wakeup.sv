`timescale 1ns / 1ps

// RS wakeup — apply WB broadcast to bank ready bits and PRF ready map.
import rv_dis_pkg::*;
import rs_pkg::*;

module rs_wakeup (
  input  rs_entry_t          bank_q [RS_SETS][RS_WAYS],
  input  logic [NUM_PRF-1:0] prf_ready_q,
  input  rs_wb_pair_t        wb,

  output rs_entry_t          bank_w [RS_SETS][RS_WAYS],
  output logic [NUM_PRF-1:0] prf_ready_w
);

  genvar w;
  generate
    for (w = 0; w < RS_WAYS; w++) begin : g_wake
      always_comb begin
        bank_w[0][w] = bank_q[0][w];
        if (bank_w[0][w].valid) begin
          if (!bank_w[0][w].rs1_ready && rs_wb_hit(bank_w[0][w].ps1, wb))
            bank_w[0][w].rs1_ready = 1'b1;
          if (!bank_w[0][w].rs2_ready && rs_wb_hit(bank_w[0][w].ps2, wb))
            bank_w[0][w].rs2_ready = 1'b1;
        end
      end
    end
  endgenerate

  always_comb begin
    prf_ready_w = prf_ready_q;
    if (wb.wb0.en) prf_ready_w[wb.wb0.prd] = 1'b1;
    if (wb.wb1.en) prf_ready_w[wb.wb1.prd] = 1'b1;
    prf_ready_w[0] = 1'b1;
  end

endmodule
