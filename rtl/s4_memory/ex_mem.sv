`timescale 1ns / 1ps

// EX/MEM pipeline register — odd-lane copies only (od0, od1).
// Even-lane ALU skips this register; uses ex_mem_wb EX bank instead.
module ex_mem
  import rv_dis_pkg::*;
(
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls
  input  logic        stall_od0,
  input  logic        stall_od1,
  input  logic        od0_enable_ex,
  input  logic        od0_reg_write_ex,
  input  logic        od0_brch_taken_ex,
  input  logic        od0_mem_en_ex,
  input  logic        od0_mem_act_ex,
  input  logic        od0_use_link_ex,
  input  logic        od1_enable_ex,
  input  logic        od1_reg_write_ex,
  input  logic        od1_brch_taken_ex,
  input  logic        od1_mem_en_ex,
  input  logic        od1_mem_act_ex,
  input  logic        od1_use_link_ex,

  // input data
  input  gpr_addr_t   od0_rd_ex,
  input  word_t         od0_brch_pc_ex,
  input  word_t         od0_mem_addr_ex,
  input  word_t        od0_mem_wdata_ex,
  input  mem_besel_t  od0_mem_besel_ex,
  input  word_t         od0_link_pc_ex,
  input  word_t        od0_alu_result_ex,
  input  word_t         od0_pc_ex,
  input  gpr_addr_t   od1_rd_ex,
  input  word_t         od1_brch_pc_ex,
  input  word_t         od1_mem_addr_ex,
  input  word_t        od1_mem_wdata_ex,
  input  mem_besel_t  od1_mem_besel_ex,
  input  word_t         od1_link_pc_ex,
  input  word_t        od1_alu_result_ex,
  input  word_t         od1_pc_ex,

  // output controls
  output logic        od0_reg_write_mem,
  output logic        od0_brch_taken_mem,
  output logic        od0_mem_en_mem,
  output logic        od0_mem_act_mem,
  output logic        od0_use_link_mem,
  output logic        od1_reg_write_mem,
  output logic        od1_brch_taken_mem,
  output logic        od1_mem_en_mem,
  output logic        od1_mem_act_mem,
  output logic        od1_use_link_mem,

  // output data
  output gpr_addr_t   od0_rd_mem,
  output word_t         od0_brch_pc_mem,
  output word_t         od0_mem_addr_mem,
  output word_t        od0_mem_wdata_mem,
  output mem_besel_t  od0_mem_besel_mem,
  output word_t         od0_link_pc_mem,
  output word_t        od0_alu_result_mem,
  output word_t         od0_pc_mem,
  output gpr_addr_t   od1_rd_mem,
  output word_t         od1_brch_pc_mem,
  output word_t         od1_mem_addr_mem,
  output word_t        od1_mem_wdata_mem,
  output mem_besel_t  od1_mem_besel_mem,
  output word_t         od1_link_pc_mem,
  output word_t        od1_alu_result_mem,
  output word_t         od1_pc_mem
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
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
      od0_use_link_mem   <= 1'b0;
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
      od1_use_link_mem   <= 1'b0;
      od1_pc_mem         <= 32'd0;
    end else begin
      if (enable && !stall_od0) begin
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
        od0_use_link_mem   <= od0_use_link_ex;
        od0_pc_mem         <= od0_pc_ex;
      end

      if (enable && !stall_od1) begin
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
        od1_use_link_mem   <= od1_use_link_ex;
        od1_pc_mem         <= od1_pc_ex;
      end
    end
  end

endmodule
