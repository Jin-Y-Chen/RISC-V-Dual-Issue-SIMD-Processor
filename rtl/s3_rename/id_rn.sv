`timescale 1ns / 1ps

import rv_dis_pkg::*;

// ID/RN pipeline register — decode bundle latched on posedge before rename core.
// stall holds; flush/rst/!decode_valid => architectural NOP bubble (addi x0, x0, 0).
// Valid is capture-only (not exported). No GPR operand data.
// spec0_en_id/spec1_en_id pack to br_map_rn = {spec1, spec0} for the RAT.
module id_rn (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls (stage)
  input  logic        flush,
  input  logic        stall,

  // internal controls (I0) — from decode / IF-ID
  input  logic        i0_decode_valid,
  input  logic        i0_lane_sel_id,
  input  logic        i0_reg_write_id,
  input  logic        i0_rs1_use_id,
  input  logic        i0_rs2_use_id,
  input  br_state_t   i0_state_id,
  input  logic        spec0_en_id,
  // internal controls (I1)
  input  logic        i1_decode_valid,
  input  logic        i1_lane_sel_id,
  input  logic        i1_reg_write_id,
  input  logic        i1_rs1_use_id,
  input  logic        i1_rs2_use_id,
  input  br_state_t   i1_state_id,
  input  logic        spec1_en_id,

  // input data (I0) — arch addresses / immediate / PC
  input  opcode_t     i0_opcode_id,
  input  funct3_t     i0_funct3_id,
  input  funct7_t     i0_funct7_id,
  input  gpr_addr_t   i0_rd_addr_id,
  input  gpr_addr_t   i0_rs1_addr_id,
  input  gpr_addr_t   i0_rs2_addr_id,
  input  word_t       i0_imm_id,
  input  word_t       i0_pc_id,

  // input data (I1)
  input  opcode_t     i1_opcode_id,
  input  funct3_t     i1_funct3_id,
  input  funct7_t     i1_funct7_id,
  input  gpr_addr_t   i1_rd_addr_id,
  input  gpr_addr_t   i1_rs1_addr_id,
  input  gpr_addr_t   i1_rs2_addr_id,
  input  word_t       i1_imm_id,
  input  word_t       i1_pc_id,

  // output controls (I0) → rename_core_struct
  output logic        i0_lane_sel_rn,
  output logic        i0_reg_write_rn,
  output logic        i0_rs1_use_rn,
  output logic        i0_rs2_use_rn,
  output br_state_t   i0_state_rn,

  // output controls (I1)
  output logic        i1_lane_sel_rn,
  output logic        i1_reg_write_rn,
  output logic        i1_rs1_use_rn,
  output logic        i1_rs2_use_rn,
  output br_state_t   i1_state_rn,

  output br_map_t     br_map_rn,

  // output data (I0)
  output opcode_t     i0_opcode_rn,
  output funct3_t     i0_funct3_rn,
  output funct7_t     i0_funct7_rn,
  output gpr_addr_t   i0_rd_addr_rn,
  output gpr_addr_t   i0_rs1_addr_rn,
  output gpr_addr_t   i0_rs2_addr_rn,
  output word_t       i0_imm_rn,
  output word_t       i0_pc_rn,

  // output data (I1)
  output opcode_t     i1_opcode_rn,
  output funct3_t     i1_funct3_rn,
  output funct7_t     i1_funct7_rn,
  output gpr_addr_t   i1_rd_addr_rn,
  output gpr_addr_t   i1_rs1_addr_rn,
  output gpr_addr_t   i1_rs2_addr_rn,
  output word_t       i1_imm_rn,
  output word_t       i1_pc_rn
);

  // Decoded fields for INSTR_NOP = addi x0, x0, 0.
  localparam opcode_t   NOP_OPCODE    = OPC_OP_IMM;
  localparam funct3_t   NOP_FUNCT3    = 3'b000;
  localparam funct7_t   NOP_FUNCT7    = 7'b0000000;
  localparam gpr_addr_t NOP_REG       = 5'd0;
  localparam logic      NOP_LANE_SEL  = 1'b0;
  localparam logic      NOP_REG_WRITE = 1'b0;
  localparam logic      NOP_RS1_USE   = 1'b1;  // ADDI reads rs1 (=x0)
  localparam logic      NOP_RS2_USE   = 1'b0;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i0_lane_sel_rn   <= NOP_LANE_SEL;
      i0_reg_write_rn  <= NOP_REG_WRITE;
      i0_rs1_use_rn    <= NOP_RS1_USE;
      i0_rs2_use_rn    <= NOP_RS2_USE;
      i0_state_rn      <= '0;
      i0_opcode_rn     <= NOP_OPCODE;
      i0_funct3_rn     <= NOP_FUNCT3;
      i0_funct7_rn     <= NOP_FUNCT7;
      i0_rd_addr_rn    <= NOP_REG;
      i0_rs1_addr_rn   <= NOP_REG;
      i0_rs2_addr_rn   <= NOP_REG;
      i0_imm_rn        <= '0;
      i0_pc_rn         <= '0;

      i1_lane_sel_rn   <= NOP_LANE_SEL;
      i1_reg_write_rn  <= NOP_REG_WRITE;
      i1_rs1_use_rn    <= NOP_RS1_USE;
      i1_rs2_use_rn    <= NOP_RS2_USE;
      i1_state_rn      <= '0;
      i1_opcode_rn     <= NOP_OPCODE;
      i1_funct3_rn     <= NOP_FUNCT3;
      i1_funct7_rn     <= NOP_FUNCT7;
      i1_rd_addr_rn    <= NOP_REG;
      i1_rs1_addr_rn   <= NOP_REG;
      i1_rs2_addr_rn   <= NOP_REG;
      i1_imm_rn        <= '0;
      i1_pc_rn         <= '0;
      br_map_rn        <= BR_MAP_NONE;
    end else if (flush) begin
      i0_lane_sel_rn   <= NOP_LANE_SEL;
      i0_reg_write_rn  <= NOP_REG_WRITE;
      i0_rs1_use_rn    <= NOP_RS1_USE;
      i0_rs2_use_rn    <= NOP_RS2_USE;
      i0_state_rn      <= '0;
      i0_opcode_rn     <= NOP_OPCODE;
      i0_funct3_rn     <= NOP_FUNCT3;
      i0_funct7_rn     <= NOP_FUNCT7;
      i0_rd_addr_rn    <= NOP_REG;
      i0_rs1_addr_rn   <= NOP_REG;
      i0_rs2_addr_rn   <= NOP_REG;
      i0_imm_rn        <= '0;
      i0_pc_rn         <= '0;

      i1_lane_sel_rn   <= NOP_LANE_SEL;
      i1_reg_write_rn  <= NOP_REG_WRITE;
      i1_rs1_use_rn    <= NOP_RS1_USE;
      i1_rs2_use_rn    <= NOP_RS2_USE;
      i1_state_rn      <= '0;
      i1_opcode_rn     <= NOP_OPCODE;
      i1_funct3_rn     <= NOP_FUNCT3;
      i1_funct7_rn     <= NOP_FUNCT7;
      i1_rd_addr_rn    <= NOP_REG;
      i1_rs1_addr_rn   <= NOP_REG;
      i1_rs2_addr_rn   <= NOP_REG;
      i1_imm_rn        <= '0;
      i1_pc_rn         <= '0;
      br_map_rn        <= BR_MAP_NONE;
    end else if (enable && !stall) begin
      if (i0_decode_valid) begin
        i0_lane_sel_rn   <= i0_lane_sel_id;
        i0_reg_write_rn  <= i0_reg_write_id;
        i0_rs1_use_rn    <= i0_rs1_use_id;
        i0_rs2_use_rn    <= i0_rs2_use_id;
        i0_state_rn      <= i0_state_id;
        i0_opcode_rn     <= i0_opcode_id;
        i0_funct3_rn     <= i0_funct3_id;
        i0_funct7_rn     <= i0_funct7_id;
        i0_rd_addr_rn    <= i0_rd_addr_id;
        i0_rs1_addr_rn   <= i0_rs1_addr_id;
        i0_rs2_addr_rn   <= i0_rs2_addr_id;
        i0_imm_rn        <= i0_imm_id;
        i0_pc_rn         <= i0_pc_id;
      end else begin
        // decode_valid=0 => NOP bubble
        i0_lane_sel_rn   <= NOP_LANE_SEL;
        i0_reg_write_rn  <= NOP_REG_WRITE;
        i0_rs1_use_rn    <= NOP_RS1_USE;
        i0_rs2_use_rn    <= NOP_RS2_USE;
        i0_state_rn      <= '0;
        i0_opcode_rn     <= NOP_OPCODE;
        i0_funct3_rn     <= NOP_FUNCT3;
        i0_funct7_rn     <= NOP_FUNCT7;
        i0_rd_addr_rn    <= NOP_REG;
        i0_rs1_addr_rn   <= NOP_REG;
        i0_rs2_addr_rn   <= NOP_REG;
        i0_imm_rn        <= '0;
        i0_pc_rn         <= '0;
      end

      if (i1_decode_valid) begin
        i1_lane_sel_rn   <= i1_lane_sel_id;
        i1_reg_write_rn  <= i1_reg_write_id;
        i1_rs1_use_rn    <= i1_rs1_use_id;
        i1_rs2_use_rn    <= i1_rs2_use_id;
        i1_state_rn      <= i1_state_id;
        i1_opcode_rn     <= i1_opcode_id;
        i1_funct3_rn     <= i1_funct3_id;
        i1_funct7_rn     <= i1_funct7_id;
        i1_rd_addr_rn    <= i1_rd_addr_id;
        i1_rs1_addr_rn   <= i1_rs1_addr_id;
        i1_rs2_addr_rn   <= i1_rs2_addr_id;
        i1_imm_rn        <= i1_imm_id;
        i1_pc_rn         <= i1_pc_id;
      end else begin
        i1_lane_sel_rn   <= NOP_LANE_SEL;
        i1_reg_write_rn  <= NOP_REG_WRITE;
        i1_rs1_use_rn    <= NOP_RS1_USE;
        i1_rs2_use_rn    <= NOP_RS2_USE;
        i1_state_rn      <= '0;
        i1_opcode_rn     <= NOP_OPCODE;
        i1_funct3_rn     <= NOP_FUNCT3;
        i1_funct7_rn     <= NOP_FUNCT7;
        i1_rd_addr_rn    <= NOP_REG;
        i1_rs1_addr_rn   <= NOP_REG;
        i1_rs2_addr_rn   <= NOP_REG;
        i1_imm_rn        <= '0;
        i1_pc_rn         <= '0;
      end

      // Only valid lanes contribute speculation bits.
      br_map_rn <= {i1_decode_valid & spec1_en_id, i0_decode_valid & spec0_en_id};
    end
  end

endmodule
