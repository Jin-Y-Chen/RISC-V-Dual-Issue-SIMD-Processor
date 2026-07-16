`timescale 1ns / 1ps

// S3 rename — Free List (dest pregs) + RAT + ROB.
import rv_dis_pkg::*;
import rob_pkg::*;

module rename_core_struct (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  br_map_t     br_map,

  input  logic        i0_lane_sel_rn,
  input  logic        i0_reg_write_rn,
  input  logic        i0_rs1_use_rn,
  input  logic        i0_rs2_use_rn,
  input  logic        i1_lane_sel_rn,
  input  logic        i1_reg_write_rn,
  input  logic        i1_rs1_use_rn,
  input  logic        i1_rs2_use_rn,

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

  input  logic        complete0_en,
  input  logic        complete1_en,
  input  logic [ROB_AW-1:0] complete0_idx,
  input  logic [ROB_AW-1:0] complete1_idx,
  input  word_t       complete0_result,
  input  word_t       complete1_result,

  // Branch resolve (from EX/WB); LIFO top of rename checkpoint stack.
  input  logic        resolve_en,
  input  logic        resolve_mispred,
  input  logic        resolve_win_path, // 0 = path0/br0, 1 = path1/br1

  output logic        stall_id,

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

  logic      fl_alloc0_valid, fl_alloc1_valid, rob_alloc_ready;
  prf_addr_t fl_i0_br0, fl_i0_br1, fl_i1_br0, fl_i1_br1;
  prf_addr_t i0_prd_old, i1_prd_old;
  prf_addr_t cmt0_prd_old, cmt1_prd_old;
  logic [2:0] rat_ckpt_ptr;

  // Lane must dispatch if it writes, stores, or is control-flow (NOP bubbles: none).
  wire i0_is_ctrl  = (i0_opcode_rn == OPC_BRANCH) ||
                     (i0_opcode_rn == OPC_JAL)    ||
                     (i0_opcode_rn == OPC_JALR);
  wire i1_is_ctrl  = (i1_opcode_rn == OPC_BRANCH) ||
                     (i1_opcode_rn == OPC_JAL)    ||
                     (i1_opcode_rn == OPC_JALR);
  wire i0_is_store = (i0_opcode_rn == OPC_STORE);
  wire i1_is_store = (i1_opcode_rn == OPC_STORE);
  wire i0_issue    = i0_reg_write_rn || i0_is_ctrl || i0_is_store;
  wire i1_issue    = i1_reg_write_rn || i1_is_ctrl || i1_is_store;

  wire fl_ok = (i0_reg_write_rn && i1_reg_write_rn) ? fl_alloc1_valid :
               (i0_reg_write_rn ||  i1_reg_write_rn) ? fl_alloc0_valid : 1'b1;
  wire go = !flush && !(resolve_en && resolve_mispred) && (i0_issue || i1_issue) &&
            ((i0_reg_write_rn || i1_reg_write_rn) ? (fl_ok && rob_alloc_ready)
                                                  : rob_alloc_ready);

  assign stall_id = !flush && (i0_issue || i1_issue) && !go;

  wire tip_is_i1 = (br_map != BR_MAP_I0);
  wire prf_addr_t fl_i0_tip = tip_is_i1 ? fl_i0_br1 : fl_i0_br0;
  wire prf_addr_t fl_i1_tip = tip_is_i1 ? fl_i1_br1 : fl_i1_br0;
  wire prf_addr_t i0_prd = i0_reg_write_rn ? fl_i0_tip : i0_prd_old;
  wire prf_addr_t i1_prd = i1_reg_write_rn ? fl_i1_tip : i1_prd_old;

  wire ckpt_push = go && (i0_is_ctrl || i1_is_ctrl);

  ID_packet_t i0_meta, i1_meta;
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

  free_list u_free_list (
    .clk         (clk),
    .rst_n       (rst_n),
    .flush       (flush),
    .brch_map    (br_map),
    .rename0_en  (go && i0_reg_write_rn),
    .rename1_en  (go && i1_reg_write_rn),
    .i0_alloc_br0(fl_i0_br0),
    .i0_alloc_br1(fl_i0_br1),
    .i1_alloc_br0(fl_i1_br0),
    .i1_alloc_br1(fl_i1_br1),
    .alloc0_valid(fl_alloc0_valid),
    .alloc1_valid(fl_alloc1_valid),
    .free0_en    (commit0_en && commit0_reg_write),
    .free1_en    (commit1_en && commit1_reg_write),
    .i0_free_tag (cmt0_prd_old),
    .i1_free_tag (cmt1_prd_old)
  );

  allis_table u_allis (
    .clk             (clk),
    .rst_n           (rst_n),
    .flush           (flush),
    .brch_map        (br_map),
    .i0_rs1_use      (i0_rs1_use_rn),
    .i0_rs2_use      (i0_rs2_use_rn),
    .i1_rs1_use      (i1_rs1_use_rn),
    .i1_rs2_use      (i1_rs2_use_rn),
    .i0_rs1_addr     (i0_rs1_addr_rn),
    .i0_rs2_addr     (i0_rs2_addr_rn),
    .i1_rs1_addr     (i1_rs1_addr_rn),
    .i1_rs2_addr     (i1_rs2_addr_rn),
    .i0_ps1_tag      (i0_ps1_disp),
    .i0_ps2_tag      (i0_ps2_disp),
    .i1_ps1_tag      (i1_ps1_disp),
    .i1_ps2_tag      (i1_ps2_disp),
    .i0_reg_write    (go && i0_reg_write_rn),
    .i1_reg_write    (go && i1_reg_write_rn),
    .i0_rd_addr      (i0_rd_addr_rn),
    .i1_rd_addr      (i1_rd_addr_rn),
    .i0_alloc_br0    (fl_i0_br0),
    .i0_alloc_br1    (fl_i0_br1),
    .i1_alloc_br0    (fl_i1_br0),
    .i1_alloc_br1    (fl_i1_br1),
    .i0_old_tag      (i0_prd_old),
    .i1_old_tag      (i1_prd_old),
    .commit0_en      (commit0_en && commit0_reg_write),
    .commit1_en      (commit1_en && commit1_reg_write),
    .commit0_rd_addr (commit0_rd_addr),
    .commit1_rd_addr (commit1_rd_addr),
    .commit0_prd     (commit0_prd),
    .commit1_prd     (commit1_prd),
    .ckpt_push_en    (ckpt_push),
    .rat_ckpt_ptr_out(rat_ckpt_ptr),
    .resolve_en      (resolve_en),
    .resolve_mispred (resolve_mispred),
    .resolve_win_path(resolve_win_path)
  );

  reorder_buffer u_rob (
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (1'b1),
    .flush            (flush),
    .alloc_en         (go),
    .alloc0_valid     (i0_issue),
    .alloc1_valid     (i1_issue),
    .alloc0_reg_write (i0_reg_write_rn),
    .alloc1_reg_write (i1_reg_write_rn),
    .alloc0_rd_addr   (i0_rd_addr_rn),
    .alloc1_rd_addr   (i1_rd_addr_rn),
    .alloc0_prd       (i0_prd),
    .alloc1_prd       (i1_prd),
    .alloc0_prd_old   (i0_prd_old),
    .alloc1_prd_old   (i1_prd_old),
    .alloc0_meta      (i0_meta),
    .alloc1_meta      (i1_meta),
    .alloc0_idx       (i0_rob_idx_disp),
    .alloc1_idx       (i1_rob_idx_disp),
    .alloc_ready      (rob_alloc_ready),
    .complete0_en     (complete0_en),
    .complete1_en     (complete1_en),
    .complete0_idx    (complete0_idx),
    .complete1_idx    (complete1_idx),
    .complete0_result (complete0_result),
    .complete1_result (complete1_result),
    .commit0_en       (commit0_en),
    .commit1_en       (commit1_en),
    .commit0_reg_write(commit0_reg_write),
    .commit1_reg_write(commit1_reg_write),
    .commit0_rd_addr  (commit0_rd_addr),
    .commit1_rd_addr  (commit1_rd_addr),
    .commit0_prd      (commit0_prd),
    .commit1_prd      (commit1_prd),
    .commit0_prd_old  (cmt0_prd_old),
    .commit1_prd_old  (cmt1_prd_old),
    .commit0_result   (commit0_result),
    .commit1_result   (commit1_result),
    .write_ptr        (),
    .commit_ptr       (),
    .bank             (),
    .tag              ()
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
  assign i0_prd_disp       = i0_prd;
  assign i1_prd_disp       = i1_prd;
  assign i0_imm_disp       = i0_imm_rn;
  assign i1_imm_disp       = i1_imm_rn;
  assign i0_pc_disp        = i0_pc_rn;
  assign i1_pc_disp        = i1_pc_rn;

endmodule
