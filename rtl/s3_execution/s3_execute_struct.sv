`timescale 1ns / 1ps

// S3 execute structure — forward unit + four lane copies (combinational EX).
// id_ex_dispatch, ex_mem, and s4_memory_struct live outside this block.
module s3_execute_struct
  import rv_dis_pkg::*;
(
  // internal controls
  input  logic        i0_reg_write_ex,
  input  logic        i1_reg_write_ex,
  input  logic        ev0_enable_ex,
  input  logic        ev1_enable_ex,
  input  logic        od0_enable_ex,
  input  logic        od1_enable_ex,
  input  logic        wb0_reg_write,
  input  logic        wb1_reg_write,

  // input data
  input  logic [31:0] i0_pc_ex,
  input  logic [31:0] i1_pc_ex,
  input  logic [6:0]  ev0_opcode_ex,
  input  logic [2:0]  ev0_funct3_ex,
  input  logic [6:0]  ev0_funct7_ex,
  input  logic [4:0]  ev0_rd_ex,
  input  logic [4:0]  ev0_rs1_addr_ex,
  input  logic [4:0]  ev0_rs2_addr_ex,
  input  logic [31:0] ev0_imm_ex,
  input  logic [31:0] ev0_rs1_data_ex,
  input  logic [31:0] ev0_rs2_data_ex,
  input  logic [31:0] ev0_pc_ex,
  input  logic [6:0]  ev1_opcode_ex,
  input  logic [2:0]  ev1_funct3_ex,
  input  logic [6:0]  ev1_funct7_ex,
  input  logic [4:0]  ev1_rd_ex,
  input  logic [4:0]  ev1_rs1_addr_ex,
  input  logic [4:0]  ev1_rs2_addr_ex,
  input  logic [31:0] ev1_imm_ex,
  input  logic [31:0] ev1_rs1_data_ex,
  input  logic [31:0] ev1_rs2_data_ex,
  input  logic [31:0] ev1_pc_ex,
  input  logic [6:0]  od0_opcode_ex,
  input  logic [2:0]  od0_funct3_ex,
  input  logic [4:0]  od0_rd_ex,
  input  logic [4:0]  od0_rs1_addr_ex,
  input  logic [4:0]  od0_rs2_addr_ex,
  input  logic [31:0] od0_imm_ex,
  input  logic [31:0] od0_rs1_data_ex,
  input  logic [31:0] od0_rs2_data_ex,
  input  logic [31:0] od0_pc_ex,
  input  logic [6:0]  od1_opcode_ex,
  input  logic [2:0]  od1_funct3_ex,
  input  logic [4:0]  od1_rd_ex,
  input  logic [4:0]  od1_rs1_addr_ex,
  input  logic [4:0]  od1_rs2_addr_ex,
  input  logic [31:0] od1_imm_ex,
  input  logic [31:0] od1_rs1_data_ex,
  input  logic [31:0] od1_rs2_data_ex,
  input  logic [31:0] od1_pc_ex,
  input  logic [4:0]  wb0_rd_addr,
  input  logic [31:0] wb0_data,
  input  logic [31:0] wb0_pc,
  input  logic [4:0]  wb1_rd_addr,
  input  logic [31:0] wb1_data,
  input  logic [31:0] wb1_pc,

  // output controls
  output logic        od0_use_link_ex,
  output logic        od1_use_link_ex,
  output logic        od0_brch_taken,
  output logic        od0_mem_en,
  output logic        od0_mem_act,
  output logic        od1_brch_taken,
  output logic        od1_mem_en,
  output logic        od1_mem_act,

  // output data
  output logic [31:0] ev0_alu_result,
  output logic [31:0] ev1_alu_result,
  output logic [31:0] od0_brch_pc,
  output logic [31:0] od0_mem_addr,
  output logic [31:0] od0_mem_wdata,
  output logic [3:0]  od0_mem_besel,
  output logic [31:0] od0_link_pc,
  output logic [31:0] od0_alu_result,
  output logic [31:0] od1_brch_pc,
  output logic [31:0] od1_mem_addr,
  output logic [31:0] od1_mem_wdata,
  output logic [3:0]  od1_mem_besel,
  output logic [31:0] od1_link_pc,
  output logic [31:0] od1_alu_result
);

  logic [31:0] ev0_rs1_data_fwd;
  logic [31:0] ev0_rs2_data_fwd;
  logic [31:0] ev1_rs1_data_fwd;
  logic [31:0] ev1_rs2_data_fwd;
  logic [31:0] od0_rs1_data_fwd;
  logic [31:0] od0_rs2_data_fwd;
  logic [31:0] od1_rs1_data_fwd;
  logic [31:0] od1_rs2_data_fwd;

  assign od0_use_link_ex = od0_enable_ex &&
                           ((od0_opcode_ex == OPC_JAL) || (od0_opcode_ex == OPC_JALR));
  assign od1_use_link_ex = od1_enable_ex &&
                           ((od1_opcode_ex == OPC_JAL) || (od1_opcode_ex == OPC_JALR));

  forward_unit u_forward (
    // internal controls
    .ev0_enable       (ev0_enable_ex),
    .ev1_enable       (ev1_enable_ex),
    .od0_enable       (od0_enable_ex),
    .od1_enable       (od1_enable_ex),
    .wb0_reg_write    (wb0_reg_write),
    .wb1_reg_write    (wb1_reg_write),
    // input data
    .ev0_rs1_addr     (ev0_rs1_addr_ex),
    .ev0_rs2_addr     (ev0_rs2_addr_ex),
    .ev0_rs1_data     (ev0_rs1_data_ex),
    .ev0_rs2_data     (ev0_rs2_data_ex),
    .ev1_rs1_addr     (ev1_rs1_addr_ex),
    .ev1_rs2_addr     (ev1_rs2_addr_ex),
    .ev1_rs1_data     (ev1_rs1_data_ex),
    .ev1_rs2_data     (ev1_rs2_data_ex),
    .od0_rs1_addr     (od0_rs1_addr_ex),
    .od0_rs2_addr     (od0_rs2_addr_ex),
    .od0_rs1_data     (od0_rs1_data_ex),
    .od0_rs2_data     (od0_rs2_data_ex),
    .od1_rs1_addr     (od1_rs1_addr_ex),
    .od1_rs2_addr     (od1_rs2_addr_ex),
    .od1_rs1_data     (od1_rs1_data_ex),
    .od1_rs2_data     (od1_rs2_data_ex),
    .wb0_rd_addr      (wb0_rd_addr),
    .wb0_data         (wb0_data),
    .wb0_pc           (wb0_pc),
    .wb1_rd_addr      (wb1_rd_addr),
    .wb1_data         (wb1_data),
    .wb1_pc           (wb1_pc),
    // output data
    .ev0_rs1_data_fwd (ev0_rs1_data_fwd),
    .ev0_rs2_data_fwd (ev0_rs2_data_fwd),
    .ev1_rs1_data_fwd (ev1_rs1_data_fwd),
    .ev1_rs2_data_fwd (ev1_rs2_data_fwd),
    .od0_rs1_data_fwd (od0_rs1_data_fwd),
    .od0_rs2_data_fwd (od0_rs2_data_fwd),
    .od1_rs1_data_fwd (od1_rs1_data_fwd),
    .od1_rs2_data_fwd (od1_rs2_data_fwd)
  );

  even_lane u_ev0 (
    // internal controls
    .enable     (ev0_enable_ex),
    // input data
    .opcode     (ev0_opcode_ex),
    .funct3     (ev0_funct3_ex),
    .funct7     (ev0_funct7_ex),
    .rs1_data   (ev0_rs1_data_fwd),
    .rs2_data   (ev0_rs2_data_fwd),
    .imm        (ev0_imm_ex),
    // output data
    .alu_result (ev0_alu_result)
  );

  even_lane u_ev1 (
    // internal controls
    .enable     (ev1_enable_ex),
    // input data
    .opcode     (ev1_opcode_ex),
    .funct3     (ev1_funct3_ex),
    .funct7     (ev1_funct7_ex),
    .rs1_data   (ev1_rs1_data_fwd),
    .rs2_data   (ev1_rs2_data_fwd),
    .imm        (ev1_imm_ex),
    // output data
    .alu_result (ev1_alu_result)
  );

  odd_lane u_od0 (
    // internal controls
    .enable     (od0_enable_ex),
    // input data
    .opcode     (od0_opcode_ex),
    .funct3     (od0_funct3_ex),
    .rs1_data   (od0_rs1_data_fwd),
    .rs2_data   (od0_rs2_data_fwd),
    .imm        (od0_imm_ex),
    .pc         (od0_pc_ex),
    // output controls
    .brch_taken (od0_brch_taken),
    .mem_en     (od0_mem_en),
    .mem_act    (od0_mem_act),
    // output data
    .brch_pc    (od0_brch_pc),
    .mem_addr   (od0_mem_addr),
    .mem_wdata  (od0_mem_wdata),
    .mem_besel  (od0_mem_besel),
    .link_pc    (od0_link_pc),
    .reg_wdata  (od0_alu_result)
  );

  odd_lane u_od1 (
    // internal controls
    .enable     (od1_enable_ex),
    // input data
    .opcode     (od1_opcode_ex),
    .funct3     (od1_funct3_ex),
    .rs1_data   (od1_rs1_data_fwd),
    .rs2_data   (od1_rs2_data_fwd),
    .imm        (od1_imm_ex),
    .pc         (od1_pc_ex),
    // output controls
    .brch_taken (od1_brch_taken),
    .mem_en     (od1_mem_en),
    .mem_act    (od1_mem_act),
    // output data
    .brch_pc    (od1_brch_pc),
    .mem_addr   (od1_mem_addr),
    .mem_wdata  (od1_mem_wdata),
    .mem_besel  (od1_mem_besel),
    .link_pc    (od1_link_pc),
    .reg_wdata  (od1_alu_result)
  );

endmodule
