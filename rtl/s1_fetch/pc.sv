`timescale 1ns / 1ps

typedef rv_dis_pkg::word_t word_t;

// PC unit — pc0/pc1 from pc0_in/pc1_in; mode=1 => +4/+4, mode=0 => +8/+8.
module pc #(
  parameter word_t RESET_PC = word_t'(32'h0000_0000)
) (
  // external controls
  input  logic          clk,
  input  logic          rst_n,
  input  logic          enable,

  // internal controls
  input  logic          fetch_stall,
  input  logic          dispatch_stall, 
  input  logic          mode,
  input  logic          spec0_en,

  // input data
  input  word_t         pc0_in,
  input  word_t         pc1_in,

  // output data
  output logic          is_spec,
  output word_t         pc0_out,
  output word_t         pc1_out
);

  word_t pc0_next, pc1_next;
  word_t pc0_a, pc1_a;
  logic stall;

  assign stall = fetch_stall | dispatch_stall;
  assign pc0_a = rv_dis_pkg::imm_align4(pc0_in);
  assign pc1_a = rv_dis_pkg::imm_align4(pc1_in);

  always_comb begin
    pc0_next = pc0_out;
    pc1_next = pc1_out;

    if (!stall && enable) begin
      if (mode) begin
        pc0_next = pc0_a + word_t'(32'd4);
        pc1_next = pc1_a + word_t'(32'd4);
      end else begin
        pc0_next = pc0_a + word_t'(32'd8);
        pc1_next = pc1_a + word_t'(32'd8);
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc0_out <= RESET_PC;
      pc1_out <= RESET_PC + word_t'(32'd4);
      is_spec <= 1'b0;
    end else if (enable && !stall) begin
      pc0_out <= pc0_next;
      pc1_out <= pc1_next;
      is_spec <= spec0_en;
    end
  end

endmodule
