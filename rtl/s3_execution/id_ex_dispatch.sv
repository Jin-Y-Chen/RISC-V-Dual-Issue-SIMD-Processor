`timescale 1ns / 1ps

// ID/EX dispatch stage — the Reorder Buffer (ROB), per project_outline.
// Types and helpers: funct_pkg/rob.sv, rob_branch.sv, rob_rename.sv.
//
// ROB storage uses cache_pkg line format per slot:
//   valid — cache line valid bit (slot occupied)
//   tag   — architectural destination register (rd)
//   data  — rob_data_t (packet + state + result)
//
//   * Three pointers (no entry shifting):
//       - write  (tail) : allocate up to two decoded slots per cycle (I0 then I1)
//       - read   (body) : route oldest undispatched pair to ev0/ev1/od0/od1
//       - commit (head) : retire completed entries (commit_en / commit_count)
//     Occupancy = write - commit; a full ROB back-pressures fetch (stall_id).
module id_ex_dispatch
  import rv_dis_pkg::*;
  import rob_pkg::*;
  import rob_branch_pkg::*;
  import rob_rename_pkg::*;

(
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,

  // commit / retire — advance commit (head) pointer, freeing ROB slots
  input  logic        commit_en,
  input  logic [1:0]  commit_count,

  // execution complete — write result, mark entry executed (010 / 110)
  input  logic            set_complete_en,
  input  logic [ROB_AW-1:0] set_complete_idx,
  input  word_t           set_complete_result,

  // decode bundle controls (I0 = older, I1 = younger)
  input  logic        i0_valid_id,
  input  logic        i0_lane_sel_id,
  input  logic        i0_reg_write_id,
  input  logic        i1_valid_id,
  input  logic        i1_lane_sel_id,
  input  logic        i1_rs1_use_id,
  input  logic        i1_rs2_use_id,
  input  logic        i1_reg_write_id,

  // decode bundle data
  input  opcode_t     i0_opcode_id,
  input  funct3_t     i0_funct3_id,
  input  funct7_t     i0_funct7_id,
  input  gpr_addr_t   i0_rd_addr_id,
  input  gpr_addr_t   i0_rs1_addr_id,
  input  gpr_addr_t   i0_rs2_addr_id,
  input  word_t       i0_imm_id,
  input  word_t       i0_rs1_data_id,
  input  word_t       i0_rs2_data_id,
  input  word_t       i0_pc_id,
  input  opcode_t     i1_opcode_id,
  input  funct3_t     i1_funct3_id,
  input  funct7_t     i1_funct7_id,
  input  gpr_addr_t   i1_rd_addr_id,
  input  gpr_addr_t   i1_rs1_addr_id,
  input  gpr_addr_t   i1_rs2_addr_id,
  input  word_t       i1_imm_id,
  input  word_t       i1_rs1_data_id,
  input  word_t       i1_rs2_data_id,
  input  word_t       i1_pc_id,

  // output controls
  output logic        stall_id,

  // issue-slot writeback tags (I0 = older, I1 = younger; lane-independent)
  output logic        i0_reg_write_ex,
  output logic        i1_reg_write_ex,
  output word_t       i0_pc_ex,
  output word_t       i1_pc_ex,

  // even lanes — I0 -> ev0, I1 -> ev1 (lane_sel = 0)
  output logic        ev0_enable_ex,
  output opcode_t     ev0_opcode_ex,
  output funct3_t     ev0_funct3_ex,
  output funct7_t     ev0_funct7_ex,
  output gpr_addr_t   ev0_rd_ex,
  output gpr_addr_t   ev0_rs1_addr_ex,
  output gpr_addr_t   ev0_rs2_addr_ex,
  output word_t       ev0_imm_ex,
  output word_t       ev0_rs1_data_ex,
  output word_t       ev0_rs2_data_ex,
  output word_t       ev0_pc_ex,

  output logic        ev1_enable_ex,
  output opcode_t     ev1_opcode_ex,
  output funct3_t     ev1_funct3_ex,
  output funct7_t     ev1_funct7_ex,
  output gpr_addr_t   ev1_rd_ex,
  output gpr_addr_t   ev1_rs1_addr_ex,
  output gpr_addr_t   ev1_rs2_addr_ex,
  output word_t       ev1_imm_ex,
  output word_t       ev1_rs1_data_ex,
  output word_t       ev1_rs2_data_ex,
  output word_t       ev1_pc_ex,

  // odd lanes — I0 -> od0, I1 -> od1 (lane_sel = 1)
  output logic        od0_enable_ex,
  output opcode_t     od0_opcode_ex,
  output funct3_t     od0_funct3_ex,
  output gpr_addr_t   od0_rd_ex,
  output gpr_addr_t   od0_rs1_addr_ex,
  output gpr_addr_t   od0_rs2_addr_ex,
  output word_t       od0_imm_ex,
  output word_t       od0_rs1_data_ex,
  output word_t       od0_rs2_data_ex,
  output word_t       od0_pc_ex,

  output logic        od1_enable_ex,
  output opcode_t     od1_opcode_ex,
  output funct3_t     od1_funct3_ex,
  output gpr_addr_t   od1_rd_ex,
  output gpr_addr_t   od1_rs1_addr_ex,
  output gpr_addr_t   od1_rs2_addr_ex,
  output word_t       od1_imm_ex,
  output word_t       od1_rs1_data_ex,
  output word_t       od1_rs2_data_ex,
  output word_t       od1_pc_ex
);

  // -----------------------------------------------------------------------
  // Reorder Buffer — cache_pkg bank + per-slot tag (rd)
  // -----------------------------------------------------------------------
  logic [ROB_PAYLOAD_W:0] rob_bank [0:ROB_DEPTH-1];
  gpr_addr_t              rob_tag  [0:ROB_DEPTH-1];

  rob_ptr_t rob_write_ptr;
  rob_ptr_t rob_read_ptr;
  rob_ptr_t rob_commit_ptr;
  rob_ptr_t br_inflight;

  // -----------------------------------------------------------------------
  // ROB occupancy — allocate side (write pointer)
  // -----------------------------------------------------------------------
  wire [1:0]   in_valids   = rob_in_valids(i0_valid_id, i1_valid_id);
  wire rob_ptr_t rob_count  = rob_occupancy(rob_write_ptr, rob_commit_ptr);
  wire rob_ptr_t rob_free   = rob_free_slots(rob_count);
  wire         can_alloc    = rob_can_alloc(rob_free, in_valids);
  wire         alloc_ok     = enable && !flush && (in_valids != 2'd0) && can_alloc;

  assign stall_id = rob_stall_fetch(enable, flush, in_valids, can_alloc);

  // -----------------------------------------------------------------------
  // Branch speculation — tag entries allocated behind unresolved branches
  // -----------------------------------------------------------------------
  wire i0_is_br = rob_is_branch(i0_opcode_id);
  wire i1_is_br = rob_is_branch(i1_opcode_id);

  wire spec_i0 = rob_spec_i0(br_inflight);
  wire spec_i1 = rob_spec_i1(br_inflight, i0_valid_id, i0_is_br);

  // -----------------------------------------------------------------------
  // Decode bundles -> rob_entry_t (direct ROB write on allocate)
  // -----------------------------------------------------------------------

  // -----------------------------------------------------------------------
  // ROB dispatch — route oldest pair to ev0/ev1/od0/od1 by lane_sel
  // -----------------------------------------------------------------------
  wire [ROB_AW-1:0] write_idx   = rob_write_ptr[ROB_AW-1:0];
  wire [ROB_AW-1:0] read_idx0   = rob_read_ptr[ROB_AW-1:0];
  wire [ROB_AW-1:0] read_idx1   = rob_read_ptr[ROB_AW-1:0] + 1'b1;
  wire [ROB_AW-1:0] commit_idx0 = rob_commit_ptr[ROB_AW-1:0];
  wire [ROB_AW-1:0] commit_idx1 = rob_commit_ptr[ROB_AW-1:0] + 1'b1;

  wire rob_ptr_t pending = rob_pending_dispatch(rob_write_ptr, rob_read_ptr);

  rob_data_t    data_head0, data_head1;
  rob_data_t    data_commit0, data_commit1;
  EX_packet_t   rob_head0, rob_head1;
  EX_packet_t   i0_out, i1_out;
  EX_packet_t   ev0_pkt, ev1_pkt, od0_pkt, od1_pkt;

  assign data_head0 = rob_cache_data_read(rob_bank[read_idx0], '0);
  assign data_head1 = rob_cache_data_read(rob_bank[read_idx1], '0);
  assign data_commit0 = rob_cache_data_read(rob_bank[commit_idx0], '0);
  assign data_commit1 = rob_cache_data_read(rob_bank[commit_idx1], '0);
  assign rob_head0 = rob_cache_read_ex(rob_bank[read_idx0], rob_tag[read_idx0]);
  assign rob_head1 = rob_cache_read_ex(rob_bank[read_idx1], rob_tag[read_idx1]);

  wire disp0 = rob_disp0_en(pending, data_head0.state);
  wire disp1 = rob_disp1_en(disp0, pending, data_head1.state);

  wire [1:0] dispatch_count = rob_dispatch_count(disp0, disp1);

  assign i0_out = EX_packet_if(disp0 && rob_head0.valid, rob_head0);
  assign i1_out = EX_packet_if(disp1 && rob_head1.valid, rob_head1);

  assign ev0_pkt = ex_packet_route_even(disp0, rob_head0);
  assign od0_pkt = ex_packet_route_odd(disp0, rob_head0);
  assign ev1_pkt = ex_packet_route_even(disp1, rob_head1);
  assign od1_pkt = ex_packet_route_odd(disp1, rob_head1);

  assign i0_reg_write_ex = ex_packet_reg_write(disp0, rob_head0);
  assign i1_reg_write_ex = ex_packet_reg_write(disp1, rob_head1);
  assign i0_pc_ex        = i0_out.packet.pc;
  assign i1_pc_ex        = i1_out.packet.pc;

  assign ev0_enable_ex   = ev0_pkt.valid;
  assign ev0_opcode_ex   = ev0_pkt.packet.opcode;
  assign ev0_funct3_ex   = ev0_pkt.packet.funct3;
  assign ev0_funct7_ex   = ev0_pkt.packet.funct7;
  assign ev0_rd_ex       = ev0_pkt.renamed_tag;
  assign ev0_rs1_addr_ex = ev0_pkt.packet.rs1;
  assign ev0_rs2_addr_ex = ev0_pkt.packet.rs2;
  assign ev0_imm_ex      = ev0_pkt.packet.imm;
  assign ev0_rs1_data_ex = ev0_pkt.packet.rs1_data;
  assign ev0_rs2_data_ex = ev0_pkt.packet.rs2_data;
  assign ev0_pc_ex       = ev0_pkt.packet.pc;

  assign ev1_enable_ex   = ev1_pkt.valid;
  assign ev1_opcode_ex   = ev1_pkt.packet.opcode;
  assign ev1_funct3_ex   = ev1_pkt.packet.funct3;
  assign ev1_funct7_ex   = ev1_pkt.packet.funct7;
  assign ev1_rd_ex       = ev1_pkt.renamed_tag;
  assign ev1_rs1_addr_ex = ev1_pkt.packet.rs1;
  assign ev1_rs2_addr_ex = ev1_pkt.packet.rs2;
  assign ev1_imm_ex      = ev1_pkt.packet.imm;
  assign ev1_rs1_data_ex = ev1_pkt.packet.rs1_data;
  assign ev1_rs2_data_ex = ev1_pkt.packet.rs2_data;
  assign ev1_pc_ex       = ev1_pkt.packet.pc;

  assign od0_enable_ex   = od0_pkt.valid;
  assign od0_opcode_ex   = od0_pkt.packet.opcode;
  assign od0_funct3_ex   = od0_pkt.packet.funct3;
  assign od0_rd_ex       = od0_pkt.renamed_tag;
  assign od0_rs1_addr_ex = od0_pkt.packet.rs1;
  assign od0_rs2_addr_ex = od0_pkt.packet.rs2;
  assign od0_imm_ex      = od0_pkt.packet.imm;
  assign od0_rs1_data_ex = od0_pkt.packet.rs1_data;
  assign od0_rs2_data_ex = od0_pkt.packet.rs2_data;
  assign od0_pc_ex       = od0_pkt.packet.pc;

  assign od1_enable_ex   = od1_pkt.valid;
  assign od1_opcode_ex   = od1_pkt.packet.opcode;
  assign od1_funct3_ex   = od1_pkt.packet.funct3;
  assign od1_rd_ex       = od1_pkt.renamed_tag;
  assign od1_rs1_addr_ex = od1_pkt.packet.rs1;
  assign od1_rs2_addr_ex = od1_pkt.packet.rs2;
  assign od1_imm_ex      = od1_pkt.packet.imm;
  assign od1_rs1_data_ex = od1_pkt.packet.rs1_data;
  assign od1_rs2_data_ex = od1_pkt.packet.rs2_data;
  assign od1_pc_ex       = od1_pkt.packet.pc;

  // -----------------------------------------------------------------------
  // Branch commit bookkeeping
  // -----------------------------------------------------------------------
  wire rob_ptr_t alloc_branches = rob_alloc_branches(
    alloc_ok, i0_valid_id, i0_is_br, i1_valid_id, i1_is_br
  );

  wire cmt0_is_br = rob_is_branch(data_commit0.packet.opcode);
  wire cmt1_is_br = rob_is_branch(data_commit1.packet.opcode);
  wire rob_ptr_t cmt_branches = rob_commit_branches(
    commit_en, commit_count, cmt0_is_br, cmt1_is_br
  );

  // -----------------------------------------------------------------------
  // Sequential ROB update — dispatch, complete, commit, allocate
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    rob_data_t    data_q;
    rob_state_t   next_state;

    if (!rst_n || flush) begin
      rob_write_ptr  <= '0;
      rob_read_ptr   <= '0;
      rob_commit_ptr <= '0;
      br_inflight    <= '0;
    end else if (!enable) begin
      // pipeline frozen — hold all pointers
    end else begin
      if (disp0) begin
        data_q     = rob_cache_data_read(rob_bank[read_idx0], '0);
        next_state = rob_state_after_dispatch(data_q.state);
        rob_bank[read_idx0] <= rob_cache_pack(
          1'b1, rob_data_update_state(data_q, next_state)
        );
      end
      if (disp1) begin
        data_q     = rob_cache_data_read(rob_bank[read_idx1], '0);
        next_state = rob_state_after_dispatch(data_q.state);
        rob_bank[read_idx1] <= rob_cache_pack(
          1'b1, rob_data_update_state(data_q, next_state)
        );
      end
      rob_read_ptr <= rob_read_ptr + {3'b0, dispatch_count};

      if (set_complete_en) begin
        data_q = rob_cache_data_read(rob_bank[set_complete_idx], '0);
        if (rob_complete_valid(data_q.state)) begin
          next_state = rob_state_after_complete(data_q.state);
          rob_bank[set_complete_idx] <= rob_cache_pack(
            1'b1,
            rob_data_update_complete(data_q, next_state, set_complete_result)
          );
        end
      end

      if (commit_en) begin
        if (commit_count >= 2'd1)
          rob_bank[commit_idx0] <= rob_cache_pack(1'b0, '0);
        if (commit_count >= 2'd2)
          rob_bank[commit_idx1] <= rob_cache_pack(1'b0, '0);
        rob_commit_ptr <= rob_commit_ptr + {3'b0, commit_count};
      end

      if (alloc_ok) begin
        if (i0_valid_id) begin
          rob_bank[write_idx] <= rob_entry_to_cache(bundle_i0(
            i0_valid_id, i0_lane_sel_id, i0_reg_write_id,
            i0_opcode_id, i0_funct3_id, i0_funct7_id,
            i0_rd_addr_id, i0_rs1_addr_id, i0_rs2_addr_id,
            i0_imm_id, i0_rs1_data_id, i0_rs2_data_id, i0_pc_id,
            rob_state_on_alloc(spec_i0), '0
          ));
          rob_tag[write_idx] <= i0_rd_addr_id;
        end
        if (i1_valid_id) begin
          rob_bank[write_idx + ROB_AW'(i0_valid_id)] <= rob_entry_to_cache(bundle_i1(
            i1_valid_id, i1_lane_sel_id, i1_reg_write_id,
            i1_rs1_use_id, i1_rs2_use_id,
            i1_opcode_id, i1_funct3_id, i1_funct7_id,
            i1_rd_addr_id, i1_rs1_addr_id, i1_rs2_addr_id,
            i1_imm_id, i1_rs1_data_id, i1_rs2_data_id, i1_pc_id,
            rob_state_on_alloc(spec_i1), '0
          ));
          rob_tag[write_idx + ROB_AW'(i0_valid_id)] <= i1_rd_addr_id;
        end
        rob_write_ptr <= rob_write_ptr + {3'b0, in_valids};
      end

      br_inflight <= br_inflight + alloc_branches - cmt_branches;
    end
  end

endmodule
