`timescale 1ns / 1ps

// Forward unit (EX) — two forwarding stages (project_outline "Dispatch"/"Forwarding"):
//
// 1) WB -> EX (combinational): a WB write-port hit replaces the stale GPR read
//    captured in ID. If both WB ports write the same rd, the younger insn
//    (larger pc) wins — same policy as register_file.
//
// 2) I0 -> I1 same-cycle forward (falling edge): when I1 reads I0's rd (RAW)
//    and the I0 unit asserts unit_done before the falling edge, I0's result is
//    latched at negedge and overrides I1's operand for the second half-cycle;
//    the I1 lane finishes in the remaining time and its result is captured at
//    the next posedge. If the RAW producer is not done by the falling edge
//    (e.g. LW: data returns in MEM), i1_stall requests a replay of I1 instead.
//
// reg_write already excludes rd == x0 and unused rs fields decode to x0,
// so no extra x0 qualifier is needed.
module forward_unit (
  input  logic        clk,
  input  logic        rst_n,

  // --- ev0 operands (from id_ex_dispatch, slot 0 / even copy) ---
  input  logic        ev0_enable,
  input  logic [4:0]  ev0_rs1_addr,
  input  logic [4:0]  ev0_rs2_addr,
  input  logic [31:0] ev0_rs1_data,
  input  logic [31:0] ev0_rs2_data,

  // --- ev1 operands (slot 1 / even copy) ---
  input  logic        ev1_enable,
  input  logic [4:0]  ev1_rs1_addr,
  input  logic [4:0]  ev1_rs2_addr,
  input  logic [31:0] ev1_rs1_data,
  input  logic [31:0] ev1_rs2_data,

  // --- od0 operands (slot 0 / odd copy) ---
  input  logic        od0_enable,
  input  logic [4:0]  od0_rs1_addr,
  input  logic [4:0]  od0_rs2_addr,
  input  logic [31:0] od0_rs1_data,
  input  logic [31:0] od0_rs2_data,

  // --- od1 operands (slot 1 / odd copy) ---
  input  logic        od1_enable,
  input  logic [4:0]  od1_rs1_addr,
  input  logic [4:0]  od1_rs2_addr,
  input  logic [31:0] od1_rs1_data,
  input  logic [31:0] od1_rs2_data,

  // --- I0 producer (EX): destination + per-copy result/done ---
  // i0_rd_addr: ev0_rd_ex == od0_rd_ex (both copies carry I0's rd).
  // ev0_unit_done: even ALU single-cycle — connect to ev0_enable at top level.
  // od0_result wiring: link_pc for JAL/JALR, alu_result for LUI/AUIPC.
  input  logic        i0_reg_write,   // I0 writes a GPR (id_ex_dispatch i0_reg_write_ex)
  input  logic [4:0]  i0_rd_addr,
  input  logic        ev0_unit_done,
  input  logic [31:0] ev0_result,     // alu_result
  input  logic        od0_unit_done,
  input  logic [31:0] od0_result,     // link_pc or alu_result (see above)

  // --- WB write port 0 (slot 0) ---
  input  logic        wb0_reg_write,
  input  logic [4:0]  wb0_rd_addr,
  input  logic [31:0] wb0_data,
  input  logic [31:0] wb0_pc,

  // --- WB write port 1 (slot 1) ---
  input  logic        wb1_reg_write,
  input  logic [4:0]  wb1_rd_addr,
  input  logic [31:0] wb1_data,
  input  logic [31:0] wb1_pc,

  // --- Forwarded operands to the lanes ---
  output logic [31:0] ev0_rs1_data_fwd,
  output logic [31:0] ev0_rs2_data_fwd,
  output logic [31:0] ev1_rs1_data_fwd,
  output logic [31:0] ev1_rs2_data_fwd,
  output logic [31:0] od0_rs1_data_fwd,
  output logic [31:0] od0_rs2_data_fwd,
  output logic [31:0] od1_rs1_data_fwd,
  output logic [31:0] od1_rs2_data_fwd,

  // --- RAW producer not done by the falling edge -> replay I1 ---
  output logic        i1_stall
);

  // ---------------------------------------------------------------------
  // Stage 1: WB -> EX (combinational)
  // ---------------------------------------------------------------------

  // One read-port forward: pick WB data on rd match, else keep the EX operand.
  function automatic logic [31:0] fwd_port(
    input logic        enable,
    input logic [4:0]  rs_addr,
    input logic [31:0] rs_data
  );
    logic wb0_hit;
    logic wb1_hit;

    if (!enable)
      return rs_data;

    wb0_hit = wb0_reg_write && (wb0_rd_addr == rs_addr);
    wb1_hit = wb1_reg_write && (wb1_rd_addr == rs_addr);

    if (wb0_hit && wb1_hit)
      return (wb1_pc >= wb0_pc) ? wb1_data : wb0_data;
    else if (wb1_hit)
      return wb1_data;
    else if (wb0_hit)
      return wb0_data;
    else
      return rs_data;
  endfunction

  // ---------------------------------------------------------------------
  // Stage 2: I0 -> I1 same-cycle forward (falling edge)
  // ---------------------------------------------------------------------

  // At most one slot-0 copy executes I0, so done/result reduce to one producer.
  logic        i0_done;
  logic [31:0] i0_result;

  assign i0_done   = ev0_unit_done || od0_unit_done;
  assign i0_result = ev0_unit_done ? ev0_result : od0_result;

  // I0 -> I1 RAW per consumer read port
  logic ev1_rs1_raw;
  logic ev1_rs2_raw;
  logic od1_rs1_raw;
  logic od1_rs2_raw;

  assign ev1_rs1_raw = ev1_enable && i0_reg_write && (ev1_rs1_addr == i0_rd_addr);
  assign ev1_rs2_raw = ev1_enable && i0_reg_write && (ev1_rs2_addr == i0_rd_addr);
  assign od1_rs1_raw = od1_enable && i0_reg_write && (od1_rs1_addr == i0_rd_addr);
  assign od1_rs2_raw = od1_enable && i0_reg_write && (od1_rs2_addr == i0_rd_addr);

  // RAW that cannot be served by the falling edge (e.g. LW producer)
  assign i1_stall = (ev1_rs1_raw || ev1_rs2_raw || od1_rs1_raw || od1_rs2_raw) &&
                    !i0_done;

  // Falling-edge latch: capture I0's result and the per-port override flags.
  // Flags are recomputed every negedge, so a stale override only affects the
  // first half-cycle of the next pair; results are captured at posedge after
  // the override has settled.
  logic        ev1_rs1_ovr_q;
  logic        ev1_rs2_ovr_q;
  logic        od1_rs1_ovr_q;
  logic        od1_rs2_ovr_q;
  logic [31:0] i0_result_q;

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ev1_rs1_ovr_q <= 1'b0;
      ev1_rs2_ovr_q <= 1'b0;
      od1_rs1_ovr_q <= 1'b0;
      od1_rs2_ovr_q <= 1'b0;
      i0_result_q   <= 32'd0;
    end else begin
      ev1_rs1_ovr_q <= ev1_rs1_raw && i0_done;
      ev1_rs2_ovr_q <= ev1_rs2_raw && i0_done;
      od1_rs1_ovr_q <= od1_rs1_raw && i0_done;
      od1_rs2_ovr_q <= od1_rs2_raw && i0_done;
      i0_result_q   <= i0_result;
    end
  end

  // ---------------------------------------------------------------------
  // Operand outputs: I0 override (second half-cycle) on top of WB forwarding
  // ---------------------------------------------------------------------
  // always_comb (not assign+function): XSim must see full WB sensitivity
  always_comb begin
    ev0_rs1_data_fwd = fwd_port(ev0_enable, ev0_rs1_addr, ev0_rs1_data);
    ev0_rs2_data_fwd = fwd_port(ev0_enable, ev0_rs2_addr, ev0_rs2_data);
    od0_rs1_data_fwd = fwd_port(od0_enable, od0_rs1_addr, od0_rs1_data);
    od0_rs2_data_fwd = fwd_port(od0_enable, od0_rs2_addr, od0_rs2_data);

    ev1_rs1_data_fwd = ev1_rs1_ovr_q ? i0_result_q
                                     : fwd_port(ev1_enable, ev1_rs1_addr, ev1_rs1_data);
    ev1_rs2_data_fwd = ev1_rs2_ovr_q ? i0_result_q
                                     : fwd_port(ev1_enable, ev1_rs2_addr, ev1_rs2_data);
    od1_rs1_data_fwd = od1_rs1_ovr_q ? i0_result_q
                                     : fwd_port(od1_enable, od1_rs1_addr, od1_rs1_data);
    od1_rs2_data_fwd = od1_rs2_ovr_q ? i0_result_q
                                     : fwd_port(od1_enable, od1_rs2_addr, od1_rs2_data);
  end

endmodule
