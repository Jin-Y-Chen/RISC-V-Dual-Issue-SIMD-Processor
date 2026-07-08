`timescale 1ns / 1ps

// Issue gate for dual-issue dispatch — same-bundle GPR RAW and I1 buffer replay.
import rv_dis_pkg::*;

module scoreboard (
  // input data — ID pair
  input  logic      i0_reg_write,
  input  gpr_addr_t i0_rd,
  input  opcode_t   i0_opcode,
  input  logic      i1_rs1_use,
  input  logic      i1_rs2_use,
  input  gpr_addr_t i1_rs1,
  input  gpr_addr_t i1_rs2,

  // input controls — buffered I1 replay
  input  logic      buf_valid,
  input  logic      issue_i1_from_hold,
  input  logic      suppress_bundle_raw,

  // output controls
  output logic      issue_i0,
  output logic      issue_i1,
  output logic      stall_id,
  output logic      set_i1_hold,
  output logic [1:0] i1_stall_cycles
);

  logic bundle_raw;

  assign bundle_raw = !suppress_bundle_raw &&
                      i0_reg_write && (i0_rd != 5'd0) &&
                      ((i1_rs1_use && (i1_rs1 == i0_rd)) ||
                       (i1_rs2_use && (i1_rs2 == i0_rd)));

  always_comb begin
    issue_i0         = 1'b1;
    issue_i1         = 1'b1;
    stall_id         = 1'b0;
    set_i1_hold      = 1'b0;
    i1_stall_cycles  = 2'd1;

    if (buf_valid) begin
      issue_i0 = 1'b0;
      issue_i1 = issue_i1_from_hold;
      stall_id = !issue_i1_from_hold;
      set_i1_hold = 1'b0;
      i1_stall_cycles = 2'd1;
    end else if (bundle_raw) begin
      issue_i0 = 1'b1;
      issue_i1 = 1'b0;
      stall_id = 1'b1;
      set_i1_hold = 1'b1;
      i1_stall_cycles = (i0_opcode == OPC_LOAD) ? 2'd2 : 2'd1;
    end
  end

endmodule
