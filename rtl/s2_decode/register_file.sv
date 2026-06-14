`timescale 1ns / 1ps

// Dual-issue scalar GPR (32x32): 4 read + 2 write ports (project_outline SS4-5).
// x0 reads as zero; writes to x0 ignored. Same-cycle write to same rd: higher wpc wins.
//
// Timing: regs[] commits on negedge; read ports are combinational with WB bypass so
// ID/EX operands still see WB data in the same cycle before the falling-edge commit.
module register_file
  import rv_dis_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // I0 lane read (ID) — ALU rs1 / rs2
  input  logic        i0_rs1_use,
  input  logic        i0_rs2_use,
  input  logic [4:0]  i0_rs1_addr,
  input  logic [4:0]  i0_rs2_addr,
  output reg_t        i0_rs1_data,
  output reg_t        i0_rs2_data,

  // I1 lane read (ID) — load/store / branch rs1 / rs2
  input  logic        i1_rs1_use,
  input  logic        i1_rs2_use,
  input  logic [4:0]  i1_rs1_addr,
  input  logic [4:0]  i1_rs2_addr,
  output reg_t        i1_rs1_data,
  output reg_t        i1_rs2_data,

  // I0 lane write (WB)
  input  logic        i0_wen,
  input  logic [4:0]  i0_rd,
  input  reg_t        i0_wdata,
  input  reg_t        i0_wpc,

  // I1 lane write (WB)
  input  logic        i1_wen,
  input  logic [4:0]  i1_rd,
  input  reg_t        i1_wdata,
  input  reg_t        i1_wpc
);

  // x1-x31 stored; x0 is not physical storage
  reg_t regs [1:NUM_GPR-1];

  logic i0_wr;
  logic i1_wr;
  logic same_rd;
  logic i1_wins;

  assign i0_wr = i0_wen && (i0_rd != 5'd0);
  assign i1_wr = i1_wen && (i1_rd != 5'd0);
  assign same_rd = i0_wr && i1_wr && (i0_rd == i1_rd);
  assign i1_wins = same_rd && (i1_wpc >= i0_wpc);

  function automatic reg_t rf_array_read(input logic [4:0] addr);
    if (addr == 5'd0)
      rf_array_read = '0;
    else
      rf_array_read = regs[addr];
  endfunction

  function automatic reg_t rf_read_port(input logic rs_use, input logic [4:0] addr);
    reg_t         stored;
    logic         i0_byp, i1_byp;
    reg_t         wdata;

    if (!rs_use) begin
      rf_read_port = '0;
      return;
    end

    stored  = rf_array_read(addr);
    i0_byp  = i0_wr && (i0_rd == addr);
    i1_byp  = i1_wr && (i1_rd == addr);

    if (i0_byp && i1_byp)
      wdata = i1_wins ? i1_wdata : i0_wdata;
    else if (i1_byp)
      wdata = i1_wdata;
    else if (i0_byp)
      wdata = i0_wdata;
    else
      wdata = stored;

    rf_read_port = wdata;
  endfunction

  // always_comb (not assign+function): XSim must see full bypass/write sensitivity
  always_comb begin
    i0_rs1_data = rf_read_port(i0_rs1_use, i0_rs1_addr);
    i0_rs2_data = rf_read_port(i0_rs2_use, i0_rs2_addr);
    i1_rs1_data = rf_read_port(i1_rs1_use, i1_rs1_addr);
    i1_rs2_data = rf_read_port(i1_rs2_use, i1_rs2_addr);
  end

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < NUM_GPR; i++)
        regs[i] <= '0;
    end else begin
      if (i0_wr && !i1_wins)
        regs[i0_rd] <= i0_wdata;
      if (i1_wr && (!same_rd || i1_wins))
        regs[i1_rd] <= i1_wdata;
    end
  end

endmodule
