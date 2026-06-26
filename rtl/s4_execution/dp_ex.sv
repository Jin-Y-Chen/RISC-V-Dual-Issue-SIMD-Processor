`timescale 1ns / 1ps

// ID/EX pipeline register — dual-issue lane copies into EX (project_outline §6).
// Hazard / scoreboard / I1 replay live in s3_dispatch (id_dp); this block demuxes and registers.
module dp_ex
  import rv_dis_pkg::*;
(
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  // internal controls
  input  logic        flush,
  input  logic        stall_id,
  input  logic        issue_i0,
  input  logic        issue_i1,

  // input data — gated dispatch bundle from id_dp
  input  logic        i0_valid_id,
  input  logic        i0_lane_sel_id,
  input  logic        i0_reg_write_id,
  input  logic        i1_valid_id,
  input  logic        i1_lane_sel_id,
  input  logic        i1_reg_write_id,
  input  opcode_t     i0_opcode_id,
  input  funct3_t     i0_funct3_id,
  input  funct7_t     i0_funct7_id,
  input  gpr_addr_t   i0_rd_addr_id,
  input  gpr_addr_t   i0_rs1_addr_id,
  input  gpr_addr_t   i0_rs2_addr_id,
  input  imm_t        i0_imm_id,
  input  reg_t        i0_rs1_data_id,
  input  reg_t        i0_rs2_data_id,
  input  pc_t         i0_pc_id,
  input  opcode_t     i1_opcode_id,
  input  funct3_t     i1_funct3_id,
  input  funct7_t     i1_funct7_id,
  input  gpr_addr_t   i1_rd_addr_id,
  input  gpr_addr_t   i1_rs1_addr_id,
  input  gpr_addr_t   i1_rs2_addr_id,
  input  imm_t        i1_imm_id,
  input  reg_t        i1_rs1_data_id,
  input  reg_t        i1_rs2_data_id,
  input  pc_t         i1_pc_id,

  // output controls
  output logic        i0_reg_write_ex,
  output logic        i1_reg_write_ex,
  output logic        ev0_enable_ex,
  output logic        ev1_enable_ex,
  output logic        od0_enable_ex,
  output logic        od1_enable_ex,

  // output data
  output pc_t         i0_pc_ex,
  output pc_t         i1_pc_ex,
  output opcode_t     ev0_opcode_ex,
  output funct3_t     ev0_funct3_ex,
  output funct7_t     ev0_funct7_ex,
  output gpr_addr_t   ev0_rd_ex,
  output gpr_addr_t   ev0_rs1_addr_ex,
  output gpr_addr_t   ev0_rs2_addr_ex,
  output imm_t        ev0_imm_ex,
  output reg_t        ev0_rs1_data_ex,
  output reg_t        ev0_rs2_data_ex,
  output pc_t         ev0_pc_ex,
  output opcode_t     ev1_opcode_ex,
  output funct3_t     ev1_funct3_ex,
  output funct7_t     ev1_funct7_ex,
  output gpr_addr_t   ev1_rd_ex,
  output gpr_addr_t   ev1_rs1_addr_ex,
  output gpr_addr_t   ev1_rs2_addr_ex,
  output imm_t        ev1_imm_ex,
  output reg_t        ev1_rs1_data_ex,
  output reg_t        ev1_rs2_data_ex,
  output pc_t         ev1_pc_ex,
  output opcode_t     od0_opcode_ex,
  output funct3_t     od0_funct3_ex,
  output gpr_addr_t   od0_rd_ex,
  output gpr_addr_t   od0_rs1_addr_ex,
  output gpr_addr_t   od0_rs2_addr_ex,
  output imm_t        od0_imm_ex,
  output reg_t        od0_rs1_data_ex,
  output reg_t        od0_rs2_data_ex,
  output pc_t         od0_pc_ex,
  output opcode_t     od1_opcode_ex,
  output funct3_t     od1_funct3_ex,
  output gpr_addr_t   od1_rd_ex,
  output gpr_addr_t   od1_rs1_addr_ex,
  output gpr_addr_t   od1_rs2_addr_ex,
  output imm_t        od1_imm_ex,
  output reg_t        od1_rs1_data_ex,
  output reg_t        od1_rs2_data_ex,
  output pc_t         od1_pc_ex
);

  wire ev0_enable_next = i0_valid_id && !i0_lane_sel_id;
  wire ev1_enable_next = i1_valid_id && !i1_lane_sel_id;
  wire od0_enable_next = i0_valid_id &&  i0_lane_sel_id;
  wire od1_enable_next = i1_valid_id &&  i1_lane_sel_id;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      i0_reg_write_ex <= 1'b0;
      i1_reg_write_ex <= 1'b0;
      i0_pc_ex        <= '0;
      i1_pc_ex        <= '0;

      ev0_enable_ex   <= 1'b0;
      ev0_opcode_ex   <= '0;
      ev0_funct3_ex   <= '0;
      ev0_funct7_ex   <= '0;
      ev0_rd_ex       <= '0;
      ev0_rs1_addr_ex <= '0;
      ev0_rs2_addr_ex <= '0;
      ev0_imm_ex      <= '0;
      ev0_rs1_data_ex <= '0;
      ev0_rs2_data_ex <= '0;
      ev0_pc_ex       <= '0;

      ev1_enable_ex   <= 1'b0;
      ev1_opcode_ex   <= '0;
      ev1_funct3_ex   <= '0;
      ev1_funct7_ex   <= '0;
      ev1_rd_ex       <= '0;
      ev1_rs1_addr_ex <= '0;
      ev1_rs2_addr_ex <= '0;
      ev1_imm_ex      <= '0;
      ev1_rs1_data_ex <= '0;
      ev1_rs2_data_ex <= '0;
      ev1_pc_ex       <= '0;

      od0_enable_ex   <= 1'b0;
      od0_opcode_ex   <= '0;
      od0_funct3_ex   <= '0;
      od0_rd_ex       <= '0;
      od0_rs1_addr_ex <= '0;
      od0_rs2_addr_ex <= '0;
      od0_imm_ex      <= '0;
      od0_rs1_data_ex <= '0;
      od0_rs2_data_ex <= '0;
      od0_pc_ex       <= '0;

      od1_enable_ex   <= 1'b0;
      od1_opcode_ex   <= '0;
      od1_funct3_ex   <= '0;
      od1_rd_ex       <= '0;
      od1_rs1_addr_ex <= '0;
      od1_rs2_addr_ex <= '0;
      od1_imm_ex      <= '0;
      od1_rs1_data_ex <= '0;
      od1_rs2_data_ex <= '0;
      od1_pc_ex       <= '0;
    end else if (!enable) begin
      // hold all EX lane copies
    end else if (stall_id && !issue_i0 && !issue_i1) begin
      // full stall — hold all lane copies
    end else begin
      if (issue_i0) begin
        i0_reg_write_ex <= i0_reg_write_id &&
                           (ev0_enable_next || od0_enable_next);
        i0_pc_ex        <= i0_pc_id;

        ev0_enable_ex   <= ev0_enable_next;
        ev0_opcode_ex   <= i0_opcode_id;
        ev0_funct3_ex   <= i0_funct3_id;
        ev0_funct7_ex   <= i0_funct7_id;
        ev0_rd_ex       <= i0_rd_addr_id;
        ev0_rs1_addr_ex <= i0_rs1_addr_id;
        ev0_rs2_addr_ex <= i0_rs2_addr_id;
        ev0_imm_ex      <= i0_imm_id;
        ev0_rs1_data_ex <= i0_rs1_data_id;
        ev0_rs2_data_ex <= i0_rs2_data_id;
        ev0_pc_ex       <= i0_pc_id;

        od0_enable_ex   <= od0_enable_next;
        od0_opcode_ex   <= i0_opcode_id;
        od0_funct3_ex   <= i0_funct3_id;
        od0_rd_ex       <= i0_rd_addr_id;
        od0_rs1_addr_ex <= i0_rs1_addr_id;
        od0_rs2_addr_ex <= i0_rs2_addr_id;
        od0_imm_ex      <= i0_imm_id;
        od0_rs1_data_ex <= i0_rs1_data_id;
        od0_rs2_data_ex <= i0_rs2_data_id;
        od0_pc_ex       <= i0_pc_id;
      end else begin
        i0_reg_write_ex <= 1'b0;
        i0_pc_ex        <= '0;
        ev0_enable_ex   <= 1'b0;
        od0_enable_ex   <= 1'b0;
      end

      if (issue_i1) begin
        i1_reg_write_ex <= i1_reg_write_id &&
                           (ev1_enable_next || od1_enable_next);
        i1_pc_ex        <= i1_pc_id;

        ev1_enable_ex   <= ev1_enable_next;
        ev1_opcode_ex   <= i1_opcode_id;
        ev1_funct3_ex   <= i1_funct3_id;
        ev1_funct7_ex   <= i1_funct7_id;
        ev1_rd_ex       <= i1_rd_addr_id;
        ev1_rs1_addr_ex <= i1_rs1_addr_id;
        ev1_rs2_addr_ex <= i1_rs2_addr_id;
        ev1_imm_ex      <= i1_imm_id;
        ev1_rs1_data_ex <= i1_rs1_data_id;
        ev1_rs2_data_ex <= i1_rs2_data_id;
        ev1_pc_ex       <= i1_pc_id;

        od1_enable_ex   <= od1_enable_next;
        od1_opcode_ex   <= i1_opcode_id;
        od1_funct3_ex   <= i1_funct3_id;
        od1_rd_ex       <= i1_rd_addr_id;
        od1_rs1_addr_ex <= i1_rs1_addr_id;
        od1_rs2_addr_ex <= i1_rs2_addr_id;
        od1_imm_ex      <= i1_imm_id;
        od1_rs1_data_ex <= i1_rs1_data_id;
        od1_rs2_data_ex <= i1_rs2_data_id;
        od1_pc_ex       <= i1_pc_id;
      end else begin
        i1_reg_write_ex <= 1'b0;
        i1_pc_ex        <= '0;
        ev1_enable_ex   <= 1'b0;
        od1_enable_ex   <= 1'b0;
      end
    end
  end

endmodule
