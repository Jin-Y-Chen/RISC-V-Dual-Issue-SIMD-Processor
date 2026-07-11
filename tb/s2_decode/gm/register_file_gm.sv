`timescale 1ns / 1ps

// Golden model for rtl/s2_decode/core_mod/register_file.sv
// Bank replica + same-cycle WB bypass; commits on negedge (matches DUT).
import rv_dis_pkg::*;

module register_file_gm (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        i0_rs1_use,
  input  logic        i0_rs2_use,
  input  logic        i1_rs1_use,
  input  logic        i1_rs2_use,
  input  logic        i0_valid_wb,
  input  logic        i1_valid_wb,
  input  gpr_addr_t   i0_rs1_addr,
  input  gpr_addr_t   i0_rs2_addr,
  input  gpr_addr_t   i1_rs1_addr,
  input  gpr_addr_t   i1_rs2_addr,
  input  gpr_addr_t   i0_rd,
  input  gpr_addr_t   i1_rd,
  input  word_t       i0_data_wb,
  input  word_t       i1_data_wb,
  input  word_t       i0_pc_wb,
  input  word_t       i1_pc_wb,
  output word_t       i0_rs1_data,
  output word_t       i0_rs2_data,
  output word_t       i1_rs1_data,
  output word_t       i1_rs2_data
);

  word_t regs [1:NUM_GPR-1];

  logic i0_wr, i1_wr, same_rd, i1_wins;

  assign i0_wr   = i0_valid_wb && (i0_rd != 5'd0);
  assign i1_wr   = i1_valid_wb && (i1_rd != 5'd0);
  assign same_rd = i0_wr && i1_wr && (i0_rd == i1_rd);
  assign i1_wins = same_rd && (i1_pc_wb >= i0_pc_wb);

  function automatic word_t rf_array_read(input logic [4:0] addr);
    if (addr == 5'd0)
      return '0;
    return regs[addr];
  endfunction

  function automatic word_t rf_read_port(input logic rs_use, input logic [4:0] addr);
    word_t stored, wdata;
    logic  i0_byp, i1_byp;

    if (!rs_use)
      return '0;

    stored = rf_array_read(addr);
    i0_byp = i0_wr && (i0_rd == addr);
    i1_byp = i1_wr && (i1_rd == addr);

    if (i0_byp && i1_byp)
      wdata = i1_wins ? i1_data_wb : i0_data_wb;
    else if (i1_byp)
      wdata = i1_data_wb;
    else if (i0_byp)
      wdata = i0_data_wb;
    else
      wdata = stored;
    return wdata;
  endfunction

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
        regs[i0_rd] <= i0_data_wb;
      if (i1_wr && (!same_rd || i1_wins))
        regs[i1_rd] <= i1_data_wb;
    end
  end

endmodule
