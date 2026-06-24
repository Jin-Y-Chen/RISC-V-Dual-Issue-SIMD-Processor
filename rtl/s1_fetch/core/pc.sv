`timescale 1ns / 1ps

// Fetch-stage program counter for dual-issue RV32I.
module pc #(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  input  logic               clk,
  input  logic               rst_n,
  input  logic               enable,
  input  logic               stall,
  input  logic               set,
  input  rv_dis_pkg::pc_t    set_pc,
  output rv_dis_pkg::pc_t    pc0,
  output rv_dis_pkg::pc_t    pc1
);

  typedef rv_dis_pkg::pc_t pc_t;
  pc_t pc_q, pc_next;

  always_comb begin
    pc_next = pc_q;
    if (set) begin
      pc_next = {set_pc[31:2], 2'b00};
    end else if (!stall && enable) begin
      pc_next = pc_q + 32'd8;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc_q <= RESET_PC;
    end else begin
      pc_q <= pc_next;
    end
  end

  assign pc0 = pc_q;
  assign pc1 = pc_q + 32'd4;

endmodule
