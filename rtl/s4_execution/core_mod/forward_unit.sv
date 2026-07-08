`timescale 1ns / 1ps

// WB-stage bypass mux for EX operands (wb0/wb1 → ev/od lanes).
// Youngest in-order WB PC wins on rd match; disabled lanes pass through unchanged.
import rv_dis_pkg::*;

module forward_unit (
  // internal controls
  input  logic      ev0_enable,
  input  logic      ev1_enable,
  input  logic      od0_enable,
  input  logic      od1_enable,
  input  logic      wb0_reg_write,
  input  logic      wb1_reg_write,

  // input data
  input  gpr_addr_t ev0_rs1_addr,
  input  gpr_addr_t ev0_rs2_addr,
  input  word_t     ev0_rs1_data,
  input  word_t     ev0_rs2_data,
  input  gpr_addr_t ev1_rs1_addr,
  input  gpr_addr_t ev1_rs2_addr,
  input  word_t     ev1_rs1_data,
  input  word_t     ev1_rs2_data,
  input  gpr_addr_t od0_rs1_addr,
  input  gpr_addr_t od0_rs2_addr,
  input  word_t     od0_rs1_data,
  input  word_t     od0_rs2_data,
  input  gpr_addr_t od1_rs1_addr,
  input  gpr_addr_t od1_rs2_addr,
  input  word_t     od1_rs1_data,
  input  word_t     od1_rs2_data,
  input  gpr_addr_t wb0_rd_addr,
  input  word_t     wb0_data,
  input  word_t     wb0_pc,
  input  gpr_addr_t wb1_rd_addr,
  input  word_t     wb1_data,
  input  word_t     wb1_pc,

  // output data
  output word_t     ev0_rs1_data_fwd,
  output word_t     ev0_rs2_data_fwd,
  output word_t     ev1_rs1_data_fwd,
  output word_t     ev1_rs2_data_fwd,
  output word_t     od0_rs1_data_fwd,
  output word_t     od0_rs2_data_fwd,
  output word_t     od1_rs1_data_fwd,
  output word_t     od1_rs2_data_fwd
);

  function automatic word_t youngest_fwd(
    input logic      lane_enable,
    input gpr_addr_t rs_addr,
    input word_t     rs_data
  );
    word_t y_data;
    word_t y_pc;
    logic  y_hit;

    if (!lane_enable)
      return rs_data;

    y_data = rs_data;
    y_pc   = '0;
    y_hit  = 1'b0;

    if (wb0_reg_write && (wb0_rd_addr == rs_addr)) begin
      y_data = wb0_data;
      y_pc   = wb0_pc;
      y_hit  = 1'b1;
    end
    if (wb1_reg_write && (wb1_rd_addr == rs_addr) &&
        (!y_hit || (wb1_pc >= y_pc))) begin
      y_data = wb1_data;
      y_pc   = wb1_pc;
      y_hit  = 1'b1;
    end

    return y_data;
  endfunction

  assign ev0_rs1_data_fwd = youngest_fwd(ev0_enable, ev0_rs1_addr, ev0_rs1_data);
  assign ev0_rs2_data_fwd = youngest_fwd(ev0_enable, ev0_rs2_addr, ev0_rs2_data);
  assign ev1_rs1_data_fwd = youngest_fwd(ev1_enable, ev1_rs1_addr, ev1_rs1_data);
  assign ev1_rs2_data_fwd = youngest_fwd(ev1_enable, ev1_rs2_addr, ev1_rs2_data);
  assign od0_rs1_data_fwd = youngest_fwd(od0_enable, od0_rs1_addr, od0_rs1_data);
  assign od0_rs2_data_fwd = youngest_fwd(od0_enable, od0_rs2_addr, od0_rs2_data);
  assign od1_rs1_data_fwd = youngest_fwd(od1_enable, od1_rs1_addr, od1_rs1_data);
  assign od1_rs2_data_fwd = youngest_fwd(od1_enable, od1_rs2_addr, od1_rs2_data);

endmodule
