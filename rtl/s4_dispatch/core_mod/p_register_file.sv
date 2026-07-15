`timescale 1ns / 1ps

// Dual-issue Physical Register File (PRF): NUM_PRF x RLEN, 4 read + 2 write ports.
// p0 reads as zero; writes to p0 ignored (hardwired zero for architectural x0).
// Same-cycle WAW to same prd: I1 always wins (in-order dual-issue; ROB owns WAW age).
//
// Timing: preg[] commits on negedge; read ports are combinational with WB bypass so
// issue/dispatch operands still see WB data in the same cycle before falling-edge commit.
import rv_dis_pkg::*;

module p_register_file (
  // external controls
  input  logic        clk,
  input  logic        rst_n,

  // internal controls
  input  logic        i0_rs1_use,
  input  logic        i0_rs2_use,
  input  logic        i1_rs1_use,
  input  logic        i1_rs2_use,
  input  logic        i0_valid_wb,
  input  logic        i1_valid_wb,

  // input data — physical register indices
  input  prf_addr_t   i0_rs1_addr,
  input  prf_addr_t   i0_rs2_addr,
  input  prf_addr_t   i1_rs1_addr,
  input  prf_addr_t   i1_rs2_addr,
  input  prf_addr_t   i0_rd_addr,
  input  prf_addr_t   i1_rd_addr,
  input  word_t       i0_data_wb,
  input  word_t       i1_data_wb,

  // output data
  output word_t       i0_rs1_data,
  output word_t       i0_rs2_data,
  output word_t       i1_rs1_data,
  output word_t       i1_rs2_data
);

  // p1..p{NUM_PRF-1} stored; p0 is not physical storage
  word_t preg [1:NUM_PRF-1];

  logic i0_wr;
  logic i1_wr;
  logic same_rd;

  assign i0_wr   = i0_valid_wb && (i0_rd_addr != '0);
  assign i1_wr   = i1_valid_wb && (i1_rd_addr != '0);
  assign same_rd = i0_wr && i1_wr && (i0_rd_addr == i1_rd_addr);

  function automatic word_t prf_array_read(input prf_addr_t addr);
    if (addr == '0)
      prf_array_read = '0;
    else
      prf_array_read = preg[addr];
  endfunction

  function automatic word_t prf_read_port(input logic rs_use, input prf_addr_t addr);
    word_t stored;
    logic  i0_byp, i1_byp;
    word_t wdata;

    if (!rs_use)
      prf_read_port = '0;
    else begin
      stored = prf_array_read(addr);
      i0_byp = i0_wr && (i0_rd_addr == addr);
      i1_byp = i1_wr && (i1_rd_addr == addr);

      // Dual same-prd bypass: I1 is always younger in the dual-issue pair.
      if (i0_byp && i1_byp)
        wdata = i1_data_wb;
      else if (i1_byp)
        wdata = i1_data_wb;
      else if (i0_byp)
        wdata = i0_data_wb;
      else
        wdata = stored;

      prf_read_port = wdata;
    end
  endfunction

  // always_comb (not assign+function): XSim must see full bypass/write sensitivity
  always_comb begin
    i0_rs1_data = prf_read_port(i0_rs1_use, i0_rs1_addr);
    i0_rs2_data = prf_read_port(i0_rs2_use, i0_rs2_addr);
    i1_rs1_data = prf_read_port(i1_rs1_use, i1_rs1_addr);
    i1_rs2_data = prf_read_port(i1_rs2_use, i1_rs2_addr);
  end

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < NUM_PRF; i++)
        preg[i] <= '0;
    end else begin
      // Same-prd dual WB: commit I1 only (I0 suppressed).
      if (i0_wr && !same_rd)
        preg[i0_rd_addr] <= i0_data_wb;
      if (i1_wr)
        preg[i1_rd_addr] <= i1_data_wb;
    end
  end

endmodule
