`timescale 1ns / 1ps

// S2 decode — dual decoder, GPR, branch state buffer, and per-lane target_predict.
import rv_dis_pkg::*;

module s2_decode_struct (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // IF/ID inputs
  input  instr_t      i0_instr,
  input  instr_t      i1_instr,
  input  word_t       i0_pc,
  input  word_t       i1_pc,
  input  word_t       i0_pc_target,
  input  word_t       i1_pc_target,

  // GPR writeback
  input  logic        i0_wen,
  input  logic        i1_wen,
  input  gpr_addr_t   i0_rd,
  input  word_t       i0_wdata,
  input  word_t       i0_wpc,
  input  gpr_addr_t   i1_rd,
  input  word_t       i1_wdata,
  input  word_t       i1_wpc,

  // branch-state writeback (MEM resolve → state_LUT in top)
  input  logic        i0_br_valid_wb,
  input  logic        i1_br_valid_wb,
  input  word_t       i0_br_pc_wb,
  input  word_t       i1_br_pc_wb,
  input  br_state_t   i0_target_state_wb,
  input  br_state_t   i1_target_state_wb,

  // decode outputs — data
  output logic        i0_lane_sel,
  output opcode_t     i0_opcode,
  output funct3_t     i0_funct3,
  output funct7_t     i0_funct7,
  output gpr_addr_t   i0_rd_addr,
  output gpr_addr_t   i0_rs1_addr,
  output gpr_addr_t   i0_rs2_addr,
  output word_t       i0_imm,
  output word_t       i0_rs1_data,
  output word_t       i0_rs2_data,
  output logic        i1_lane_sel,
  output opcode_t     i1_opcode,
  output funct3_t     i1_funct3,
  output funct7_t     i1_funct7,
  output gpr_addr_t   i1_rd_addr,
  output gpr_addr_t   i1_rs1_addr,
  output gpr_addr_t   i1_rs2_addr,
  output word_t       i1_imm,
  output word_t       i1_rs1_data,
  output word_t       i1_rs2_data,

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

  // branch predict outputs
  output br_state_t   i0_target_state,
  output br_state_t   i1_target_state,
  output word_t       i0_pc_predict,
  output word_t       i1_pc_predict,
  output logic        i0_set_target,
  output logic        i1_set_target,
  output logic        i0_tp_wb_valid,
  output logic        i1_tp_wb_valid
);

  // -------------------------------------------------------------------------
  // Decoders
  // -------------------------------------------------------------------------
  logic [4:0] rf_i0_rs1_addr;
  logic [4:0] rf_i0_rs2_addr;
  logic [4:0] rf_i1_rs1_addr;
  logic [4:0] rf_i1_rs2_addr;

  decoder u_dec_i0 (
    // input data
    .instr     (i0_instr),
    // output data
    .lane_sel  (i0_lane_sel),
    .brch_en   (i0_brch_en),
    .jump_en   (i0_jump_en),
    .opcode    (i0_opcode),
    .funct3    (i0_funct3),
    .funct7    (i0_funct7),
    .rd        (i0_rd_addr),
    .rs1       (rf_i0_rs1_addr),
    .rs2       (rf_i0_rs2_addr),
    .imm       (i0_imm),
    // output controls
    .valid     (i0_valid),
    .rs1_use   (i0_rs1_use),
    .rs2_use   (i0_rs2_use),
    .reg_write (i0_reg_write)
  );

  decoder u_dec_i1 (
    // input data
    .instr     (i1_instr),
    // output data
    .lane_sel  (i1_lane_sel),
    .brch_en   (i1_brch_en),
    .jump_en   (i1_jump_en),
    .opcode    (i1_opcode),
    .funct3    (i1_funct3),
    .funct7    (i1_funct7),
    .rd        (i1_rd_addr),
    .rs1       (rf_i1_rs1_addr),
    .rs2       (rf_i1_rs2_addr),
    .imm       (i1_imm),
    // output controls
    .valid     (i1_valid),
    .rs1_use   (i1_rs1_use),
    .rs2_use   (i1_rs2_use),
    .reg_write (i1_reg_write)
  );

  assign i0_rs1_addr = rf_i0_rs1_addr;
  assign i0_rs2_addr = rf_i0_rs2_addr;
  assign i1_rs1_addr = rf_i1_rs1_addr;
  assign i1_rs2_addr = rf_i1_rs2_addr;

  // -------------------------------------------------------------------------
  // Register file
  // -------------------------------------------------------------------------
  register_file u_regfile (
    // external controls
    .clk          (clk),
    .rst_n        (rst_n),
    // internal controls
    .i0_rs1_use   (i0_rs1_use),
    .i0_rs2_use   (i0_rs2_use),
    .i1_rs1_use   (i1_rs1_use),
    .i1_rs2_use   (i1_rs2_use),
    .i0_valid_wb  (i0_wen),
    .i1_valid_wb  (i1_wen),
    // input data
    .i0_rs1_addr  (rf_i0_rs1_addr),
    .i0_rs2_addr  (rf_i0_rs2_addr),
    .i1_rs1_addr  (rf_i1_rs1_addr),
    .i1_rs2_addr  (rf_i1_rs2_addr),
    .i0_rd        (i0_rd),
    .i1_rd        (i1_rd),
    .i0_data_wb   (i0_wdata),
    .i1_data_wb   (i1_wdata),
    .i0_pc_wb     (i0_wpc),
    .i1_pc_wb     (i1_wpc),
    // output data
    .i0_rs1_data  (i0_rs1_data),
    .i0_rs2_data  (i0_rs2_data),
    .i1_rs1_data  (i1_rs1_data),
    .i1_rs2_data  (i1_rs2_data)
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
    .pc_valid    (i0_valid),
    .brnch_en    (i0_brch_en),
    .jump_en     (i0_jump_en),
    .pc          (i0_pc),
    .target_state(i0_target_state),
    .imm         (i0_imm),
    .pc_target   (i0_pc_target),
    .set_target  (i0_set_target),
    .wb_valid    (i0_tp_wb_valid),
    .pc_predict  (i0_pc_predict)
  );

  target_predict u_target_predict_i1 (
    .pc_valid    (i1_valid),
    .brnch_en    (i1_brch_en),
    .jump_en     (i1_jump_en),
    .pc          (i1_pc),
    .target_state(i1_target_state),
    .imm         (i1_imm),
    .pc_target   (i1_pc_target),
    .set_target  (i1_set_target),
    .wb_valid    (i1_tp_wb_valid),
    .pc_predict  (i1_pc_predict)
  );

endmodule
