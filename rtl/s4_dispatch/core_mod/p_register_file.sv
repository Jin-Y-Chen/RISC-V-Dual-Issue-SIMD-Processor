`timescale 1ns / 1ps

// Dual-issue PRF: NUM_PRF x RLEN, 4 read + 2 write ports.
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
// p0 hardwired zero; same-prd dual WB prefers I1 (younger of the pair).
//
// Negedge commit; combo reads with same-cycle WB bypass.
import rv_dis_pkg::*;

module p_register_file (
  input  logic      clk,
  input  logic      rst_n,

  // Dual read (from RS issue)
  input  logic      rs1_use  [2],
  input  logic      rs2_use  [2],
  input  prf_addr_t rs1_addr [2],
  input  prf_addr_t rs2_addr [2],

  // Dual writeback
  input  logic      wb_en    [2],
  input  prf_addr_t wb_prd   [2],
  input  word_t     wb_data  [2],

  output word_t     rs1_data [2],
  output word_t     rs2_data [2]
);

  word_t preg [1:NUM_PRF-1];

  logic wr [2];
  logic same_rd;

  assign wr[0]   = wb_en[0] && (wb_prd[0] != '0);
  assign wr[1]   = wb_en[1] && (wb_prd[1] != '0);
  assign same_rd = wr[0] && wr[1] && (wb_prd[0] == wb_prd[1]);

  function automatic word_t prf_array_read(input prf_addr_t addr);
    return (addr == '0) ? '0 : preg[addr];
  endfunction

  function automatic word_t prf_read_port(
    input logic      rs_use,
    input prf_addr_t addr
  );
    word_t stored;
    logic  byp0, byp1;

    if (!rs_use)
      return '0;

    stored = prf_array_read(addr);
    byp0   = wr[0] && (wb_prd[0] == addr);
    byp1   = wr[1] && (wb_prd[1] == addr);

    // Same-prd: I1 wins (younger dual-issue lane).
    if (byp0 && byp1) return wb_data[1];
    if (byp1)         return wb_data[1];
    if (byp0)         return wb_data[0];
    return stored;
  endfunction

  // always_comb (not assign+function): XSim needs full bypass sensitivity.
  always_comb begin
    for (int i = 0; i < 2; i++) begin
      rs1_data[i] = prf_read_port(rs1_use[i], rs1_addr[i]);
      rs2_data[i] = prf_read_port(rs2_use[i], rs2_addr[i]);
    end
  end

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < NUM_PRF; i++)
        preg[i] <= '0;
    end else begin
      if (wr[0] && !same_rd)
        preg[wb_prd[0]] <= wb_data[0];
      if (wr[1])
        preg[wb_prd[1]] <= wb_data[1];
    end
  end

endmodule
