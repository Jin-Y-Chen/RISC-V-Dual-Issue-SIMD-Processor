`timescale 1ns / 1ps

// S2 decode structure — dual decoder + state_buffer + per-lane target_predict.
// All slot-indexed ports are [2] arrays: index 0 = I0, index 1 = I1.
// IF/ID supplies instr/PC/pc_target, slot valid, and per-lane spec_en_id.
// No register-file access here: decode exports rs*/rd addresses and use flags only;
// GPR read/write lives in the issue stage.
// Nested-speculation freeze (nest_spec_stall) is produced by target_predict for PC.
import rv_dis_pkg::*;

module s2_decode_struct (
  // external controls
  input  logic        clk,
  input  logic        rst_n,

  // IF/ID controls (I$ hit + per-lane speculation from if_id)
  input  logic        fetch_valid_id  [2],
  input  logic        spec_en_id      [2],

  // IF/ID data
  input  instr_t      instr_id        [2],
  input  word_t       pc_id           [2],
  input  word_t       pc_target_id    [2],
  input  logic        target_valid_id [2],

  // branch-state writeback (MEM resolve → state_buffer train)
  input  logic        brch_valid_wb   [2],
  input  word_t       brch_pc_wb      [2],
  input  br_state_t   brch_state_wb   [2],

  // decode outputs — data (addresses / immediate only; no GPR operands)
  output logic        lane_sel        [2],
  output opcode_t     opcode          [2],
  output funct3_t     funct3          [2],
  output funct7_t     funct7          [2],
  output gpr_addr_t   rd_addr         [2],
  output gpr_addr_t   rs1_addr        [2],
  output gpr_addr_t   rs2_addr        [2],
  output word_t       imm             [2],

  // decode outputs — controls
  output logic        valid           [2],
  output logic        brch_en         [2],
  output logic        store_en        [2],
  output logic        rs1_use         [2],
  output logic        rs2_use         [2],
  output logic        reg_write       [2],

  // branch predict outputs (nest_spec_stall → fetch PC)
  output br_state_t   brch_state      [2],
  output logic        state_valid     [2],
  output word_t       pc_predict      [2],
  output logic        pred_taken      [2],
  output logic        pred_valid_wb   [2],
  output logic        nest_spec_stall [2]
);

  // Internal only: decoder → target_predict (not exported)
  logic jump_en [2];

  // -------------------------------------------------------------------------
  // Branch direction state (shared bank, dual-ported)
  // -------------------------------------------------------------------------
  state_buffer u_state_buf (
    .clk           (clk),
    .rst_n         (rst_n),
    .pc            (pc_id),
    .brch_en       (brch_en),
    .valid_wb      (brch_valid_wb),
    .brch_pc_wb    (brch_pc_wb),
    .brch_state_wb (brch_state_wb),
    .brch_state    (brch_state),
    .state_valid   (state_valid)
  );

  // -------------------------------------------------------------------------
  // Per-slot decode + target predict (decoder/target_predict are single-insn)
  // -------------------------------------------------------------------------
  for (genvar i = 0; i < N_DUAL; i++) begin : g_slot
    decoder u_dec (
      .instr       (instr_id[i]),
      .fetch_valid (fetch_valid_id[i]),
      .lane_sel    (lane_sel[i]),
      .brch_en     (brch_en[i]),
      .jump_en     (jump_en[i]),
      .store_en    (store_en[i]),
      .opcode      (opcode[i]),
      .funct3      (funct3[i]),
      .funct7      (funct7[i]),
      .rd_addr     (rd_addr[i]),
      .rs1_addr    (rs1_addr[i]),
      .rs2_addr    (rs2_addr[i]),
      .imm         (imm[i]),
      .valid       (valid[i]),
      .rs1_use     (rs1_use[i]),
      .rs2_use     (rs2_use[i]),
      .reg_write   (reg_write[i])
    );

    target_predict u_target_predict (
      .target_valid    (target_valid_id[i]),
      .brnch_en        (brch_en[i]),
      .jump_en         (jump_en[i]),
      .spec_n          (spec_en_id[i]),
      .pc              (pc_id[i]),
      .target_state    (brch_state[i]),
      .imm             (imm[i]),
      .pc_target       (pc_target_id[i]),
      .pc_predict      (pc_predict[i]),
      .pred_taken      (pred_taken[i]),
      .pred_valid_wb   (pred_valid_wb[i]),
      .nest_spec_stall (nest_spec_stall[i])
    );
  end

endmodule
