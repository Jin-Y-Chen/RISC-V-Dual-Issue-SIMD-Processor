`timescale 1ns / 1ps

// In-order issue gate at ID→EX (project_outline §6).
// Same-bundle RAW: partial-issue I0, buffer I1, full stall until replay.
module scoreboard
  import rv_dis_pkg::*;
(
  input  logic        i0_valid,
  input  logic        i0_reg_write,
  input  logic [4:0]  i0_rd,
  input  logic [6:0]  i0_opcode,

  input  logic        i1_valid,
  input  logic        i1_rs1_use,
  input  logic        i1_rs2_use,
  input  logic [4:0]  i1_rs1,
  input  logic [4:0]  i1_rs2,

  input  logic        buf_valid,
  input  logic        issue_i1_from_hold,

  input  logic        suppress_bundle_raw,

  output logic        issue_i0,
  output logic        issue_i1,
  output logic        stall_id,
  output logic        set_i1_hold,
  output logic        bundle_raw,
  output logic [1:0]  i1_stall_cycles
);

  wire i0_writes = i0_valid && i0_reg_write && (i0_rd != 5'd0);

  assign bundle_raw = i0_writes && i1_valid && (
      (i1_rs1_use && (i1_rs1 == i0_rd)) ||
      (i1_rs2_use && (i1_rs2 == i0_rd)));

  wire load_use_raw = bundle_raw && (i0_opcode == OPC_LOAD);

  assign i1_stall_cycles = load_use_raw ? 2'd2 : 2'd1;

  always_comb begin
    issue_i0    = 1'b0;
    issue_i1    = 1'b0;
    stall_id    = 1'b0;
    set_i1_hold = 1'b0;

    if (buf_valid) begin
      stall_id = 1'b1;
      if (issue_i1_from_hold) begin
        issue_i1 = 1'b1;
        stall_id = 1'b0;
      end
    end else if (bundle_raw && !suppress_bundle_raw && i0_valid) begin
      issue_i0    = 1'b1;
      set_i1_hold = i1_valid;
      stall_id    = 1'b1;
    end else begin
      issue_i0 = i0_valid;
      issue_i1 = i1_valid;
    end
  end

endmodule
