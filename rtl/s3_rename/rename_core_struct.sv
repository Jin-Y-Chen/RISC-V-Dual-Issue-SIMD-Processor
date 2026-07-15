`timescale 1ns / 1ps

// S3 rename core — Free List + RAT (allis_table) + ROB.
// Rename flow (dual-issue):
 //   1) Free List allocates new destination pregs (if rd_wen).
 //   2) RAT maps sources → physical; dest update returns old preg.
 //   3) ROB records meta + new/old preg; commit returns old preg to Free List.
import rv_dis_pkg::*;
import rob_pkg::*;

module rename_core_struct (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  br_map_t     br_map,

  // ID/RN controls
  input  logic        i0_valid_rn,
  input  logic        i0_lane_sel_rn,
  input  logic        i0_reg_write_rn,
  input  logic        i0_rs1_use_rn,
  input  logic        i0_rs2_use_rn,
  input  logic        i1_valid_rn,
  input  logic        i1_lane_sel_rn,
  input  logic        i1_reg_write_rn,
  input  logic        i1_rs1_use_rn,
  input  logic        i1_rs2_use_rn,

  // ID/RN data
  input  opcode_t     i0_opcode_rn,
  input  funct3_t     i0_funct3_rn,
  input  funct7_t     i0_funct7_rn,
  input  gpr_addr_t   i0_rd_addr_rn,
  input  gpr_addr_t   i0_rs1_addr_rn,
  input  gpr_addr_t   i0_rs2_addr_rn,
  input  word_t       i0_imm_rn,
  input  word_t       i0_pc_rn,
  input  opcode_t     i1_opcode_rn,
  input  funct3_t     i1_funct3_rn,
  input  funct7_t     i1_funct7_rn,
  input  gpr_addr_t   i1_rd_addr_rn,
  input  gpr_addr_t   i1_rs1_addr_rn,
  input  gpr_addr_t   i1_rs2_addr_rn,
  input  word_t       i1_imm_rn,
  input  word_t       i1_pc_rn,

  // EX complete → ROB (by allocated index)
  input  logic        complete0_en,
  input  logic        complete1_en,
  input  logic [ROB_AW-1:0] complete0_idx,
  input  logic [ROB_AW-1:0] complete1_idx,
  input  word_t       complete0_result,
  input  word_t       complete1_result,

  // stall back to ID/RN
  output logic        stall_id,

  // renamed outputs (for rn_dp / dispatch)
  output logic        i0_valid_disp,
  output logic        i1_valid_disp,
  output logic        i0_lane_sel_disp,
  output logic        i1_lane_sel_disp,
  output logic        i0_reg_write_disp,
  output logic        i1_reg_write_disp,
  output opcode_t     i0_opcode_disp,
  output opcode_t     i1_opcode_disp,
  output funct3_t     i0_funct3_disp,
  output funct3_t     i1_funct3_disp,
  output funct7_t     i0_funct7_disp,
  output funct7_t     i1_funct7_disp,
  output gpr_addr_t   i0_rd_addr_disp,
  output gpr_addr_t   i1_rd_addr_disp,
  output prf_addr_t   i0_ps1_disp,
  output prf_addr_t   i0_ps2_disp,
  output prf_addr_t   i0_prd_disp,
  output prf_addr_t   i1_ps1_disp,
  output prf_addr_t   i1_ps2_disp,
  output prf_addr_t   i1_prd_disp,
  output logic [ROB_AW-1:0] i0_rob_idx_disp,
  output logic [ROB_AW-1:0] i1_rob_idx_disp,
  output word_t       i0_imm_disp,
  output word_t       i1_imm_disp,
  output word_t       i0_pc_disp,
  output word_t       i1_pc_disp,

  // commit ports (PRF writeback / exception)
  output logic        commit0_en,
  output logic        commit1_en,
  output logic        commit0_reg_write,
  output logic        commit1_reg_write,
  output gpr_addr_t   commit0_rd_addr,
  output gpr_addr_t   commit1_rd_addr,
  output prf_addr_t   commit0_prd,
  output prf_addr_t   commit1_prd,
  output word_t       commit0_result,
  output word_t       commit1_result
);

  // -------------------------------------------------------------------------
  // Rename request decode
  // -------------------------------------------------------------------------
  wire i0_rd_wen = i0_valid_rn && i0_reg_write_rn && (i0_rd_addr_rn != '0);
  wire i1_rd_wen = i1_valid_rn && i1_reg_write_rn && (i1_rd_addr_rn != '0);
  wire has_valid = i0_valid_rn || i1_valid_rn;

  wire fl_req0 = i0_rd_wen;
  wire fl_req1 = i1_rd_wen;

  logic      fl_alloc_ready;
  logic      rob_alloc_ready;
  prf_addr_t fl_alloc0_preg;
  prf_addr_t fl_alloc1_preg;

  // ROB always takes two ways; Free List still sized to actual rd writes.
  wire can_rename  = has_valid && fl_alloc_ready && rob_alloc_ready;
  wire rename_fire = enable && !flush && can_rename;

  assign stall_id = enable && !flush && has_valid && !can_rename;

  wire fl_alloc0 = rename_fire && fl_req0;
  wire fl_alloc1 = rename_fire && fl_req1;

  // -------------------------------------------------------------------------
  // Build ID metadata for ROB
  // -------------------------------------------------------------------------
  ID_packet_t i0_meta;
  ID_packet_t i1_meta;

  always_comb begin
    i0_meta = '0;
    i0_meta.lane_sel  = i0_lane_sel_rn;
    i0_meta.reg_write = i0_reg_write_rn;
    i0_meta.opcode    = i0_opcode_rn;
    i0_meta.funct3    = i0_funct3_rn;
    i0_meta.funct7    = i0_funct7_rn;
    i0_meta.rs1       = i0_rs1_addr_rn;
    i0_meta.rs2       = i0_rs2_addr_rn;
    i0_meta.imm       = i0_imm_rn;
    i0_meta.pc        = i0_pc_rn;

    i1_meta = '0;
    i1_meta.lane_sel  = i1_lane_sel_rn;
    i1_meta.reg_write = i1_reg_write_rn;
    i1_meta.opcode    = i1_opcode_rn;
    i1_meta.funct3    = i1_funct3_rn;
    i1_meta.funct7    = i1_funct7_rn;
    i1_meta.rs1       = i1_rs1_addr_rn;
    i1_meta.rs2       = i1_rs2_addr_rn;
    i1_meta.imm       = i1_imm_rn;
    i1_meta.pc        = i1_pc_rn;
  end

  // -------------------------------------------------------------------------
  // Free List ↔ ROB commit reclaim
  // -------------------------------------------------------------------------
  logic        cmt0_en, cmt1_en;
  logic        cmt0_reg_write, cmt1_reg_write;
  gpr_addr_t   cmt0_rd_addr, cmt1_rd_addr;
  prf_addr_t   cmt0_prd, cmt1_prd;
  prf_addr_t   cmt0_prd_old, cmt1_prd_old;
  word_t       cmt0_result, cmt1_result;

  wire fl_free0 = cmt0_en && cmt0_reg_write;
  wire fl_free1 = cmt1_en && cmt1_reg_write;

  free_list u_free_list (
    .clk         (clk),
    .rst_n       (rst_n),
    .enable      (enable),
    .flush       (flush),
    .alloc_req0  (fl_req0),
    .alloc_req1  (fl_req1),
    .alloc0_en   (fl_alloc0),
    .alloc1_en   (fl_alloc1),
    .alloc0_preg (fl_alloc0_preg),
    .alloc1_preg (fl_alloc1_preg),
    .alloc_ready (fl_alloc_ready),
    .free0_en    (fl_free0),
    .free1_en    (fl_free1),
    .free0_preg  (cmt0_prd_old),
    .free1_preg  (cmt1_prd_old)
  );

  // -------------------------------------------------------------------------
  // RAT (allis_table) — speculative + architected maps inside the module
  // -------------------------------------------------------------------------
  prf_addr_t i0_ps1, i0_ps2, i1_ps1, i1_ps2;
  prf_addr_t i0_prd_old, i1_prd_old;

  prf_addr_t i0_prd;
  prf_addr_t i1_prd;
  assign i0_prd = fl_req0 ? fl_alloc0_preg : i0_prd_old;
  assign i1_prd = fl_req1 ? fl_alloc1_preg : i1_prd_old;

  allis_table u_allis (
    .clk             (clk),
    .rst_n           (rst_n),
    .flush           (flush),
    .br_map          (br_map),
    .i0_rs1_use      (i0_rs1_use_rn),
    .i0_rs2_use      (i0_rs2_use_rn),
    .i1_rs1_use      (i1_rs1_use_rn),
    .i1_rs2_use      (i1_rs2_use_rn),
    .i0_rs1_addr     (arch_addr_t'(i0_rs1_addr_rn)),
    .i0_rs2_addr     (arch_addr_t'(i0_rs2_addr_rn)),
    .i1_rs1_addr     (arch_addr_t'(i1_rs1_addr_rn)),
    .i1_rs2_addr     (arch_addr_t'(i1_rs2_addr_rn)),
    .i0_ps1_tag      (i0_ps1),
    .i0_ps2_tag      (i0_ps2),
    .i1_ps1_tag      (i1_ps1),
    .i1_ps2_tag      (i1_ps2),
    .i0_rd_wen       (fl_alloc0),
    .i1_rd_wen       (fl_alloc1),
    .i0_rd_addr      (arch_addr_t'(i0_rd_addr_rn)),
    .i1_rd_addr      (arch_addr_t'(i1_rd_addr_rn)),
    .i0_prd_new_tag  (fl_alloc0_preg),
    .i1_prd_new_tag  (fl_alloc1_preg),
    .i0_prd_old_tag  (i0_prd_old),
    .i1_prd_old_tag  (i1_prd_old),
    .commit0_en      (fl_free0),
    .commit1_en      (fl_free1),
    .commit0_rd_addr (arch_addr_t'(cmt0_rd_addr)),
    .commit1_rd_addr (arch_addr_t'(cmt1_rd_addr)),
    .commit0_prd     (cmt0_prd),
    .commit1_prd     (cmt1_prd)
  );


  // -------------------------------------------------------------------------
  // ROB
  // -------------------------------------------------------------------------
  logic [ROB_AW-1:0] rob_idx0, rob_idx1;
  rob_ptr_t          rob_write_ptr, rob_commit_ptr;
  rob_line_t         rob_bank [ROB_WAYS];
  gpr_addr_t         rob_tag  [ROB_WAYS];

  reorder_buffer u_rob (
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (enable),
    .flush            (flush),
    .alloc_en         (rename_fire),
    .alloc0_valid     (i0_valid_rn),
    .alloc1_valid     (i1_valid_rn),
    .alloc0_reg_write (i0_rd_wen),
    .alloc1_reg_write (i1_rd_wen),
    .alloc0_rd_addr   (i0_rd_addr_rn),
    .alloc1_rd_addr   (i1_rd_addr_rn),
    .alloc0_prd       (i0_prd),
    .alloc1_prd       (i1_prd),
    .alloc0_prd_old   (i0_prd_old),
    .alloc1_prd_old   (i1_prd_old),
    .alloc0_meta      (i0_meta),
    .alloc1_meta      (i1_meta),
    .alloc0_idx       (rob_idx0),
    .alloc1_idx       (rob_idx1),
    .alloc_ready      (rob_alloc_ready),
    .complete0_en     (complete0_en),
    .complete1_en     (complete1_en),
    .complete0_idx    (complete0_idx),
    .complete1_idx    (complete1_idx),
    .complete0_result (complete0_result),
    .complete1_result (complete1_result),
    .commit0_en       (cmt0_en),
    .commit1_en       (cmt1_en),
    .commit0_reg_write(cmt0_reg_write),
    .commit1_reg_write(cmt1_reg_write),
    .commit0_rd_addr  (cmt0_rd_addr),
    .commit1_rd_addr  (cmt1_rd_addr),
    .commit0_prd      (cmt0_prd),
    .commit1_prd      (cmt1_prd),
    .commit0_prd_old  (cmt0_prd_old),
    .commit1_prd_old  (cmt1_prd_old),
    .commit0_result   (cmt0_result),
    .commit1_result   (cmt1_result),
    .write_ptr        (rob_write_ptr),
    .commit_ptr       (rob_commit_ptr),
    .bank             (rob_bank),
    .tag              (rob_tag)
  );

  // -------------------------------------------------------------------------
  // Dispatch-facing rename bundle (valid on rename_fire)
  // -------------------------------------------------------------------------
  assign i0_valid_disp     = rename_fire && i0_valid_rn;
  assign i1_valid_disp     = rename_fire && i1_valid_rn;
  assign i0_lane_sel_disp  = i0_lane_sel_rn;
  assign i1_lane_sel_disp  = i1_lane_sel_rn;
  assign i0_reg_write_disp = i0_rd_wen;
  assign i1_reg_write_disp = i1_rd_wen;
  assign i0_opcode_disp    = i0_opcode_rn;
  assign i1_opcode_disp    = i1_opcode_rn;
  assign i0_funct3_disp    = i0_funct3_rn;
  assign i1_funct3_disp    = i1_funct3_rn;
  assign i0_funct7_disp    = i0_funct7_rn;
  assign i1_funct7_disp    = i1_funct7_rn;
  assign i0_rd_addr_disp   = i0_rd_addr_rn;
  assign i1_rd_addr_disp   = i1_rd_addr_rn;
  assign i0_ps1_disp       = i0_ps1;
  assign i0_ps2_disp       = i0_ps2;
  assign i0_prd_disp       = i0_prd;
  assign i1_ps1_disp       = i1_ps1;
  assign i1_ps2_disp       = i1_ps2;
  assign i1_prd_disp       = i1_prd;
  assign i0_rob_idx_disp   = rob_idx0;
  assign i1_rob_idx_disp   = rob_idx1;
  assign i0_imm_disp       = i0_imm_rn;
  assign i1_imm_disp       = i1_imm_rn;
  assign i0_pc_disp        = i0_pc_rn;
  assign i1_pc_disp        = i1_pc_rn;

  assign commit0_en        = cmt0_en;
  assign commit1_en        = cmt1_en;
  assign commit0_reg_write = cmt0_reg_write;
  assign commit1_reg_write = cmt1_reg_write;
  assign commit0_rd_addr   = cmt0_rd_addr;
  assign commit1_rd_addr   = cmt1_rd_addr;
  assign commit0_prd       = cmt0_prd;
  assign commit1_prd       = cmt1_prd;
  assign commit0_result    = cmt0_result;
  assign commit1_result    = cmt1_result;

endmodule
