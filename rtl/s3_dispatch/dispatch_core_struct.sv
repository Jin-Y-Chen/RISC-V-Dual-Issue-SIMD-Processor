`timescale 1ns / 1ps

// S3 dispatch core — ROB, branch speculation, rename/route (combinational dispatch).
// Upstream: id_dp (ID/DP register). Downstream: dp_ex (DP/EX register) -> reservation stations.
//
//   reorder_buffer   — add / read / update / clear
//   branch_speculate — NEW vs SPEC_NEW, br_inflight
//   rename_dispatch  — operand forward + route to ev0/ev1/od0/od1
//
// Entry lifecycle (rob_state_t):
//   NEW(000)/SPEC_NEW(100) -> READ(001)/SPEC_READ(101) -> EXEC(010)/SPEC_EXEC(110) -> clear
module dispatch_core_struct
  import rv_dis_pkg::*;
  import rob_pkg::*;
  import rob_queue_pkg::*;
  import rob_rename_pkg::*;

(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,

  input  logic        commit_en,
  input  logic [1:0]  commit_count,

  input  logic            set_complete_en,
  input  logic [ROB_AW-1:0] set_complete_idx,
  input  word_t           set_complete_result,

  input  logic        i0_valid_dp,
  input  logic        i0_lane_sel_dp,
  input  logic        i0_reg_write_dp,
  input  logic        i1_valid_dp,
  input  logic        i1_lane_sel_dp,
  input  logic        i1_rs1_use_dp,
  input  logic        i1_rs2_use_dp,
  input  logic        i1_reg_write_dp,
  input  opcode_t     i0_opcode_dp,
  input  funct3_t     i0_funct3_dp,
  input  funct7_t     i0_funct7_dp,
  input  gpr_addr_t   i0_rd_addr_dp,
  input  gpr_addr_t   i0_rs1_addr_dp,
  input  gpr_addr_t   i0_rs2_addr_dp,
  input  word_t       i0_imm_dp,
  input  word_t       i0_rs1_data_dp,
  input  word_t       i0_rs2_data_dp,
  input  word_t       i0_pc_dp,
  input  opcode_t     i1_opcode_dp,
  input  funct3_t     i1_funct3_dp,
  input  funct7_t     i1_funct7_dp,
  input  gpr_addr_t   i1_rd_addr_dp,
  input  gpr_addr_t   i1_rs1_addr_dp,
  input  gpr_addr_t   i1_rs2_addr_dp,
  input  word_t       i1_imm_dp,
  input  word_t       i1_rs1_data_dp,
  input  word_t       i1_rs2_data_dp,
  input  word_t       i1_pc_dp,

  output logic        stall_id,

  output logic        i0_reg_write_disp,
  output logic        i1_reg_write_disp,
  output word_t       i0_pc_disp,
  output word_t       i1_pc_disp,

  output logic        ev0_enable_disp,
  output opcode_t     ev0_opcode_disp,
  output funct3_t     ev0_funct3_disp,
  output funct7_t     ev0_funct7_disp,
  output gpr_addr_t   ev0_rd_disp,
  output gpr_addr_t   ev0_rs1_addr_disp,
  output gpr_addr_t   ev0_rs2_addr_disp,
  output word_t       ev0_imm_disp,
  output word_t       ev0_rs1_data_disp,
  output word_t       ev0_rs2_data_disp,
  output word_t       ev0_pc_disp,

  output logic        ev1_enable_disp,
  output opcode_t     ev1_opcode_disp,
  output funct3_t     ev1_funct3_disp,
  output funct7_t     ev1_funct7_disp,
  output gpr_addr_t   ev1_rd_disp,
  output gpr_addr_t   ev1_rs1_addr_disp,
  output gpr_addr_t   ev1_rs2_addr_disp,
  output word_t       ev1_imm_disp,
  output word_t       ev1_rs1_data_disp,
  output word_t       ev1_rs2_data_disp,
  output word_t       ev1_pc_disp,

  output logic        od0_enable_disp,
  output opcode_t     od0_opcode_disp,
  output funct3_t     od0_funct3_disp,
  output gpr_addr_t   od0_rd_disp,
  output gpr_addr_t   od0_rs1_addr_disp,
  output gpr_addr_t   od0_rs2_addr_disp,
  output word_t       od0_imm_disp,
  output word_t       od0_rs1_data_disp,
  output word_t       od0_rs2_data_disp,
  output word_t       od0_pc_disp,

  output logic        od1_enable_disp,
  output opcode_t     od1_opcode_disp,
  output funct3_t     od1_funct3_disp,
  output gpr_addr_t   od1_rd_disp,
  output gpr_addr_t   od1_rs1_addr_disp,
  output gpr_addr_t   od1_rs2_addr_disp,
  output word_t       od1_imm_disp,
  output word_t       od1_rs1_data_disp,
  output word_t       od1_rs2_data_disp,
  output word_t       od1_pc_disp
);

  // Re-export for TB hierarchical access (rob_entries.txt)
  rob_ptr_t        rob_write_ptr;
  rob_ptr_t        rob_read_ptr;
  rob_ptr_t        rob_commit_ptr;
  rob_ptr_t        br_inflight;
  logic [ROB_DATA_W:0] rob_bank [ROB_WAYS];
  gpr_addr_t           rob_tag  [ROB_WAYS];

  // -------------------------------------------------------------------------
  // Flow control — allocate side (NEW entry)
  // -------------------------------------------------------------------------
  wire [1:0]     in_valids  = rob_in_valids(i0_valid_dp, i1_valid_dp);
  wire rob_ptr_t rob_count  = rob_occupancy(rob_write_ptr, rob_commit_ptr);
  wire rob_ptr_t rob_free   = rob_free_slots(rob_count);
  wire           can_alloc  = rob_can_alloc(rob_free, in_valids);
  wire           add_en     = enable && !flush && (in_valids != 2'd0) && can_alloc;

  assign stall_id = rob_stall_fetch(enable, flush, in_valids, can_alloc);

  wire [ROB_AW-1:0] write_idx   = rob_write_ptr[ROB_AW-1:0];
  wire [ROB_AW-1:0] read_idx0   = rob_read_ptr[ROB_AW-1:0];
  wire [ROB_AW-1:0] read_idx1   = rob_read_ptr[ROB_AW-1:0] + 1'b1;
  wire [ROB_AW-1:0] commit_idx0 = rob_commit_ptr[ROB_AW-1:0];
  wire [ROB_AW-1:0] commit_idx1 = rob_commit_ptr[ROB_AW-1:0] + 1'b1;

  // -------------------------------------------------------------------------
  // Branch speculation — SPEC_NEW vs NEW on add
  // -------------------------------------------------------------------------
  logic spec_i0;
  logic spec_i1;

  branch_speculate u_branch_speculate (
    .clk          (clk),
    .rst_n        (rst_n),
    .enable       (enable),
    .flush        (flush),
    .add_en       (add_en),
    .i0_valid     (i0_valid_dp),
    .i0_opcode    (i0_opcode_dp),
    .i1_valid     (i1_valid_dp),
    .i1_opcode    (i1_opcode_dp),
    .clear_en     (commit_en),
    .clear_count  (commit_count),
    .cmt0_opcode  (rob_cache_data_read(rob_bank[commit_idx0], '0).packet.opcode),
    .cmt1_opcode  (rob_cache_data_read(rob_bank[commit_idx1], '0).packet.opcode),
    .spec_i0      (spec_i0),
    .spec_i1      (spec_i1),
    .br_inflight  (br_inflight)
  );

  wire [ROB_DATA_W:0] add_line0 = rob_entry_to_cache(bundle_i0(
    i0_valid_dp, i0_lane_sel_dp, i0_reg_write_dp,
    i0_opcode_dp, i0_funct3_dp, i0_funct7_dp,
    i0_rd_addr_dp, i0_rs1_addr_dp, i0_rs2_addr_dp,
    i0_imm_dp, i0_rs1_data_dp, i0_rs2_data_dp, i0_pc_dp,
    rob_state_on_alloc(spec_i0), '0
  ));
  wire [ROB_DATA_W:0] add_line1 = rob_entry_to_cache(bundle_i1(
    i1_valid_dp, i1_lane_sel_dp, i1_reg_write_dp,
    i1_rs1_use_dp, i1_rs2_use_dp,
    i1_opcode_dp, i1_funct3_dp, i1_funct7_dp,
    i1_rd_addr_dp, i1_rs1_addr_dp, i1_rs2_addr_dp,
    i1_imm_dp, i1_rs1_data_dp, i1_rs2_data_dp, i1_pc_dp,
    rob_state_on_alloc(spec_i1), '0
  ));

  // -------------------------------------------------------------------------
  // READ entry — dispatch eligibility from ROB head state
  // -------------------------------------------------------------------------
  rob_data_t read_data0;
  rob_data_t read_data1;

  wire rob_ptr_t pending = rob_pending_dispatch(rob_write_ptr, rob_read_ptr);
  wire disp0 = rob_disp0_en(pending, read_data0.state);
  wire disp1 = rob_disp1_en(disp0, pending, read_data1.state);
  wire [1:0] read_advance_count = rob_dispatch_count(disp0, disp1);

  // -------------------------------------------------------------------------
  // Reorder Buffer — add / read / update / clear
  // -------------------------------------------------------------------------
  reorder_buffer u_rob (
    .clk                (clk),
    .rst_n              (rst_n),
    .enable             (enable),
    .flush              (flush),
    .add_en             (add_en),
    .add_count          (in_valids),
    .add_idx0           (write_idx),
    .add_idx1           (write_idx + ROB_AW'(i0_valid_dp)),
    .add0_valid         (i0_valid_dp),
    .add1_valid         (i1_valid_dp),
    .add_line0          (add_line0),
    .add_line1          (add_line1),
    .add_tag0           (i0_rd_addr_dp),
    .add_tag1           (i1_rd_addr_dp),
    .read_idx0          (read_idx0),
    .read_idx1          (read_idx1),
    .read_data0         (read_data0),
    .read_data1         (read_data1),
    .read_tag0          (),
    .read_tag1          (),
    .read_advance0      (disp0),
    .read_advance1      (disp1),
    .read_advance_count (read_advance_count),
    .update_en          (set_complete_en),
    .update_idx         (set_complete_idx),
    .update_result      (set_complete_result),
    .clear_en           (commit_en),
    .clear_count        (commit_count),
    .clear_idx0         (commit_idx0),
    .clear_idx1         (commit_idx1),
    .write_ptr          (rob_write_ptr),
    .read_ptr           (rob_read_ptr),
    .commit_ptr         (rob_commit_ptr),
    .bank               (rob_bank),
    .tag                (rob_tag)
  );

  // -------------------------------------------------------------------------
  // Rename — forward operands + route to execute lanes
  // -------------------------------------------------------------------------
  EX_packet_t rob_head0;
  EX_packet_t rob_head1;
  EX_packet_t i0_out;
  EX_packet_t i1_out;
  EX_packet_t ev0_pkt;
  EX_packet_t ev1_pkt;
  EX_packet_t od0_pkt;
  EX_packet_t od1_pkt;
  logic       i0_reg_write;
  logic       i1_reg_write;

  rename_dispatch u_rename (
    .bank          (rob_bank),
    .tag           (rob_tag),
    .commit_ptr    (rob_commit_ptr),
    .write_ptr     (rob_write_ptr),
    .read_idx0     (read_idx0),
    .read_idx1     (read_idx1),
    .disp0         (disp0),
    .disp1         (disp1),
    .rob_head0     (rob_head0),
    .rob_head1     (rob_head1),
    .i0_out        (i0_out),
    .i1_out        (i1_out),
    .ev0_pkt       (ev0_pkt),
    .ev1_pkt       (ev1_pkt),
    .od0_pkt       (od0_pkt),
    .od1_pkt       (od1_pkt),
    .i0_reg_write  (i0_reg_write),
    .i1_reg_write  (i1_reg_write)
  );

  assign i0_reg_write_disp = i0_reg_write;
  assign i1_reg_write_disp = i1_reg_write;
  assign i0_pc_disp        = i0_out.packet.pc;
  assign i1_pc_disp        = i1_out.packet.pc;

  assign ev0_enable_disp   = ev0_pkt.valid;
  assign ev0_opcode_disp   = ev0_pkt.packet.opcode;
  assign ev0_funct3_disp   = ev0_pkt.packet.funct3;
  assign ev0_funct7_disp   = ev0_pkt.packet.funct7;
  assign ev0_rd_disp       = ev0_pkt.renamed_tag;
  assign ev0_rs1_addr_disp = ev0_pkt.packet.rs1;
  assign ev0_rs2_addr_disp = ev0_pkt.packet.rs2;
  assign ev0_imm_disp      = ev0_pkt.packet.imm;
  assign ev0_rs1_data_disp = ev0_pkt.packet.rs1_data;
  assign ev0_rs2_data_disp = ev0_pkt.packet.rs2_data;
  assign ev0_pc_disp       = ev0_pkt.packet.pc;

  assign ev1_enable_disp   = ev1_pkt.valid;
  assign ev1_opcode_disp   = ev1_pkt.packet.opcode;
  assign ev1_funct3_disp   = ev1_pkt.packet.funct3;
  assign ev1_funct7_disp   = ev1_pkt.packet.funct7;
  assign ev1_rd_disp       = ev1_pkt.renamed_tag;
  assign ev1_rs1_addr_disp = ev1_pkt.packet.rs1;
  assign ev1_rs2_addr_disp = ev1_pkt.packet.rs2;
  assign ev1_imm_disp      = ev1_pkt.packet.imm;
  assign ev1_rs1_data_disp = ev1_pkt.packet.rs1_data;
  assign ev1_rs2_data_disp = ev1_pkt.packet.rs2_data;
  assign ev1_pc_disp       = ev1_pkt.packet.pc;

  assign od0_enable_disp   = od0_pkt.valid;
  assign od0_opcode_disp   = od0_pkt.packet.opcode;
  assign od0_funct3_disp   = od0_pkt.packet.funct3;
  assign od0_rd_disp       = od0_pkt.renamed_tag;
  assign od0_rs1_addr_disp = od0_pkt.packet.rs1;
  assign od0_rs2_addr_disp = od0_pkt.packet.rs2;
  assign od0_imm_disp      = od0_pkt.packet.imm;
  assign od0_rs1_data_disp = od0_pkt.packet.rs1_data;
  assign od0_rs2_data_disp = od0_pkt.packet.rs2_data;
  assign od0_pc_disp       = od0_pkt.packet.pc;

  assign od1_enable_disp   = od1_pkt.valid;
  assign od1_opcode_disp   = od1_pkt.packet.opcode;
  assign od1_funct3_disp   = od1_pkt.packet.funct3;
  assign od1_rd_disp       = od1_pkt.renamed_tag;
  assign od1_rs1_addr_disp = od1_pkt.packet.rs1;
  assign od1_rs2_addr_disp = od1_pkt.packet.rs2;
  assign od1_imm_disp      = od1_pkt.packet.imm;
  assign od1_rs1_data_disp = od1_pkt.packet.rs1_data;
  assign od1_rs2_data_disp = od1_pkt.packet.rs2_data;
  assign od1_pc_disp       = od1_pkt.packet.pc;

endmodule
