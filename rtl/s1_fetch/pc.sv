`timescale 1ns / 1ps

// Fetch-stage program counter for dual-issue RV32I.
// - Byte-addressed PC (RV32I)
// - 32-bit fixed-width instructions => +4 bytes per instruction
// - Single issue advance: +4, dual issue advance: +8
module pc #(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  input  logic        clk,
  input  logic        rst_n,

  // Control from front-end / dispatch
  input  logic        stall_i,         // hold PC when set (unless redirect)
  input  logic        advance_i,       // fetch/issue accepted this cycle
  input  logic        dual_issue_i,    // 1 => advance by two instructions

  // Control-flow redirect (branch/jump/mispredict recovery)
  input  logic        redirect_i,
  input  logic [31:0] redirect_pc_i,   // byte PC

  // Current fetch PCs (older / younger in a pair)
  output logic [31:0] pc_o,            // current fetch PC (older instruction)
  output logic [31:0] pc_plus4_o       // younger instruction PC in same fetch pair
);

  logic [31:0] pc_q;
  logic [31:0] pc_next;

  always_comb begin
    pc_next = pc_q;

    // Redirect has highest priority so recovery is not blocked by a stall.
    if (redirect_i) begin
      // Keep PC 4-byte aligned for fixed 32-bit instruction fetch.
      pc_next = {redirect_pc_i[31:2], 2'b00};
    end else if (!stall_i && advance_i) begin
      pc_next = pc_q + ((dual_issue_i) ? 32'd8 : 32'd4);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_q <= RESET_PC;
    end else begin
      pc_q <= pc_next;
    end
  end

  assign pc_o       = pc_q;
  assign pc_plus4_o = pc_q + 32'd4;

endmodule
