`timescale 1ns / 1ps

// S2 decode structure — dual decoder + state_buffer + per-lane target_predict.
// IF/ID supplies instr/PC/pc_target, slot valid, and speculation enables.
// No register-file access here: decode exports rs*/rd addresses and use flags only;
// GPR read/write lives in the issue stage.
// Nested-speculation freeze (i0/i1_spec_stall) is produced by target_predict for PC.
import rv_dis_pkg::*;

module s2_decode_struct (
  // external controls
  input  logic        clk,
  input  logic        rst_n,

  // IF/ID controls (slot valid + branch_map from if_id)
  input  logic        i0_valid_id,
  input  logic        i1_valid_id,
  input  br_map_t     br_map,

  // IF/ID data
  input  instr_t      i0_instr,
  input  instr_t      i1_instr,
  input  word_t       i0_pc,
  input  word_t       i1_pc,
  input  word_t       i0_pc_target,
  input  word_t       i1_pc_target,

  // branch-state writeback (MEM resolve → state_buffer train)
  input  logic        i0_br_valid_wb,
  input  logic        i1_br_valid_wb,
  input  word_t       i0_br_pc_wb,
  input  word_t       i1_br_pc_wb,
  input  br_state_t   i0_target_state_wb,
  input  br_state_t   i1_target_state_wb,

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
  output logic        i0_rs1_use,
  output logic        i0_rs2_use,
  output logic        i0_reg_write,
  output logic        i1_valid,
  output logic        i1_brch_en,
  output logic        i1_jump_en,
  output logic        i1_rs1_use,
  output logic        i1_rs2_use,
  output logic        i1_reg_write,

  // branch predict outputs (spec_stall → fetch PC)
  output br_state_t   i0_target_state,
  output br_state_t   i1_target_state,
  output word_t       i0_pc_predict,
  output word_t       i1_pc_predict,
  output logic        i0_predict_taken,
  output logic        i1_predict_taken,
  output logic        i0_tp_wb_valid,
  output logic        i1_tp_wb_valid,
  output logic        i0_spec_stall,
  output logic        i1_spec_stall
);

  // Slot must be IF/ID-valid and decoder-legal before target_predict runs.
  logic i0_pc_valid;
  logic i1_pc_valid;

  assign i0_pc_valid = i0_valid_id && i0_valid;
  assign i1_pc_valid = i1_valid_id && i1_valid;

  // -------------------------------------------------------------------------
  // Decoders
  // -------------------------------------------------------------------------
  decoder u_dec_i0 (
    .instr     (i0_instr),
    .lane_sel  (i0_lane_sel),
    .brch_en   (i0_brch_en),
    .jump_en   (i0_jump_en),
    .opcode    (i0_opcode),
    .funct3    (i0_funct3),
    .funct7    (i0_funct7),
    .rd        (i0_rd_addr),
    .rs1       (i0_rs1_addr),
    .rs2       (i0_rs2_addr),
    .imm       (i0_imm),
    .valid     (i0_valid),
    .rs1_use   (i0_rs1_use),
    .rs2_use   (i0_rs2_use),
    .reg_write (i0_reg_write)
  );

  decoder u_dec_i1 (
    .instr     (i1_instr),
    .lane_sel  (i1_lane_sel),
    .brch_en   (i1_brch_en),
    .jump_en   (i1_jump_en),
    .opcode    (i1_opcode),
    .funct3    (i1_funct3),
    .funct7    (i1_funct7),
    .rd        (i1_rd_addr),
    .rs1       (i1_rs1_addr),
    .rs2       (i1_rs2_addr),
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
    .clk                 (clk),
    .rst_n               (rst_n),
    .i0_pc               (i0_pc),
    .i1_pc               (i1_pc),
    .i0_brch_en          (i0_brch_en),
    .i1_brch_en          (i1_brch_en),
    .i0_valid_wb         (i0_br_valid_wb),
    .i1_valid_wb         (i1_br_valid_wb),
    .i0_pc_wb            (i0_br_pc_wb),
    .i1_pc_wb            (i1_br_pc_wb),
    .i0_target_state_wb  (i0_target_state_wb),
    .i1_target_state_wb  (i1_target_state_wb),
    .i0_target_state     (i0_target_state),
    .i1_target_state     (i1_target_state)
  );

  target_predict u_target_predict_i0 (
    .pc_valid       (i0_pc_valid),
    .brnch_en       (i0_brch_en),
    .jump_en        (i0_jump_en),
    .br_map         (br_map),
    .lane_is_i1     (1'b0),
    .pc             (i0_pc),
    .target_state   (i0_target_state),
    .imm            (i0_imm),
    .pc_target      (i0_pc_target),
    .pc_predict     (i0_pc_predict),
    .predict_taken  (i0_predict_taken),
    .wb_valid       (i0_tp_wb_valid),
    .spec_stall     (i0_spec_stall)
  );

  target_predict u_target_predict_i1 (
    .pc_valid       (i1_pc_valid),
    .brnch_en       (i1_brch_en),
    .jump_en        (i1_jump_en),
    .br_map         (br_map),
    .lane_is_i1     (1'b1),
    .pc             (i1_pc),
    .target_state   (i1_target_state),
    .imm            (i1_imm),
    .pc_target      (i1_pc_target),
    .pc_predict     (i1_pc_predict),
    .predict_taken  (i1_predict_taken),
    .wb_valid       (i1_tp_wb_valid),
    .spec_stall     (i1_spec_stall)
  );

endmodule
