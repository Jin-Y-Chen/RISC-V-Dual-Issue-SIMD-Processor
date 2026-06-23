`timescale 1ns / 1ps

// Fetch-stage program counter for dual-issue RV32I.
// - Byte-addressed PC (RV32I)
// - 32-bit fixed-width instructions => +4 bytes per instruction
// - Always dual issue: advance by two instructions (+8) per accepted fetch
module pc #(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  // external controls
  input  logic               clk,
  input  logic               rst_n,
  input  logic               enable,          // fetch accepted this cycle (+8 when not stalled)

  // internal controls
  input  logic               stall,           // hold PC (unless set)
  input  logic               set,

  // input data
  input  rv_dis_pkg::pc_t    set_pc,          // byte PC

  // output data
  output rv_dis_pkg::pc_t    pc0,             // older instruction in fetch pair
  output rv_dis_pkg::pc_t    pc1              // younger instruction: pc1 = pc0 + 4
);

  import rv_dis_pkg::*;

  pc_t pc_q;
  pc_t pc_next;

  always_comb begin
    pc_next = pc_q;

    // set has highest priority so recovery is not blocked by a stall.
    if (set) begin
      // Keep PC 4-byte aligned for fixed 32-bit instruction fetch.
      pc_next = {set_pc[31:2], 2'b00};
    end else if (!stall && enable) begin
      pc_next = pc_q + pc_t'(32'd8);
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc_q <= pc_t'(RESET_PC);
    end else begin
      pc_q <= pc_next;
    end
  end

  assign pc0 = pc_q;
  assign pc1 = pc_q + pc_t'(32'd4);

endmodule
