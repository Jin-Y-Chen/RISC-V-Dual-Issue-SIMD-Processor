`timescale 1ns / 1ps

// Reservation station — owns the instruction bank + PRF-ready / age state.
// Wakeup and alloc are internal. Bypass and select live in issue_core_struct.
import rv_dis_pkg::*;
import rs_pkg::*;

module reservation_station (
  input  logic               clk,
  input  logic               rst_n,
  input  logic               enable,
  input  logic               flush,
  input  logic               path_en,
  input  logic               path_sel,
  input  logic               stall_dp,

  input  rs_disp_pair_t      disp,
  input  rs_wb_pair_t        wb,
  input  rs_pick_t           pick,

  output rs_entry_t          bank_q [RS_SETS][RS_WAYS],
  output logic [NUM_PRF-1:0] prf_ready_q,
  output logic [31:0]        age_q
);

  rs_entry_t          bank_w [RS_SETS][RS_WAYS];
  rs_entry_t          bank_n [RS_SETS][RS_WAYS];
  logic [NUM_PRF-1:0] prf_ready_w, prf_ready_n;
  logic [31:0]        age_n;

  rs_wakeup u_wakeup (
    .bank_q, .prf_ready_q, .wb,
    .bank_w, .prf_ready_w
  );

  rs_alloc u_alloc (
    .enable, .flush, .stall_dp,
    .path_en, .path_sel,
    .bank_w, .prf_ready_w, .age_q,
    .pick, .disp,
    .bank_n, .prf_ready_n, .age_n
  );

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      bank_q      <= '{default: '0};
      prf_ready_q <= '1;
      age_q       <= '0;
    end else begin
      bank_q      <= bank_n;
      prf_ready_q <= prf_ready_n;
      age_q       <= age_n;
    end
  end

endmodule
