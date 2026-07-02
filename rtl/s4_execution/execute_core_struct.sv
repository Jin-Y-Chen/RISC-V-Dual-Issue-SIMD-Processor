`timescale 1ns / 1ps

// S4 execute structure — reservation stations + forward unit + four lane copies.
// dp_ex feeds the RS enqueue ports; RS issue drives combinational EX.
module s4_execute_struct
  import rv_dis_pkg::*;
  import decode_pkg::*;   // decode_rs1_use / decode_rs2_use (immediate-vs-register select)
  import rob_rename_pkg::*;
(
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
  output logic        od0_mem_act,
  output logic        od1_brch_taken,
  output logic        od1_mem_en,
  output logic        od1_mem_act,

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

  logic [31:0] ev0_rs1_data_fwd;
  logic [31:0] ev0_rs2_data_fwd;
  logic [31:0] ev1_rs1_data_fwd;
  logic [31:0] ev1_rs2_data_fwd;
  logic [31:0] od0_rs1_data_fwd;
  logic [31:0] od0_rs2_data_fwd;
  logic [31:0] od1_rs1_data_fwd;
  logic [31:0] od1_rs2_data_fwd;

  logic        rs_ev0_enable_ex;
  logic        rs_ev1_enable_ex;
  logic        rs_od0_enable_ex;
  logic        rs_od1_enable_ex;
  logic        rs_i0_reg_write_ex;
  logic        rs_i1_reg_write_ex;
  word_t       rs_i0_pc_ex;
  word_t       rs_i1_pc_ex;
  opcode_t     rs_ev0_opcode_ex;
  funct3_t     rs_ev0_funct3_ex;
  funct7_t     rs_ev0_funct7_ex;
  gpr_addr_t   rs_ev0_rd_ex;
  gpr_addr_t   rs_ev0_rs1_addr_ex;
  gpr_addr_t   rs_ev0_rs2_addr_ex;
  word_t       rs_ev0_imm_ex;
  word_t       rs_ev0_rs1_data_ex;
  word_t       rs_ev0_rs2_data_ex;
  word_t       rs_ev0_pc_ex;
  opcode_t     rs_ev1_opcode_ex;
  funct3_t     rs_ev1_funct3_ex;
  funct7_t     rs_ev1_funct7_ex;
  gpr_addr_t   rs_ev1_rd_ex;
  gpr_addr_t   rs_ev1_rs1_addr_ex;
  gpr_addr_t   rs_ev1_rs2_addr_ex;
  word_t       rs_ev1_imm_ex;
  word_t       rs_ev1_rs1_data_ex;
  word_t       rs_ev1_rs2_data_ex;
  word_t       rs_ev1_pc_ex;
  opcode_t     rs_od0_opcode_ex;
  funct3_t     rs_od0_funct3_ex;
  gpr_addr_t   rs_od0_rd_ex;
  gpr_addr_t   rs_od0_rs1_addr_ex;
  gpr_addr_t   rs_od0_rs2_addr_ex;
  word_t       rs_od0_imm_ex;
  word_t       rs_od0_rs1_data_ex;
  word_t       rs_od0_rs2_data_ex;
  word_t       rs_od0_pc_ex;
  opcode_t     rs_od1_opcode_ex;
  funct3_t     rs_od1_funct3_ex;
  gpr_addr_t   rs_od1_rd_ex;
  gpr_addr_t   rs_od1_rs1_addr_ex;
  gpr_addr_t   rs_od1_rs2_addr_ex;
  word_t       rs_od1_imm_ex;
  word_t       rs_od1_rs1_data_ex;
  word_t       rs_od1_rs2_data_ex;
  word_t       rs_od1_pc_ex;

  reservation_station u_rs (
    .clk                (clk),
    .rst_n              (rst_n),
    .enable             (enable),
    .flush              (flush),
    .i0_reg_write_disp  (i0_reg_write_ex),
    .i1_reg_write_disp  (i1_reg_write_ex),
    .i0_pc_disp         (i0_pc_ex),
    .i1_pc_disp         (i1_pc_ex),
    .i0_reg_write_ex    (rs_i0_reg_write_ex),
    .i1_reg_write_ex    (rs_i1_reg_write_ex),
    .i0_pc_ex           (rs_i0_pc_ex),
    .i1_pc_ex           (rs_i1_pc_ex),
    .ev0_enable_disp    (ev0_enable_ex),
    .ev0_opcode_disp    (ev0_opcode_ex),
    .ev0_funct3_disp    (ev0_funct3_ex),
    .ev0_funct7_disp    (ev0_funct7_ex),
    .ev0_rd_disp        (ev0_rd_ex),
    .ev0_rs1_addr_disp  (ev0_rs1_addr_ex),
    .ev0_rs2_addr_disp  (ev0_rs2_addr_ex),
    .ev0_imm_disp       (ev0_imm_ex),
    .ev0_rs1_data_disp  (ev0_rs1_data_ex),
    .ev0_rs2_data_disp  (ev0_rs2_data_ex),
    .ev0_pc_disp        (ev0_pc_ex),
    .ev1_enable_disp    (ev1_enable_ex),
    .ev1_opcode_disp    (ev1_opcode_ex),
    .ev1_funct3_disp    (ev1_funct3_ex),
    .ev1_funct7_disp    (ev1_funct7_ex),
    .ev1_rd_disp        (ev1_rd_ex),
    .ev1_rs1_addr_disp  (ev1_rs1_addr_ex),
    .ev1_rs2_addr_disp  (ev1_rs2_addr_ex),
    .ev1_imm_disp       (ev1_imm_ex),
    .ev1_rs1_data_disp  (ev1_rs1_data_ex),
    .ev1_rs2_data_disp  (ev1_rs2_data_ex),
    .ev1_pc_disp        (ev1_pc_ex),
    .od0_enable_disp    (od0_enable_ex),
    .od0_opcode_disp    (od0_opcode_ex),
    .od0_funct3_disp    (od0_funct3_ex),
    .od0_rd_disp        (od0_rd_ex),
    .od0_rs1_addr_disp  (od0_rs1_addr_ex),
    .od0_rs2_addr_disp  (od0_rs2_addr_ex),
    .od0_imm_disp       (od0_imm_ex),
    .od0_rs1_data_disp  (od0_rs1_data_ex),
    .od0_rs2_data_disp  (od0_rs2_data_ex),
    .od0_pc_disp        (od0_pc_ex),
    .od1_enable_disp    (od1_enable_ex),
    .od1_opcode_disp    (od1_opcode_ex),
    .od1_funct3_disp    (od1_funct3_ex),
    .od1_rd_disp        (od1_rd_ex),
    .od1_rs1_addr_disp  (od1_rs1_addr_ex),
    .od1_rs2_addr_disp  (od1_rs2_addr_ex),
    .od1_imm_disp       (od1_imm_ex),
    .od1_rs1_data_disp  (od1_rs1_data_ex),
    .od1_rs2_data_disp  (od1_rs2_data_ex),
    .od1_pc_disp        (od1_pc_ex),
    .wb0_reg_write      (wb0_reg_write),
    .wb0_rd_addr        (wb0_rd_addr),
    .wb0_data           (wb0_data),
    .wb0_pc             (wb0_pc),
    .wb1_reg_write      (wb1_reg_write),
    .wb1_rd_addr        (wb1_rd_addr),
    .wb1_data           (wb1_data),
    .wb1_pc             (wb1_pc),
    .ev0_enable_ex      (rs_ev0_enable_ex),
    .ev0_opcode_ex      (rs_ev0_opcode_ex),
    .ev0_funct3_ex      (rs_ev0_funct3_ex),
    .ev0_funct7_ex      (rs_ev0_funct7_ex),
    .ev0_rd_ex          (rs_ev0_rd_ex),
    .ev0_rs1_addr_ex    (rs_ev0_rs1_addr_ex),
    .ev0_rs2_addr_ex    (rs_ev0_rs2_addr_ex),
    .ev0_imm_ex         (rs_ev0_imm_ex),
    .ev0_rs1_data_ex    (rs_ev0_rs1_data_ex),
    .ev0_rs2_data_ex    (rs_ev0_rs2_data_ex),
    .ev0_pc_ex          (rs_ev0_pc_ex),
    .ev1_enable_ex      (rs_ev1_enable_ex),
    .ev1_opcode_ex      (rs_ev1_opcode_ex),
    .ev1_funct3_ex      (rs_ev1_funct3_ex),
    .ev1_funct7_ex      (rs_ev1_funct7_ex),
    .ev1_rd_ex          (rs_ev1_rd_ex),
    .ev1_rs1_addr_ex    (rs_ev1_rs1_addr_ex),
    .ev1_rs2_addr_ex    (rs_ev1_rs2_addr_ex),
    .ev1_imm_ex         (rs_ev1_imm_ex),
    .ev1_rs1_data_ex    (rs_ev1_rs1_data_ex),
    .ev1_rs2_data_ex    (rs_ev1_rs2_data_ex),
    .ev1_pc_ex          (rs_ev1_pc_ex),
    .od0_enable_ex      (rs_od0_enable_ex),
    .od0_opcode_ex      (rs_od0_opcode_ex),
    .od0_funct3_ex      (rs_od0_funct3_ex),
    .od0_rd_ex          (rs_od0_rd_ex),
    .od0_rs1_addr_ex    (rs_od0_rs1_addr_ex),
    .od0_rs2_addr_ex    (rs_od0_rs2_addr_ex),
    .od0_imm_ex         (rs_od0_imm_ex),
    .od0_rs1_data_ex    (rs_od0_rs1_data_ex),
    .od0_rs2_data_ex    (rs_od0_rs2_data_ex),
    .od0_pc_ex          (rs_od0_pc_ex),
    .od1_enable_ex      (rs_od1_enable_ex),
    .od1_opcode_ex      (rs_od1_opcode_ex),
    .od1_funct3_ex      (rs_od1_funct3_ex),
    .od1_rd_ex          (rs_od1_rd_ex),
    .od1_rs1_addr_ex    (rs_od1_rs1_addr_ex),
    .od1_rs2_addr_ex    (rs_od1_rs2_addr_ex),
    .od1_imm_ex         (rs_od1_imm_ex),
    .od1_rs1_data_ex    (rs_od1_rs1_data_ex),
    .od1_rs2_data_ex    (rs_od1_rs2_data_ex),
    .od1_pc_ex          (rs_od1_pc_ex)
  );

  assign od0_use_link_ex = rs_od0_enable_ex &&
                           ((rs_od0_opcode_ex == OPC_JAL) || (rs_od0_opcode_ex == OPC_JALR));
  assign od1_use_link_ex = rs_od1_enable_ex &&
                           ((rs_od1_opcode_ex == OPC_JAL) || (rs_od1_opcode_ex == OPC_JALR));

  forward_unit u_forward (
    // internal controls
    .ev0_enable       (rs_ev0_enable_ex),
    .ev1_enable       (rs_ev1_enable_ex),
    .od0_enable       (rs_od0_enable_ex),
    .od1_enable       (rs_od1_enable_ex),
    .wb0_reg_write    (wb0_reg_write),
    .wb1_reg_write    (wb1_reg_write),
    // input data
    .ev0_rs1_addr     (rs_ev0_rs1_addr_ex),
    .ev0_rs2_addr     (rs_ev0_rs2_addr_ex),
    .ev0_rs1_data     (rs_ev0_rs1_data_ex),
    .ev0_rs2_data     (rs_ev0_rs2_data_ex),
    .ev1_rs1_addr     (rs_ev1_rs1_addr_ex),
    .ev1_rs2_addr     (rs_ev1_rs2_addr_ex),
    .ev1_rs1_data     (rs_ev1_rs1_data_ex),
    .ev1_rs2_data     (rs_ev1_rs2_data_ex),
    .od0_rs1_addr     (rs_od0_rs1_addr_ex),
    .od0_rs2_addr     (rs_od0_rs2_addr_ex),
    .od0_rs1_data     (rs_od0_rs1_data_ex),
    .od0_rs2_data     (rs_od0_rs2_data_ex),
    .od1_rs1_addr     (rs_od1_rs1_addr_ex),
    .od1_rs2_addr     (rs_od1_rs2_addr_ex),
    .od1_rs1_data     (rs_od1_rs1_data_ex),
    .od1_rs2_data     (rs_od1_rs2_data_ex),
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
    .enable     (rs_ev0_enable_ex),
    // input data
    .opcode     (rs_ev0_opcode_ex),
    .funct3     (rs_ev0_funct3_ex),
    .funct7     (rs_ev0_funct7_ex),
    .rs1_use    (decode_rs1_use(rs_ev0_opcode_ex)),
    .rs2_use    (decode_rs2_use(rs_ev0_opcode_ex)),
    .rs1_data   (ev0_rs1_data_fwd),
    .rs2_data   (ev0_rs2_data_fwd),
    .imm        (rs_ev0_imm_ex),
    // output data
    .alu_result (ev0_alu_result)
  );

  even_lane u_ev1 (
    // internal controls
    .enable     (rs_ev1_enable_ex),
    // input data
    .opcode     (rs_ev1_opcode_ex),
    .funct3     (rs_ev1_funct3_ex),
    .funct7     (rs_ev1_funct7_ex),
    .rs1_use    (decode_rs1_use(rs_ev1_opcode_ex)),
    .rs2_use    (decode_rs2_use(rs_ev1_opcode_ex)),
    .rs1_data   (ev1_rs1_data_fwd),
    .rs2_data   (ev1_rs2_data_fwd),
    .imm        (rs_ev1_imm_ex),
    // output data
    .alu_result (ev1_alu_result)
  );

  odd_lane u_od0 (
    // internal controls
    .enable     (rs_od0_enable_ex),
    // input data
    .opcode     (rs_od0_opcode_ex),
    .funct3     (rs_od0_funct3_ex),
    .rs1_use    (decode_rs1_use(rs_od0_opcode_ex)),
    .rs2_use    (decode_rs2_use(rs_od0_opcode_ex)),
    .rs1_data   (od0_rs1_data_fwd),
    .rs2_data   (od0_rs2_data_fwd),
    .imm        (rs_od0_imm_ex),
    .pc         (rs_od0_pc_ex),
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
    .enable     (rs_od1_enable_ex),
    // input data
    .opcode     (rs_od1_opcode_ex),
    .funct3     (rs_od1_funct3_ex),
    .rs1_use    (decode_rs1_use(rs_od1_opcode_ex)),
    .rs2_use    (decode_rs2_use(rs_od1_opcode_ex)),
    .rs1_data   (od1_rs1_data_fwd),
    .rs2_data   (od1_rs2_data_fwd),
    .imm        (rs_od1_imm_ex),
    .pc         (rs_od1_pc_ex),
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
