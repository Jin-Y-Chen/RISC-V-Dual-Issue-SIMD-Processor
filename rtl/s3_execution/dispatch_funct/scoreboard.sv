`timescale 1ns / 1ps

// In-order issue scoreboard at ID→EX (project_outline §6).
// Same-bundle GPR RAW: partial-issue I0, push I1 into 4-entry insn_buffer, replay head
// when producer MEM forward hits. v2 hooks: stall_mem, busy[] (load-use, outline §4.d.2).
module scoreboard
  import rv_dis_pkg::*;
(
  // ID fetch pair (I0 older, I1 younger)
  input  logic        i0_valid,
  input  logic        i0_reg_write,
  input  logic        i0_rs1_use,
  input  logic        i0_rs2_use,
  input  logic [4:0]  i0_rd,
  input  logic [4:0]  i0_rs1,
  input  logic [4:0]  i0_rs2,

  input  logic        i1_valid,
  input  logic        i1_reg_write,
  input  logic        i1_rs1_use,
  input  logic        i1_rs2_use,
  input  logic [4:0]  i1_rd,
  input  logic [4:0]  i1_rs1,
  input  logic [4:0]  i1_rs2,

  // insn_buffer head (oldest suppressed instruction)
  input  logic        buf_empty,
  input  logic        buf_push_ok,
  input  logic        buf_head_rs1_use,
  input  logic        buf_head_rs2_use,
  input  logic [4:0]  buf_head_rs1,
  input  logic [4:0]  buf_head_rs2,
  input  logic        buf_head_producer_valid,
  input  logic [4:0]  buf_head_producer_rd,

  // Forward sources (same as forward_unit)
  input  logic        mem0_reg_write,
  input  logic [4:0]  mem0_rd,
  input  logic        mem1_reg_write,
  input  logic [4:0]  mem1_rd,
  input  logic        wb0_reg_write,
  input  logic [4:0]  wb0_rd,
  input  logic        wb1_reg_write,
  input  logic [4:0]  wb1_rd,

  input  logic        stall_mem,
  input  logic        suppress_bundle_raw,
  input  logic        hold_replay_block,

  output logic        issue_i0,
  output logic        issue_i1,
  output logic        stall_id,
  output logic        set_i1_hold,
  output logic        issue_i1_from_hold,
  output logic        bundle_raw
);

  logic i0_writes;
  logic i1_dep_i0;
  logic bundle_raw_stall;
  logic buf_head_rs_ok;
  logic buf_active;
  logic buf_backpressure;

  assign buf_active        = !buf_empty;
  assign buf_backpressure  = !buf_push_ok;

  wire fwd_hit = (mem0_reg_write && (mem0_rd == buf_head_producer_rd)) ||
                 (mem1_reg_write && (mem1_rd == buf_head_producer_rd)) ||
                 (wb0_reg_write  && (wb0_rd  == buf_head_producer_rd)) ||
                 (wb1_reg_write  && (wb1_rd  == buf_head_producer_rd));

  wire rs1_needs_fwd = buf_head_rs1_use && (buf_head_rs1 != 5'd0) &&
                       buf_head_producer_valid &&
                       (buf_head_rs1 == buf_head_producer_rd);
  wire rs2_needs_fwd = buf_head_rs2_use && (buf_head_rs2 != 5'd0) &&
                       buf_head_producer_valid &&
                       (buf_head_rs2 == buf_head_producer_rd);

  assign i0_writes  = i0_valid && i0_reg_write && (i0_rd != 5'd0);
  assign i1_dep_i0  = i0_writes && i1_valid && (
                        (i1_rs1_use && (i1_rs1 == i0_rd)) ||
                        (i1_rs2_use && (i1_rs2 == i0_rd)));
  assign bundle_raw       = i1_dep_i0;
  assign bundle_raw_stall = i1_dep_i0 && !suppress_bundle_raw;
  assign buf_head_rs_ok   = buf_active &&
                            (!rs1_needs_fwd || fwd_hit) &&
                            (!rs2_needs_fwd || fwd_hit);

  always_comb begin
    issue_i0           = 1'b0;
    issue_i1           = 1'b0;
    stall_id           = 1'b0;
    set_i1_hold        = 1'b0;
    issue_i1_from_hold = 1'b0;

    if (stall_mem) begin
      stall_id = 1'b1;
    end else if (buf_backpressure) begin
      // Fewer than 2 free slots — global front-end stall; drain head when ready
      stall_id = 1'b1;
      if (buf_active && buf_head_rs_ok && !hold_replay_block) begin
        issue_i1_from_hold = 1'b1;
        issue_i1           = 1'b1;
      end
    end else if (buf_active) begin
      stall_id = 1'b1;
      if (buf_head_rs_ok && !hold_replay_block) begin
        issue_i1_from_hold = 1'b1;
        issue_i1           = 1'b1;
        stall_id           = 1'b0;
      end
    end else if (bundle_raw_stall && i0_valid) begin
      issue_i0    = 1'b1;
      set_i1_hold = i1_valid;
      stall_id    = i1_valid;
    end else begin
      issue_i0 = i0_valid;
      issue_i1 = i1_valid;
    end
  end

endmodule
