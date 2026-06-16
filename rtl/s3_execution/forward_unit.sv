`timescale 1ns / 1ps

// Forward unit (EX) — combinational operand bypass only.
// Replaces stale ID/EX GPR operands when a younger in-flight write targets rs.
// Sources: WB write ports wb0/wb1 only. Younger wpc wins on rd conflicts.
module forward_unit (
  // --- ev0 operands (slot 0 / even copy) ---
  input  logic        ev0_enable,
  input  logic [4:0]  ev0_rs1_addr,
  input  logic [4:0]  ev0_rs2_addr,
  input  logic [31:0] ev0_rs1_data,
  input  logic [31:0] ev0_rs2_data,

  // --- ev1 operands (slot 1 / even copy) ---
  input  logic        ev1_enable,
  input  logic [4:0]  ev1_rs1_addr,
  input  logic [4:0]  ev1_rs2_addr,
  input  logic [31:0] ev1_rs1_data,
  input  logic [31:0] ev1_rs2_data,

  // --- od0 operands (slot 0 / odd copy) ---
  input  logic        od0_enable,
  input  logic [4:0]  od0_rs1_addr,
  input  logic [4:0]  od0_rs2_addr,
  input  logic [31:0] od0_rs1_data,
  input  logic [31:0] od0_rs2_data,

  // --- od1 operands (slot 1 / odd copy) ---
  input  logic        od1_enable,
  input  logic [4:0]  od1_rs1_addr,
  input  logic [4:0]  od1_rs2_addr,
  input  logic [31:0] od1_rs1_data,
  input  logic [31:0] od1_rs2_data,

  // --- WB write ports (slot I0 / I1) ---
  input  logic        wb0_reg_write,
  input  logic [4:0]  wb0_rd_addr,
  input  logic [31:0] wb0_data,
  input  logic [31:0] wb0_pc,

  input  logic        wb1_reg_write,
  input  logic [4:0]  wb1_rd_addr,
  input  logic [31:0] wb1_data,
  input  logic [31:0] wb1_pc,

  // --- Forwarded operands to the lanes ---
  output logic [31:0] ev0_rs1_data_fwd,
  output logic [31:0] ev0_rs2_data_fwd,
  output logic [31:0] ev1_rs1_data_fwd,
  output logic [31:0] ev1_rs2_data_fwd,
  output logic [31:0] od0_rs1_data_fwd,
  output logic [31:0] od0_rs2_data_fwd,
  output logic [31:0] od1_rs1_data_fwd,
  output logic [31:0] od1_rs2_data_fwd
);

  function automatic logic [31:0] youngest_fwd(
    input logic [4:0]  rs_addr,
    input logic [31:0] rs_data
  );
    logic [31:0] y_data;
    logic [31:0] y_pc;
    logic        y_hit;

    y_data = rs_data;
    y_pc   = 32'd0;
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

  function automatic logic [31:0] fwd_port(
    input logic        enable,
    input logic [4:0]  rs_addr,
    input logic [31:0] rs_data
  );
    if (!enable)
      return rs_data;
    return youngest_fwd(rs_addr, rs_data);
  endfunction

  always_comb begin
    ev0_rs1_data_fwd = fwd_port(ev0_enable, ev0_rs1_addr, ev0_rs1_data);
    ev0_rs2_data_fwd = fwd_port(ev0_enable, ev0_rs2_addr, ev0_rs2_data);
    ev1_rs1_data_fwd = fwd_port(ev1_enable, ev1_rs1_addr, ev1_rs1_data);
    ev1_rs2_data_fwd = fwd_port(ev1_enable, ev1_rs2_addr, ev1_rs2_data);
    od0_rs1_data_fwd = fwd_port(od0_enable, od0_rs1_addr, od0_rs1_data);
    od0_rs2_data_fwd = fwd_port(od0_enable, od0_rs2_addr, od0_rs2_data);
    od1_rs1_data_fwd = fwd_port(od1_enable, od1_rs1_addr, od1_rs1_data);
    od1_rs2_data_fwd = fwd_port(od1_enable, od1_rs2_addr, od1_rs2_data);
  end

endmodule
