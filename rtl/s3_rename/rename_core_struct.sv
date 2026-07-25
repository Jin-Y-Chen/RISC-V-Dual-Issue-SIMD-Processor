`timescale 1ns / 1ps

// S3 rename — RAT + ROB (tail alloc). ROB entry owns PRF p32..p63.
// Head commit: retire → RRAT / store-buffer; reclaim = ROB head advance.
import rv_dis_pkg::*;
import rob_pkg::*;

module rename_core_struct (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        stall_rn,
  input  logic        enable,
  input  logic        spec0_en_rn,
  input  logic        spec1_en_rn,

  input  logic        i0_valid_rn,     i1_valid_rn,
  input  logic        i0_lane_sel_rn,  i1_lane_sel_rn,
  input  logic        i0_reg_write_rn, i1_reg_write_rn,
  input  logic        i0_store_en_rn,  i1_store_en_rn,
  input  logic        i0_rs1_use_rn,   i0_rs2_use_rn,
  input  logic        i1_rs1_use_rn,   i1_rs2_use_rn,

  input  opcode_t     i0_opcode_rn,  i1_opcode_rn,
  input  funct3_t     i0_funct3_rn,  i1_funct3_rn,
  input  funct7_t     i0_funct7_rn,  i1_funct7_rn,
  input  gpr_addr_t   i0_rd_addr_rn, i0_rs1_addr_rn, i0_rs2_addr_rn,
  input  gpr_addr_t   i1_rd_addr_rn, i1_rs1_addr_rn, i1_rs2_addr_rn,
  input  word_t       i0_imm_rn, i0_pc_rn, i1_imm_rn, i1_pc_rn,

  input  logic        wback0_en, wback1_en,
  input  prf_addr_t   i0_rob_idx_wb, i1_rob_idx_wb,
  input  logic        i0_brch_taken_wb, i1_brch_taken_wb,

  output logic        stall_id,

  output logic        i0_valid_disp, i1_valid_disp,
  output logic        i0_lane_sel_disp, i1_lane_sel_disp,
  output logic        i0_reg_write_disp, i1_reg_write_disp,
  output logic        i0_spec_en_disp, i1_spec_en_disp,
  output logic        i0_rs1_use_disp, i0_rs2_use_disp,
  output logic        i1_rs1_use_disp, i1_rs2_use_disp,
  output opcode_t     i0_opcode_disp, i1_opcode_disp,
  output funct3_t     i0_funct3_disp, i1_funct3_disp,
  output funct7_t     i0_funct7_disp, i1_funct7_disp,
  output gpr_addr_t   i0_rd_addr_disp, i1_rd_addr_disp,
  output prf_addr_t   i0_ps1_disp, i0_ps2_disp, i0_prd_disp,
  output prf_addr_t   i1_ps1_disp, i1_ps2_disp, i1_prd_disp,
  output prf_addr_t   i0_rob_idx_disp, i1_rob_idx_disp,
  output word_t       i0_imm_disp, i1_imm_disp, i0_pc_disp, i1_pc_disp,

  // → retire unit / RRAT / store buffer
  output logic        retire0_en, retire1_en,
  output logic        rrat0_en, rrat1_en,
  output gpr_addr_t   i0_rd_addr_cmt, i1_rd_addr_cmt,
  output prf_addr_t   i0_rob_idx_cmt, i1_rob_idx_cmt,
  // → store buffer
  output logic        stb0_en, stb1_en
);

  logic stall;
  logic rat0_en, rat1_en;
  logic i0_path_sel, i1_path_sel;
  logic i0_can_retire, i1_can_retire;

  wire i0_br = i0_valid_rn && (i0_opcode_rn == OPC_BRANCH);
  wire i1_br = i1_valid_rn && (i1_opcode_rn == OPC_BRANCH);

  wire i0_wr = i0_valid_rn && i0_reg_write_rn;
  wire i1_wr = i1_valid_rn && i1_reg_write_rn;

  wire go = !flush && !stall_rn && !stall &&
            (i0_valid_rn || i1_valid_rn);

  wire i0_alloc_en = go && i0_wr;
  wire i1_alloc_en = go && i1_wr;
  wire i0_rob_en   = go && i0_valid_rn;
  wire i1_rob_en   = go && i1_valid_rn;

  assign stall_id = !flush && (i0_valid_rn || i1_valid_rn) && !go;

  // ROB alloc tags are already PRF-wide (p32..p63)
  wire prf_addr_t i0_ntag = i0_rob_idx_disp;
  wire prf_addr_t i1_ntag = i1_rob_idx_disp;

  allis_table u_allis (
    .clk, .rst_n, .flush,
    .spec0_en(spec0_en_rn), .spec1_en(spec1_en_rn),
    .i0_rs1_use(i0_rs1_use_rn), .i0_rs2_use(i0_rs2_use_rn),
    .i1_rs1_use(i1_rs1_use_rn), .i1_rs2_use(i1_rs2_use_rn),
    .i0_rs1_addr(i0_rs1_addr_rn), .i0_rs2_addr(i0_rs2_addr_rn),
    .i1_rs1_addr(i1_rs1_addr_rn), .i1_rs2_addr(i1_rs2_addr_rn),
    .i0_ps1_tag(i0_ps1_disp), .i0_ps2_tag(i0_ps2_disp),
    .i1_ps1_tag(i1_ps1_disp), .i1_ps2_tag(i1_ps2_disp),
    .i0_alloc_en, .i1_alloc_en,
    .i0_alloc_rd_addr(i0_rd_addr_rn), .i1_alloc_rd_addr(i1_rd_addr_rn),
    .i0_alloc_ntag(i0_ntag), .i1_alloc_ntag(i1_ntag),
    .rrat0_en, .rrat1_en,
    .i0_rd_addr_cmt, .i1_rd_addr_cmt,
    .i0_rob_idx_cmt, .i1_rob_idx_cmt,
    .rat0_en, .rat1_en,
    .i0_path_sel, .i1_path_sel
  );

  reorder_buffer u_rob (
    .clk, .rst_n, .flush,
    .alloc0_en(i0_rob_en), .alloc1_en(i1_rob_en),
    .i0_reg_write(i0_reg_write_rn), .i1_reg_write(i1_reg_write_rn),
    .i0_is_brnch(i0_br), .i1_is_brnch(i1_br),
    .i0_is_store(i0_store_en_rn), .i1_is_store(i1_store_en_rn),
    .i0_spec_en(spec0_en_rn), .i1_spec_en(spec1_en_rn),
    .i0_rd_addr(i0_rd_addr_rn), .i1_rd_addr(i1_rd_addr_rn),
    .i0_rob_idx(i0_rob_idx_disp), .i1_rob_idx(i1_rob_idx_disp),
    .stall,
    .wback0_en, .wback1_en,
    .i0_rob_idx_wb, .i1_rob_idx_wb,
    .i0_brch_taken_wb, .i1_brch_taken_wb,
    .retire0_en, .retire1_en,
    .i0_can_retire, .i1_can_retire,
    .rrat0_en, .rrat1_en,
    .i0_rd_addr_cmt, .i1_rd_addr_cmt,
    .i0_rob_idx_cmt, .i1_rob_idx_cmt,
    .rat0_en, .rat1_en,
    .i0_path_sel, .i1_path_sel,
    .stb0_en, .stb1_en
  );

  retire u_retire (
    .enable,
    .flush,
    .i0_can_retire, .i1_can_retire,
    .retire0_en, .retire1_en
  );

  assign i0_valid_disp     = i0_rob_en;
  assign i1_valid_disp     = i1_rob_en;
  assign i0_lane_sel_disp  = i0_lane_sel_rn;
  assign i1_lane_sel_disp  = i1_lane_sel_rn;
  assign i0_reg_write_disp = i0_reg_write_rn;
  assign i1_reg_write_disp = i1_reg_write_rn;
  assign i0_spec_en_disp   = spec0_en_rn;
  assign i1_spec_en_disp   = spec1_en_rn;
  assign i0_rs1_use_disp   = i0_rs1_use_rn;
  assign i0_rs2_use_disp   = i0_rs2_use_rn;
  assign i1_rs1_use_disp   = i1_rs1_use_rn;
  assign i1_rs2_use_disp   = i1_rs2_use_rn;
  assign i0_opcode_disp    = i0_opcode_rn;
  assign i1_opcode_disp    = i1_opcode_rn;
  assign i0_funct3_disp    = i0_funct3_rn;
  assign i1_funct3_disp    = i1_funct3_rn;
  assign i0_funct7_disp    = i0_funct7_rn;
  assign i1_funct7_disp    = i1_funct7_rn;
  assign i0_rd_addr_disp   = i0_rd_addr_rn;
  assign i1_rd_addr_disp   = i1_rd_addr_rn;
  assign i0_prd_disp       = i0_wr ? i0_ntag : '0;
  assign i1_prd_disp       = i1_wr ? i1_ntag : '0;
  assign i0_imm_disp       = i0_imm_rn;
  assign i1_imm_disp       = i1_imm_rn;
  assign i0_pc_disp        = i0_pc_rn;
  assign i1_pc_disp        = i1_pc_rn;

endmodule
