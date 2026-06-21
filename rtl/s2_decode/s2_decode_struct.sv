`timescale 1ns / 1ps

// S2 decode structure — dual decoder + GPR (no IF/ID register).
// state_buffer lives in branch_mod/ and is not included here.
module s2_decode_struct
  import rv_dis_pkg::*;
(
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls
  input  logic        i0_wen,
  input  logic        i1_wen,

  // input data
  input  instr_t      i0_instr,
  input  instr_t      i1_instr,
  input  logic [4:0]  i0_rd,
  input  reg_t        i0_wdata,
  input  reg_t        i0_wpc,
  input  logic [4:0]  i1_rd,
  input  reg_t        i1_wdata,
  input  reg_t        i1_wpc,

  // output data
  output lane_sel_e   i0_lane_sel,
  output logic [6:0]  i0_opcode,
  output logic [2:0]  i0_funct3,
  output logic [6:0]  i0_funct7,
  output logic [4:0]  i0_rd_addr,
  output logic [4:0]  i0_rs1_addr,
  output logic [4:0]  i0_rs2_addr,
  output logic [31:0] i0_imm,
  output reg_t        i0_rs1_data,
  output reg_t        i0_rs2_data,
  output lane_sel_e   i1_lane_sel,
  output logic [6:0]  i1_opcode,
  output logic [2:0]  i1_funct3,
  output logic [6:0]  i1_funct7,
  output logic [4:0]  i1_rd_addr,
  output logic [4:0]  i1_rs1_addr,
  output logic [4:0]  i1_rs2_addr,
  output logic [31:0] i1_imm,
  output reg_t        i1_rs1_data,
  output reg_t        i1_rs2_data,

  // output controls
  output logic        i0_valid,
  output logic        i0_brch_en,
  output logic        i0_reg_write,
  output logic        i1_valid,
  output logic        i1_brch_en,
  output logic        i1_rs1_use,
  output logic        i1_rs2_use,
  output logic        i1_reg_write
);

  // Internal decode → register_file (not exported)
  logic        rf_i0_rs1_use;
  logic        rf_i0_rs2_use;
  logic        rf_i1_rs1_use;
  logic        rf_i1_rs2_use;
  logic [4:0]  rf_i0_rs1_addr;
  logic [4:0]  rf_i0_rs2_addr;
  logic [4:0]  rf_i1_rs1_addr;
  logic [4:0]  rf_i1_rs2_addr;

  decoder u_dec_i0 (
    // input data
    .instr     (i0_instr),
    // output data
    .lane_sel  (i0_lane_sel),
    .brch_en  (i0_brch_en),
    .opcode    (i0_opcode),
    .funct3    (i0_funct3),
    .funct7    (i0_funct7),
    .rd        (i0_rd_addr),
    .rs1       (rf_i0_rs1_addr),
    .rs2       (rf_i0_rs2_addr),
    .imm       (i0_imm),
    // output controls
    .valid     (i0_valid),
    .rs1_use   (rf_i0_rs1_use),
    .rs2_use   (rf_i0_rs2_use),
    .reg_write (i0_reg_write)
  );

  decoder u_dec_i1 (
    // input data
    .instr     (i1_instr),
    // output data
    .lane_sel  (i1_lane_sel),
    .brch_en  (i1_brch_en),
    .opcode    (i1_opcode),
    .funct3    (i1_funct3),
    .funct7    (i1_funct7),
    .rd        (i1_rd_addr),
    .rs1       (rf_i1_rs1_addr),
    .rs2       (rf_i1_rs2_addr),
    .imm       (i1_imm),
    // output controls
    .valid     (i1_valid),
    .rs1_use   (rf_i1_rs1_use),
    .rs2_use   (rf_i1_rs2_use),
    .reg_write (i1_reg_write)
  );

  // GPR read ports use internal decode nets; rs addrs also fan out to dispatch.
  assign i0_rs1_addr = rf_i0_rs1_addr;
  assign i0_rs2_addr = rf_i0_rs2_addr;
  assign i1_rs1_addr = rf_i1_rs1_addr;
  assign i1_rs2_addr = rf_i1_rs2_addr;
  assign i1_rs1_use  = rf_i1_rs1_use;
  assign i1_rs2_use  = rf_i1_rs2_use;

  register_file u_regfile (
    // external controls
    .clk         (clk),
    .rst_n       (rst_n),
    .enable      (enable),
    // internal controls
    .i0_rs1_use  (rf_i0_rs1_use),
    .i0_rs2_use  (rf_i0_rs2_use),
    .i1_rs1_use  (rf_i1_rs1_use),
    .i1_rs2_use  (rf_i1_rs2_use),
    .i0_wen      (i0_wen),
    .i1_wen      (i1_wen),
    // input data
    .i0_rs1_addr (rf_i0_rs1_addr),
    .i0_rs2_addr (rf_i0_rs2_addr),
    .i1_rs1_addr (rf_i1_rs1_addr),
    .i1_rs2_addr (rf_i1_rs2_addr),
    .i0_rd       (i0_rd),
    .i1_rd       (i1_rd),
    .i0_wdata    (i0_wdata),
    .i1_wdata    (i1_wdata),
    .i0_wpc      (i0_wpc),
    .i1_wpc      (i1_wpc),
    // output data
    .i0_rs1_data (i0_rs1_data),
    .i0_rs2_data (i0_rs2_data),
    .i1_rs1_data (i1_rs1_data),
    .i1_rs2_data (i1_rs2_data)
  );

endmodule
