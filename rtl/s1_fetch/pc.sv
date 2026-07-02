`timescale 1ns / 1ps

typedef rv_dis_pkg::word_t word_t;

// PC unit — pc0 from spec_in, pc1 from norm_in; +4 per lane (spec) or +8/+12 (sequential).
module pc #(
  parameter word_t RESET_PC = word_t'(32'h0000_0000)
) (
  input  logic  clk,
  input  logic  rst_n,
  input  logic  enable,
  input  logic  stall,
  input  logic  spec_en,
  input  word_t spec_in,
  input  word_t norm_in,
  output word_t pc0_out,
  output word_t pc1_out
);

  word_t pc0_q, pc1_q;
  word_t pc0_next, pc1_next;
  word_t spec_a, norm_a;

  assign spec_a = rv_dis_pkg::imm_align4(spec_in);
  assign norm_a = rv_dis_pkg::imm_align4(norm_in);

  always_comb begin
    pc0_next = pc0_q;
    pc1_next = pc1_q;

    if (!stall && enable) begin
      if (spec_en) begin
        pc0_next = spec_a + word_t'(32'd4);
        pc1_next = norm_a + word_t'(32'd4);
      end else begin
        pc0_next = norm_a + word_t'(32'd8);
        pc1_next = norm_a + word_t'(32'd12);
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc0_q <= RESET_PC;
      pc1_q <= RESET_PC + word_t'(32'd4);
    end else begin
      pc0_q <= pc0_next;
      pc1_q <= pc1_next;
    end
  end

  assign pc0_out = pc0_q;
  assign pc1_out = pc1_q;

endmodule
