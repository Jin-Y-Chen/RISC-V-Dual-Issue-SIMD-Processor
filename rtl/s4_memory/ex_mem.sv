`timescale 1ns / 1ps

// EX/MEM pipeline register — four lane copies (ev0, ev1, od0, od1).
// ev* carry even-lane ALU results; od* carry mem/branch/jump/U-type payloads.
// enable qualifies reg_write_mem per copy (slot dispatched to that lane only).
module ex_mem (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        stall_ev0,
  input  logic        stall_ev1,
  input  logic        stall_od0,
  input  logic        stall_od1,

  // --- ev0 (I0 / even copy) ---
  input  logic        ev0_enable_ex,
  input  logic        ev0_reg_write_ex,
  input  logic [4:0]  ev0_rd_ex,
  input  logic [31:0] ev0_alu_result_ex,
  input  logic [31:0] ev0_pc_ex,

  output logic        ev0_reg_write_mem,
  output logic [4:0]  ev0_rd_mem,
  output logic [31:0] ev0_alu_result_mem,
  output logic [31:0] ev0_pc_mem,

  // --- ev1 (I1 / even copy) ---
  input  logic        ev1_enable_ex,
  input  logic        ev1_reg_write_ex,
  input  logic [4:0]  ev1_rd_ex,
  input  logic [31:0] ev1_alu_result_ex,
  input  logic [31:0] ev1_pc_ex,

  output logic        ev1_reg_write_mem,
  output logic [4:0]  ev1_rd_mem,
  output logic [31:0] ev1_alu_result_mem,
  output logic [31:0] ev1_pc_mem,

  // --- od0 (I0 / odd copy) ---
  input  logic        od0_enable_ex,
  input  logic        od0_reg_write_ex,
  input  logic [4:0]  od0_rd_ex,
  input  logic        od0_brch_taken_ex,
  input  logic [31:0] od0_brch_pc_ex,
  input  logic        od0_mem_en_ex,
  input  logic        od0_mem_act_ex,
  input  logic [31:0] od0_mem_addr_ex,
  input  logic [31:0] od0_mem_wdata_ex,
  input  logic [3:0]  od0_mem_besel_ex,
  input  logic [31:0] od0_link_pc_ex,
  input  logic [31:0] od0_alu_result_ex,
  input  logic [31:0] od0_pc_ex,

  output logic        od0_reg_write_mem,
  output logic [4:0]  od0_rd_mem,
  output logic        od0_brch_taken_mem,
  output logic [31:0] od0_brch_pc_mem,
  output logic        od0_mem_en_mem,
  output logic        od0_mem_act_mem,
  output logic [31:0] od0_mem_addr_mem,
  output logic [31:0] od0_mem_wdata_mem,
  output logic [3:0]  od0_mem_besel_mem,
  output logic [31:0] od0_link_pc_mem,
  output logic [31:0] od0_alu_result_mem,
  output logic [31:0] od0_pc_mem,

  // --- od1 (I1 / odd copy) ---
  input  logic        od1_enable_ex,
  input  logic        od1_reg_write_ex,
  input  logic [4:0]  od1_rd_ex,
  input  logic        od1_brch_taken_ex,
  input  logic [31:0] od1_brch_pc_ex,
  input  logic        od1_mem_en_ex,
  input  logic        od1_mem_act_ex,
  input  logic [31:0] od1_mem_addr_ex,
  input  logic [31:0] od1_mem_wdata_ex,
  input  logic [3:0]  od1_mem_besel_ex,
  input  logic [31:0] od1_link_pc_ex,
  input  logic [31:0] od1_alu_result_ex,
  input  logic [31:0] od1_pc_ex,

  output logic        od1_reg_write_mem,
  output logic [4:0]  od1_rd_mem,
  output logic        od1_brch_taken_mem,
  output logic [31:0] od1_brch_pc_mem,
  output logic        od1_mem_en_mem,
  output logic        od1_mem_act_mem,
  output logic [31:0] od1_mem_addr_mem,
  output logic [31:0] od1_mem_wdata_mem,
  output logic [3:0]  od1_mem_besel_mem,
  output logic [31:0] od1_link_pc_mem,
  output logic [31:0] od1_alu_result_mem,
  output logic [31:0] od1_pc_mem
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ev0_reg_write_mem  <= 1'b0;
      ev0_rd_mem         <= 5'd0;
      ev0_alu_result_mem <= 32'd0;
      ev0_pc_mem         <= 32'd0;

      ev1_reg_write_mem  <= 1'b0;
      ev1_rd_mem         <= 5'd0;
      ev1_alu_result_mem <= 32'd0;
      ev1_pc_mem         <= 32'd0;

      od0_reg_write_mem  <= 1'b0;
      od0_rd_mem         <= 5'd0;
      od0_brch_taken_mem <= 1'b0;
      od0_brch_pc_mem    <= 32'd0;
      od0_mem_en_mem     <= 1'b0;
      od0_mem_act_mem    <= 1'b0;
      od0_mem_addr_mem   <= 32'd0;
      od0_mem_wdata_mem  <= 32'd0;
      od0_mem_besel_mem  <= 4'd0;
      od0_link_pc_mem    <= 32'd0;
      od0_alu_result_mem <= 32'd0;
      od0_pc_mem         <= 32'd0;

      od1_reg_write_mem  <= 1'b0;
      od1_rd_mem         <= 5'd0;
      od1_brch_taken_mem <= 1'b0;
      od1_brch_pc_mem    <= 32'd0;
      od1_mem_en_mem     <= 1'b0;
      od1_mem_act_mem    <= 1'b0;
      od1_mem_addr_mem   <= 32'd0;
      od1_mem_wdata_mem  <= 32'd0;
      od1_mem_besel_mem  <= 4'd0;
      od1_link_pc_mem    <= 32'd0;
      od1_alu_result_mem <= 32'd0;
      od1_pc_mem         <= 32'd0;
    end else begin
      if (!stall_ev0) begin
        ev0_reg_write_mem  <= ev0_enable_ex && ev0_reg_write_ex;
        ev0_rd_mem         <= ev0_rd_ex;
        ev0_alu_result_mem <= ev0_alu_result_ex;
        ev0_pc_mem         <= ev0_pc_ex;
      end

      if (!stall_ev1) begin
        ev1_reg_write_mem  <= ev1_enable_ex && ev1_reg_write_ex;
        ev1_rd_mem         <= ev1_rd_ex;
        ev1_alu_result_mem <= ev1_alu_result_ex;
        ev1_pc_mem         <= ev1_pc_ex;
      end

      if (!stall_od0) begin
        od0_reg_write_mem  <= od0_enable_ex && od0_reg_write_ex;
        od0_rd_mem         <= od0_rd_ex;
        od0_brch_taken_mem <= od0_brch_taken_ex;
        od0_brch_pc_mem    <= od0_brch_pc_ex;
        od0_mem_en_mem     <= od0_mem_en_ex;
        od0_mem_act_mem    <= od0_mem_act_ex;
        od0_mem_addr_mem   <= od0_mem_addr_ex;
        od0_mem_wdata_mem  <= od0_mem_wdata_ex;
        od0_mem_besel_mem  <= od0_mem_besel_ex;
        od0_link_pc_mem    <= od0_link_pc_ex;
        od0_alu_result_mem <= od0_alu_result_ex;
        od0_pc_mem         <= od0_pc_ex;
      end

      if (!stall_od1) begin
        od1_reg_write_mem  <= od1_enable_ex && od1_reg_write_ex;
        od1_rd_mem         <= od1_rd_ex;
        od1_brch_taken_mem <= od1_brch_taken_ex;
        od1_brch_pc_mem    <= od1_brch_pc_ex;
        od1_mem_en_mem     <= od1_mem_en_ex;
        od1_mem_act_mem    <= od1_mem_act_ex;
        od1_mem_addr_mem   <= od1_mem_addr_ex;
        od1_mem_wdata_mem  <= od1_mem_wdata_ex;
        od1_mem_besel_mem  <= od1_mem_besel_ex;
        od1_link_pc_mem    <= od1_link_pc_ex;
        od1_alu_result_mem <= od1_alu_result_ex;
        od1_pc_mem         <= od1_pc_ex;
      end
    end
  end

endmodule
