`timescale 1ns / 1ps

// In-order issue gate at ID→EX (project_outline §6).
// Same-bundle RAW: partial-issue I0, buffer I1, full stall until replay.
// Valid/lane gating is applied in id_ex_dispatch (issue_i0_eff / issue_i1_eff).
module scoreboard
  import rv_dis_pkg::*;
(
  // internal controls
  input  logic        i0_reg_write,
  input  logic        i1_rs1_use,
  input  logic        i1_rs2_use,
  input  logic        buf_valid,
  input  logic        issue_i1_from_hold,
  input  logic        suppress_bundle_raw,

  // input data
  input  gpr_addr_t   i0_rd,
  input  opcode_t     i0_opcode,
  input  gpr_addr_t   i1_rs1,
  input  gpr_addr_t   i1_rs2,

  // output controls
  output logic        issue_i0,
  output logic        issue_i1,
  output logic        stall_id,
  output logic        set_i1_hold,
  output logic [1:0]  i1_stall_cycles
);

  wire i0_writes = i0_reg_write && (i0_rd != 5'd0);

  wire bundle_raw = i0_writes && (
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
    end else if (bundle_raw && !suppress_bundle_raw) begin
      issue_i0    = 1'b1;
      set_i1_hold = 1'b1;
      stall_id    = 1'b1;
    end else begin
      issue_i0 = 1'b1;
      issue_i1 = 1'b1;
    end
  end

endmodule
