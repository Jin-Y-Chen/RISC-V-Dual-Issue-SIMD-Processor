`timescale 1ns / 1ps

import rv_dis_pkg::*;
import rob_rename_pkg::*;

// S4 execute — even/odd reservation stations (each with WB forwarding) + four lanes.
// dp_ex feeds RS enqueue; RS issue drives combinational EX (operands already forwarded).
module s4_execute_struct (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,

  // internal controls — from dp_ex (enqueue side of RS)
  input  logic        i0_reg_write_ex,
  input  logic        i1_reg_write_ex,
  input  logic        ev0_enable_ex,
  input  logic        ev1_enable_ex,
  input  logic        od0_enable_ex,
  input  logic        od1_enable_ex,
  input  logic        wb0_reg_write,
  input  logic        wb1_reg_write,

  // input data
  input  word_t         i0_pc_ex,
  input  word_t         i1_pc_ex,
  input  opcode_t     ev0_opcode_ex,
  input  funct3_t     ev0_funct3_ex,
  input  funct7_t     ev0_funct7_ex,
  input  gpr_addr_t   ev0_rd_ex,
  input  gpr_addr_t   ev0_rs1_addr_ex,
  input  gpr_addr_t   ev0_rs2_addr_ex,
  input  word_t        ev0_imm_ex,
  input  word_t        ev0_rs1_data_ex,
  input  word_t        ev0_rs2_data_ex,
  input  word_t         ev0_pc_ex,
  input  opcode_t     ev1_opcode_ex,
  input  funct3_t     ev1_funct3_ex,
  input  funct7_t     ev1_funct7_ex,
  input  gpr_addr_t   ev1_rd_ex,
  input  gpr_addr_t   ev1_rs1_addr_ex,
  input  gpr_addr_t   ev1_rs2_addr_ex,
  input  word_t        ev1_imm_ex,
  input  word_t        ev1_rs1_data_ex,
  input  word_t        ev1_rs2_data_ex,
  input  word_t         ev1_pc_ex,
  input  opcode_t     od0_opcode_ex,
  input  funct3_t     od0_funct3_ex,
  input  gpr_addr_t   od0_rd_ex,
  input  gpr_addr_t   od0_rs1_addr_ex,
  input  gpr_addr_t   od0_rs2_addr_ex,
  input  word_t        od0_imm_ex,
  input  word_t        od0_rs1_data_ex,
  input  word_t        od0_rs2_data_ex,
  input  word_t         od0_pc_ex,
  input  opcode_t     od1_opcode_ex,
  input  funct3_t     od1_funct3_ex,
  input  gpr_addr_t   od1_rd_ex,
  input  gpr_addr_t   od1_rs1_addr_ex,
  input  gpr_addr_t   od1_rs2_addr_ex,
  input  word_t        od1_imm_ex,
  input  word_t        od1_rs1_data_ex,
  input  word_t        od1_rs2_data_ex,
  input  word_t         od1_pc_ex,
  input  gpr_addr_t   wb0_rd_addr,
  input  word_t        wb0_data,
  input  word_t         wb0_pc,
  input  gpr_addr_t   wb1_rd_addr,
  input  word_t        wb1_data,
  input  word_t         wb1_pc,

  // output controls
  output logic        od0_use_link_ex,
  output logic        od1_use_link_ex,
  output logic        od0_brch_taken,
  output logic        od0_mem_en,
  output logic        od0_mem_write,
  output logic        od1_brch_taken,
  output logic        od1_mem_en,
  output logic        od1_mem_write,

  // output data
  output word_t        ev0_alu_result,
  output word_t        ev1_alu_result,
  output word_t         od0_brch_pc,
  output word_t         od0_mem_addr,
  output word_t        od0_mem_wdata,
  output mem_besel_t  od0_mem_besel,
  output word_t         od0_link_pc,
  output word_t        od0_alu_result,
  output word_t         od1_brch_pc,
  output word_t         od1_mem_addr,
  output word_t        od1_mem_wdata,
  output mem_besel_t  od1_mem_besel,
  output word_t         od1_link_pc,
  output word_t        od1_alu_result
);

  logic        rs_ev0_enable_ex;
  logic        rs_ev1_enable_ex;
  logic        rs_od0_enable_ex;
  logic        rs_od1_enable_ex;
  opcode_t     rs_ev0_opcode_ex;
  funct3_t     rs_ev0_funct3_ex;
  funct7_t     rs_ev0_funct7_ex;
  word_t       rs_ev0_imm_ex;
  word_t       rs_ev0_rs1_data_ex;
  word_t       rs_ev0_rs2_data_ex;
  opcode_t     rs_ev1_opcode_ex;
  funct3_t     rs_ev1_funct3_ex;
  funct7_t     rs_ev1_funct7_ex;
  word_t       rs_ev1_imm_ex;
  word_t       rs_ev1_rs1_data_ex;
  word_t       rs_ev1_rs2_data_ex;
  opcode_t     rs_od0_opcode_ex;
  funct3_t     rs_od0_funct3_ex;
  word_t       rs_od0_imm_ex;
  word_t       rs_od0_rs1_data_ex;
  word_t       rs_od0_rs2_data_ex;
  word_t       rs_od0_pc_ex;
  opcode_t     rs_od1_opcode_ex;
  funct3_t     rs_od1_funct3_ex;
  word_t       rs_od1_imm_ex;
  word_t       rs_od1_rs1_data_ex;
  word_t       rs_od1_rs2_data_ex;
  word_t       rs_od1_pc_ex;

  // Parent-owned RS storage — each RS updates via ref; peer side reads for RAW.
  rs_entry_t ev0_bank [0:RS_DEPTH-1];
  rs_entry_t ev1_bank [0:RS_DEPTH-1];
  rs_entry_t od0_bank [0:RS_DEPTH-1];
  rs_entry_t od1_bank [0:RS_DEPTH-1];

  reservation_station #(
    .IS_ODD(1'b0)
  ) u_rs_even (
    .clk               (clk),
    .rst_n             (rst_n),
    .enable            (enable),
    .flush             (flush),
    .i0_reg_write_disp (i0_reg_write_ex),
    .i1_reg_write_disp (i1_reg_write_ex),
    .i0_pc_disp        (i0_pc_ex),
    .i1_pc_disp        (i1_pc_ex),
    .i0_reg_write_ex   (),
    .i1_reg_write_ex   (),
    .i0_pc_ex          (),
    .i1_pc_ex          (),
    .s0_enable_disp    (ev0_enable_ex),
    .s0_opcode_disp    (ev0_opcode_ex),
    .s0_funct3_disp    (ev0_funct3_ex),
    .s0_funct7_disp    (ev0_funct7_ex),
    .s0_rd_disp        (ev0_rd_ex),
    .s0_rs1_addr_disp  (ev0_rs1_addr_ex),
    .s0_rs2_addr_disp  (ev0_rs2_addr_ex),
    .s0_imm_disp       (ev0_imm_ex),
    .s0_rs1_data_disp  (ev0_rs1_data_ex),
    .s0_rs2_data_disp  (ev0_rs2_data_ex),
    .s0_pc_disp        (ev0_pc_ex),
    .s1_enable_disp    (ev1_enable_ex),
    .s1_opcode_disp    (ev1_opcode_ex),
    .s1_funct3_disp    (ev1_funct3_ex),
    .s1_funct7_disp    (ev1_funct7_ex),
    .s1_rd_disp        (ev1_rd_ex),
    .s1_rs1_addr_disp  (ev1_rs1_addr_ex),
    .s1_rs2_addr_disp  (ev1_rs2_addr_ex),
    .s1_imm_disp       (ev1_imm_ex),
    .s1_rs1_data_disp  (ev1_rs1_data_ex),
    .s1_rs2_data_disp  (ev1_rs2_data_ex),
    .s1_pc_disp        (ev1_pc_ex),
    .wb0_reg_write     (wb0_reg_write),
    .wb0_rd_addr       (wb0_rd_addr),
    .wb0_data          (wb0_data),
    .wb0_pc            (wb0_pc),
    .wb1_reg_write     (wb1_reg_write),
    .wb1_rd_addr       (wb1_rd_addr),
    .wb1_data          (wb1_data),
    .wb1_pc            (wb1_pc),
    .peer0_bank        (od0_bank),
    .peer1_bank        (od1_bank),
    .bank0             (ev0_bank),
    .bank1             (ev1_bank),
    .s0_enable_ex      (rs_ev0_enable_ex),
    .s0_opcode_ex      (rs_ev0_opcode_ex),
    .s0_funct3_ex      (rs_ev0_funct3_ex),
    .s0_funct7_ex      (rs_ev0_funct7_ex),
    .s0_rd_ex          (),
    .s0_rs1_addr_ex    (),
    .s0_rs2_addr_ex    (),
    .s0_imm_ex         (rs_ev0_imm_ex),
    .s0_rs1_data_ex    (rs_ev0_rs1_data_ex),
    .s0_rs2_data_ex    (rs_ev0_rs2_data_ex),
    .s0_pc_ex          (),
    .s1_enable_ex      (rs_ev1_enable_ex),
    .s1_opcode_ex      (rs_ev1_opcode_ex),
    .s1_funct3_ex      (rs_ev1_funct3_ex),
    .s1_funct7_ex      (rs_ev1_funct7_ex),
    .s1_rd_ex          (),
    .s1_rs1_addr_ex    (),
    .s1_rs2_addr_ex    (),
    .s1_imm_ex         (rs_ev1_imm_ex),
    .s1_rs1_data_ex    (rs_ev1_rs1_data_ex),
    .s1_rs2_data_ex    (rs_ev1_rs2_data_ex),
    .s1_pc_ex          ()
  );

  reservation_station #(
    .IS_ODD(1'b1)
  ) u_rs_odd (
    .clk               (clk),
    .rst_n             (rst_n),
    .enable            (enable),
    .flush             (flush),
    .i0_reg_write_disp (i0_reg_write_ex),
    .i1_reg_write_disp (i1_reg_write_ex),
    .i0_pc_disp        (i0_pc_ex),
    .i1_pc_disp        (i1_pc_ex),
    .i0_reg_write_ex   (),
    .i1_reg_write_ex   (),
    .i0_pc_ex          (),
    .i1_pc_ex          (),
    .s0_enable_disp    (od0_enable_ex),
    .s0_opcode_disp    (od0_opcode_ex),
    .s0_funct3_disp    (od0_funct3_ex),
    .s0_funct7_disp    (7'd0),
    .s0_rd_disp        (od0_rd_ex),
    .s0_rs1_addr_disp  (od0_rs1_addr_ex),
    .s0_rs2_addr_disp  (od0_rs2_addr_ex),
    .s0_imm_disp       (od0_imm_ex),
    .s0_rs1_data_disp  (od0_rs1_data_ex),
    .s0_rs2_data_disp  (od0_rs2_data_ex),
    .s0_pc_disp        (od0_pc_ex),
    .s1_enable_disp    (od1_enable_ex),
    .s1_opcode_disp    (od1_opcode_ex),
    .s1_funct3_disp    (od1_funct3_ex),
    .s1_funct7_disp    (7'd0),
    .s1_rd_disp        (od1_rd_ex),
    .s1_rs1_addr_disp  (od1_rs1_addr_ex),
    .s1_rs2_addr_disp  (od1_rs2_addr_ex),
    .s1_imm_disp       (od1_imm_ex),
    .s1_rs1_data_disp  (od1_rs1_data_ex),
    .s1_rs2_data_disp  (od1_rs2_data_ex),
    .s1_pc_disp        (od1_pc_ex),
    .wb0_reg_write     (wb0_reg_write),
    .wb0_rd_addr       (wb0_rd_addr),
    .wb0_data          (wb0_data),
    .wb0_pc            (wb0_pc),
    .wb1_reg_write     (wb1_reg_write),
    .wb1_rd_addr       (wb1_rd_addr),
    .wb1_data          (wb1_data),
    .wb1_pc            (wb1_pc),
    .peer0_bank        (ev0_bank),
    .peer1_bank        (ev1_bank),
    .bank0             (od0_bank),
    .bank1             (od1_bank),
    .s0_enable_ex      (rs_od0_enable_ex),
    .s0_opcode_ex      (rs_od0_opcode_ex),
    .s0_funct3_ex      (rs_od0_funct3_ex),
    .s0_funct7_ex      (),
    .s0_rd_ex          (),
    .s0_rs1_addr_ex    (),
    .s0_rs2_addr_ex    (),
    .s0_imm_ex         (rs_od0_imm_ex),
    .s0_rs1_data_ex    (rs_od0_rs1_data_ex),
    .s0_rs2_data_ex    (rs_od0_rs2_data_ex),
    .s0_pc_ex          (rs_od0_pc_ex),
    .s1_enable_ex      (rs_od1_enable_ex),
    .s1_opcode_ex      (rs_od1_opcode_ex),
    .s1_funct3_ex      (rs_od1_funct3_ex),
    .s1_funct7_ex      (),
    .s1_rd_ex          (),
    .s1_rs1_addr_ex    (),
    .s1_rs2_addr_ex    (),
    .s1_imm_ex         (rs_od1_imm_ex),
    .s1_rs1_data_ex    (rs_od1_rs1_data_ex),
    .s1_rs2_data_ex    (rs_od1_rs2_data_ex),
    .s1_pc_ex          (rs_od1_pc_ex)
  );

  assign od0_use_link_ex = rs_od0_enable_ex &&
                           ((rs_od0_opcode_ex == OPC_JAL) || (rs_od0_opcode_ex == OPC_JALR));
  assign od1_use_link_ex = rs_od1_enable_ex &&
                           ((rs_od1_opcode_ex == OPC_JAL) || (rs_od1_opcode_ex == OPC_JALR));

  even_lane u_ev0 (
    .enable     (rs_ev0_enable_ex),
    .opcode     (rs_ev0_opcode_ex),
    .funct3     (rs_ev0_funct3_ex),
    .funct7     (rs_ev0_funct7_ex),
    .rs1_data   (rs_ev0_rs1_data_ex),
    .rs2_data   (rs_ev0_rs2_data_ex),
    .imm        (rs_ev0_imm_ex),
    .reg_write  (),
    .alu_result (ev0_alu_result)
  );

  even_lane u_ev1 (
    .enable     (rs_ev1_enable_ex),
    .opcode     (rs_ev1_opcode_ex),
    .funct3     (rs_ev1_funct3_ex),
    .funct7     (rs_ev1_funct7_ex),
    .rs1_data   (rs_ev1_rs1_data_ex),
    .rs2_data   (rs_ev1_rs2_data_ex),
    .imm        (rs_ev1_imm_ex),
    .reg_write  (),
    .alu_result (ev1_alu_result)
  );

  odd_lane u_od0 (
    .enable     (rs_od0_enable_ex),
    .opcode     (rs_od0_opcode_ex),
    .funct3     (rs_od0_funct3_ex),
    .rs1_data   (rs_od0_rs1_data_ex),
    .rs2_data   (rs_od0_rs2_data_ex),
    .imm        (rs_od0_imm_ex),
    .pc         (rs_od0_pc_ex),
    .brch_taken (od0_brch_taken),
    .mem_en     (od0_mem_en),
    .mem_write  (od0_mem_write),
    .brch_pc    (od0_brch_pc),
    .mem_addr   (od0_mem_addr),
    .mem_wdata  (od0_mem_wdata),
    .mem_besel  (od0_mem_besel),
    .link_pc    (od0_link_pc),
    .reg_wdata  (od0_alu_result)
  );

  odd_lane u_od1 (
    .enable     (rs_od1_enable_ex),
    .opcode     (rs_od1_opcode_ex),
    .funct3     (rs_od1_funct3_ex),
    .rs1_data   (rs_od1_rs1_data_ex),
    .rs2_data   (rs_od1_rs2_data_ex),
    .imm        (rs_od1_imm_ex),
    .pc         (rs_od1_pc_ex),
    .brch_taken (od1_brch_taken),
    .mem_en     (od1_mem_en),
    .mem_write  (od1_mem_write),
    .brch_pc    (od1_brch_pc),
    .mem_addr   (od1_mem_addr),
    .mem_wdata  (od1_mem_wdata),
    .mem_besel  (od1_mem_besel),
    .link_pc    (od1_link_pc),
    .reg_wdata  (od1_alu_result)
  );

endmodule
