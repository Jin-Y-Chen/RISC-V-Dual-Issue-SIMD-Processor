`timescale 1ns / 1ps

// S3 rename — free_list + RAT + ROB.
import rv_dis_pkg::*;
import rob_pkg::*;

module rename_core_struct (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  br_map_t     br_map,

  input  logic        i0_lane_sel_rn,  i1_lane_sel_rn,
  input  logic        i0_reg_write_rn, i1_reg_write_rn,
  input  logic        i0_rs1_use_rn,   i0_rs2_use_rn,
  input  logic        i1_rs1_use_rn,   i1_rs2_use_rn,

  input  opcode_t     i0_opcode_rn,  i1_opcode_rn,
  input  funct3_t     i0_funct3_rn,  i1_funct3_rn,
  input  funct7_t     i0_funct7_rn,  i1_funct7_rn,
  input  gpr_addr_t   i0_rd_addr_rn, i0_rs1_addr_rn, i0_rs2_addr_rn,
  input  gpr_addr_t   i1_rd_addr_rn, i1_rs1_addr_rn, i1_rs2_addr_rn,
  input  word_t       i0_imm_rn, i0_pc_rn, i1_imm_rn, i1_pc_rn,

  input  logic        wback0_en, wback1_en,
  input  rob_idx_t    i0_idx_wb, i1_idx_wb,
  input  logic        i0_brch_taken_wb, i1_brch_taken_wb,

  input  logic        resolve_en, resolve_mispred, resolve_win_path,

  output logic        stall_id,

  output logic        i0_valid_disp, i1_valid_disp,
  output logic        i0_lane_sel_disp, i1_lane_sel_disp,
  output logic        i0_reg_write_disp, i1_reg_write_disp,
  output opcode_t     i0_opcode_disp, i1_opcode_disp,
  output funct3_t     i0_funct3_disp, i1_funct3_disp,
  output funct7_t     i0_funct7_disp, i1_funct7_disp,
  output gpr_addr_t   i0_rd_addr_disp, i1_rd_addr_disp,
  output prf_addr_t   i0_ps1_disp, i0_ps2_disp, i0_prd_disp,
  output prf_addr_t   i1_ps1_disp, i1_ps2_disp, i1_prd_disp,
  output rob_idx_t    i0_rob_idx_disp, i1_rob_idx_disp,
  output word_t       i0_imm_disp, i1_imm_disp, i0_pc_disp, i1_pc_disp,

  output logic        i0_en, i1_en,
  output gpr_addr_t   i0_rd_addr, i1_rd_addr,
  output prf_addr_t   i0_prd_tag, i1_prd_tag,
  output prf_addr_t   i0_prd_old, i1_prd_old
);

  logic      fl_ok0, fl_ok1, rob_stall;
  logic      br_resolve_en, rat_path;
  prf_addr_t fl_t0, fl_t1, old0, old1;

  wire i0_br    = (i0_opcode_rn == OPC_BRANCH);
  wire i1_br    = (i1_opcode_rn == OPC_BRANCH);
  wire i0_issue = i0_reg_write_rn || i0_br ||
                  (i0_opcode_rn == OPC_JAL) || (i0_opcode_rn == OPC_JALR) ||
                  (i0_opcode_rn == OPC_STORE);
  wire i1_issue = i1_reg_write_rn || i1_br ||
                  (i1_opcode_rn == OPC_JAL) || (i1_opcode_rn == OPC_JALR) ||
                  (i1_opcode_rn == OPC_STORE);

  wire need_fl = i0_reg_write_rn || i1_reg_write_rn;
  wire fl_ok   = (i0_reg_write_rn && i1_reg_write_rn) ? fl_ok1 :
                 need_fl ? fl_ok0 : 1'b1;
  wire go = !flush && !(resolve_en && resolve_mispred) && !rob_stall &&
            (i0_issue || i1_issue) && (!need_fl || fl_ok);

  assign stall_id = !flush && (i0_issue || i1_issue) && !go;

  wire prf_addr_t prd0 = i0_reg_write_rn ? fl_t0 : old0;
  wire prf_addr_t prd1 = i1_reg_write_rn ? fl_t1 : old1;

  // Commit: new_tag→RAT, old_tag→free_list (gated by i0/i1_en from ROB).
  free_list u_free_list (
    .clk(clk), .rst_n(rst_n), .flush(flush),
    .rename0_en(go && i0_reg_write_rn), .rename1_en(go && i1_reg_write_rn),
    .i0_alloc_tag(fl_t0), .i1_alloc_tag(fl_t1),
    .alloc0_valid(fl_ok0), .alloc1_valid(fl_ok1),
    .free0_en(i0_en), .free1_en(i1_en),
    .i0_free_tag(i0_prd_old), .i1_free_tag(i1_prd_old)
  );

  allis_table u_allis (
    .clk(clk), .rst_n(rst_n), .flush(flush), .brch_map(br_map),
    .i0_rs1_use(i0_rs1_use_rn), .i0_rs2_use(i0_rs2_use_rn),
    .i1_rs1_use(i1_rs1_use_rn), .i1_rs2_use(i1_rs2_use_rn),
    .i0_rs1_addr(i0_rs1_addr_rn), .i0_rs2_addr(i0_rs2_addr_rn),
    .i1_rs1_addr(i1_rs1_addr_rn), .i1_rs2_addr(i1_rs2_addr_rn),
    .i0_ps1_tag(i0_ps1_disp), .i0_ps2_tag(i0_ps2_disp),
    .i1_ps1_tag(i1_ps1_disp), .i1_ps2_tag(i1_ps2_disp),
    .i0_reg_write(go && i0_reg_write_rn), .i1_reg_write(go && i1_reg_write_rn),
    .i0_rd_addr(i0_rd_addr_rn), .i1_rd_addr(i1_rd_addr_rn),
    .i0_alloc_tag(fl_t0), .i1_alloc_tag(fl_t1),
    .i0_old_tag(old0), .i1_old_tag(old1),
    .i0_en(i0_en), .i1_en(i1_en),
    .i0_commit_rd_addr(i0_rd_addr), .i1_commit_rd_addr(i1_rd_addr),
    .i0_commit_prd_tag(i0_prd_tag), .i1_commit_prd_tag(i1_prd_tag),
    .resolve_en(br_resolve_en), .rat_path(rat_path)
  );

  reorder_buffer u_rob (
    .clk(clk), .rst_n(rst_n), .flush(flush),
    .alloc0_en(go && i0_issue), .alloc1_en(go && i1_issue),
    .alloc0_reg_write(i0_reg_write_rn), .alloc1_reg_write(i1_reg_write_rn),
    .alloc0_is_brnch(i0_br), .alloc1_is_brnch(i1_br),
    .i0_alloc_rd_addr(i0_rd_addr_rn), .i1_alloc_rd_addr(i1_rd_addr_rn),
    .i0_alloc_prd_tag(prd0), .i1_alloc_prd_tag(prd1),
    .i0_alloc_prd_old(old0), .i1_alloc_prd_old(old1),
    .brch_map(br_map),
    .i0_rob_idx(i0_rob_idx_disp), .i1_rob_idx(i1_rob_idx_disp),
    .stall(rob_stall),
    .wback0_en(wback0_en), .wback1_en(wback1_en),
    .i0_idx_wb(i0_idx_wb), .i1_idx_wb(i1_idx_wb),
    .i0_brch_taken_wb(i0_brch_taken_wb), .i1_brch_taken_wb(i1_brch_taken_wb),
    .i0_en(i0_en), .i1_en(i1_en),
    .i0_rd_addr(i0_rd_addr), .i1_rd_addr(i1_rd_addr),
    .i0_prd_tag(i0_prd_tag), .i1_prd_tag(i1_prd_tag),
    .i0_prd_old(i0_prd_old), .i1_prd_old(i1_prd_old),
    .resolve_en(br_resolve_en), .rat_path(rat_path)
  );

  assign i0_valid_disp     = go && i0_issue;
  assign i1_valid_disp     = go && i1_issue;
  assign i0_lane_sel_disp  = i0_lane_sel_rn;
  assign i1_lane_sel_disp  = i1_lane_sel_rn;
  assign i0_reg_write_disp = i0_reg_write_rn;
  assign i1_reg_write_disp = i1_reg_write_rn;
  assign i0_opcode_disp    = i0_opcode_rn;
  assign i1_opcode_disp    = i1_opcode_rn;
  assign i0_funct3_disp    = i0_funct3_rn;
  assign i1_funct3_disp    = i1_funct3_rn;
  assign i0_funct7_disp    = i0_funct7_rn;
  assign i1_funct7_disp    = i1_funct7_rn;
  assign i0_rd_addr_disp   = i0_rd_addr_rn;
  assign i1_rd_addr_disp   = i1_rd_addr_rn;
  assign i0_prd_disp       = prd0;
  assign i1_prd_disp       = prd1;
  assign i0_imm_disp       = i0_imm_rn;
  assign i1_imm_disp       = i1_imm_rn;
  assign i0_pc_disp        = i0_pc_rn;
  assign i1_pc_disp        = i1_pc_rn;

endmodule
