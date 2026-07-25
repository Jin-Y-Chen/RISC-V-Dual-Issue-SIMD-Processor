`timescale 1ns / 1ps

// S2 decode structure — dual decoder + state_buffer + per-lane target_predict.
// IF/ID supplies instr/PC/pc_target, slot valid, and per-lane spec0/spec1 enables.
// No register-file access here: decode exports rs*/rd addresses and use flags only;
// GPR read/write lives in the issue stage.
// Nested-speculation freeze (i*_nest_spec_stall) is produced by target_predict for PC.
import rv_dis_pkg::*;

module s2_decode_struct (
  // external controls
  input  logic        clk,
  input  logic        rst_n,

  // IF/ID controls (slot valid + per-lane speculation from if_id)
  input  logic        i0_valid_id,
  input  logic        i1_valid_id,
  input  logic        spec0_en_id,
  input  logic        spec1_en_id,

  // IF/ID data
  input  instr_t      i0_instr_id,
  input  instr_t      i1_instr_id,
  input  word_t       i0_pc_id,
  input  word_t       i1_pc_id,
  input  word_t       i0_pc_target_id,
  input  word_t       i1_pc_target_id,
  input  logic        i0_target_valid_id,
  input  logic        i1_target_valid_id,

  // branch-state writeback (MEM resolve → state_buffer train)
  input  logic        i0_brch_valid_wb,
  input  logic        i1_brch_valid_wb,
  input  word_t       i0_brch_pc_wb,
  input  word_t       i1_brch_pc_wb,
  input  br_state_t   i0_brch_state_wb,
  input  br_state_t   i1_brch_state_wb,

  // decode outputs — data (addresses / immediate only; no GPR operands)
  output logic        i0_lane_sel,
  output opcode_t     i0_opcode,
  output funct3_t     i0_funct3,
  output funct7_t     i0_funct7,
  output gpr_addr_t   i0_rd_addr,
  output gpr_addr_t   i0_rs1_addr,
  output gpr_addr_t   i0_rs2_addr,
  output word_t       i0_imm,
  output logic        i1_lane_sel,
  output opcode_t     i1_opcode,
  output funct3_t     i1_funct3,
  output funct7_t     i1_funct7,
  output gpr_addr_t   i1_rd_addr,
  output gpr_addr_t   i1_rs1_addr,
  output gpr_addr_t   i1_rs2_addr,
  output word_t       i1_imm,

  // decode outputs — controls
  output logic        i0_valid,
  output logic        i0_brch_en,
  output logic        i0_jump_en,
  output logic        i0_store_en,
  output logic        i0_rs1_use,
  output logic        i0_rs2_use,
  output logic        i0_reg_write,
  output logic        i1_valid,
  output logic        i1_brch_en,
  output logic        i1_jump_en,
  output logic        i1_store_en,
  output logic        i1_rs1_use,
  output logic        i1_rs2_use,
  output logic        i1_reg_write,

  // branch predict outputs (nest_spec_stall → fetch PC)
  output br_state_t   i0_brch_state,
  output br_state_t   i1_brch_state,
  output word_t       i0_pc_predict,
  output word_t       i1_pc_predict,
  output logic        i0_pred_taken,
  output logic        i1_pred_taken,
  output logic        i0_pred_valid_wb,
  output logic        i1_pred_valid_wb,
  output logic        i0_nest_spec_stall,
  output logic        i1_nest_spec_stall
);

  // -------------------------------------------------------------------------
  // Decoders
  // -------------------------------------------------------------------------
  decoder u_dec_i0 (
    .instr     (i0_instr_id),
    .lane_sel  (i0_lane_sel),
    .brch_en   (i0_brch_en),
    .jump_en   (i0_jump_en),
    .store_en  (i0_store_en),
    .opcode    (i0_opcode),
    .funct3    (i0_funct3),
    .funct7    (i0_funct7),
    .rd_addr   (i0_rd_addr),
    .rs1_addr  (i0_rs1_addr),
    .rs2_addr  (i0_rs2_addr),
    .imm       (i0_imm),
    .valid     (i0_valid),
    .rs1_use   (i0_rs1_use),
    .rs2_use   (i0_rs2_use),
    .reg_write (i0_reg_write)
  );

  decoder u_dec_i1 (
    .instr     (i1_instr_id),
    .lane_sel  (i1_lane_sel),
    .brch_en   (i1_brch_en),
    .jump_en   (i1_jump_en),
    .store_en  (i1_store_en),
    .opcode    (i1_opcode),
    .funct3    (i1_funct3),
    .funct7    (i1_funct7),
    .rd_addr   (i1_rd_addr),
    .rs1_addr  (i1_rs1_addr),
    .rs2_addr  (i1_rs2_addr),
    .imm       (i1_imm),
    .valid     (i1_valid),
    .rs1_use   (i1_rs1_use),
    .rs2_use   (i1_rs2_use),
    .reg_write (i1_reg_write)
  );

  // -------------------------------------------------------------------------
  // Branch direction state + target predict
  // -------------------------------------------------------------------------
  state_buffer u_state_buf (
    .clk              (clk),
    .rst_n            (rst_n),
    .i0_pc            (i0_pc_id),
    .i1_pc            (i1_pc_id),
    .i0_brch_en       (i0_brch_en),
    .i1_brch_en       (i1_brch_en),
    .i0_valid_wb      (i0_brch_valid_wb),
    .i1_valid_wb      (i1_brch_valid_wb),
    .i0_brch_pc_wb    (i0_brch_pc_wb),
    .i1_brch_pc_wb    (i1_brch_pc_wb),
    .i0_brch_state_wb (i0_brch_state_wb),
    .i1_brch_state_wb (i1_brch_state_wb),
    .i0_brch_state    (i0_brch_state),
    .i1_brch_state    (i1_brch_state)
  );

  target_predict u_target_predict_i0 (
    .target_valid    (i0_target_valid_id),
    .brnch_en        (i0_brch_en),
    .jump_en         (i0_jump_en),
    .spec_n          (spec0_en_id),
    .pc              (i0_pc_id),
    .target_state    (i0_brch_state),
    .imm             (i0_imm),
    .pc_target       (i0_pc_target_id),
    .pc_predict      (i0_pc_predict),
    .pred_taken      (i0_pred_taken),
    .pred_valid_wb   (i0_pred_valid_wb),
    .nest_spec_stall (i0_nest_spec_stall)
  );

  target_predict u_target_predict_i1 (
    .target_valid    (i1_target_valid_id),
    .brnch_en        (i1_brch_en),
    .jump_en         (i1_jump_en),
    .spec_n          (spec1_en_id),
    .pc              (i1_pc_id),
    .target_state    (i1_brch_state),
    .imm             (i1_imm),
    .pc_target       (i1_pc_target_id),
    .pc_predict      (i1_pc_predict),
    .pred_taken      (i1_pred_taken),
    .pred_valid_wb   (i1_pred_valid_wb),
    .nest_spec_stall (i1_nest_spec_stall)
  );

endmodule
