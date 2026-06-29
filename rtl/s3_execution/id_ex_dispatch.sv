`timescale 1ns / 1ps

// ID/EX dispatch stage — the Reorder Buffer (ROB), per project_outline.
// Types, lifecycle codes, and helper functions: funct_pkg/dispatch.sv (dispatch_pkg).
//
//   * Three pointers (no entry shifting):
//       - write  (tail) : allocate up to two decoded slots per cycle (I0 then I1)
//       - read   (body) : route the oldest undispatched pair to even/odd lanes
//       - commit (head) : retire completed entries (commit_en / commit_count)
//     Occupancy = write - commit; a full ROB back-pressures fetch (stall_id).
//   * Per-entry fields: rob_entry_t + rob_state_t + result (see rob_slot_t).
//   * Lifecycle: new (000) -> read (001) -> executed (010) -> commit (freed).
//   * set_complete captures EX result and advances read -> executed.
//   * flush squashes speculative entries and resets all pointers.
//
// Operand hazards are resolved downstream (forward_unit), not in the ROB.
module id_ex_dispatch
  import rv_dis_pkg::*;
  import dispatch_pkg::*;
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
  input  reg_t            set_complete_result,

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
  input  imm_t        i0_imm_id,
  input  reg_t        i0_rs1_data_id,
  input  reg_t        i0_rs2_data_id,
  input  pc_t         i0_pc_id,
  input  opcode_t     i1_opcode_id,
  input  funct3_t     i1_funct3_id,
  input  funct7_t     i1_funct7_id,
  input  gpr_addr_t   i1_rd_addr_id,
  input  gpr_addr_t   i1_rs1_addr_id,
  input  gpr_addr_t   i1_rs2_addr_id,
  input  imm_t        i1_imm_id,
  input  reg_t        i1_rs1_data_id,
  input  reg_t        i1_rs2_data_id,
  input  pc_t         i1_pc_id,

  // output controls
  output logic        stall_id,
  output logic        i0_reg_write_ex,
  output logic        i1_reg_write_ex,
  output logic        ev0_enable_ex,
  output logic        ev1_enable_ex,
  output logic        od0_enable_ex,
  output logic        od1_enable_ex,

  // output data
  output pc_t         i0_pc_ex,
  output pc_t         i1_pc_ex,
  output opcode_t     ev0_opcode_ex,
  output funct3_t     ev0_funct3_ex,
  output funct7_t     ev0_funct7_ex,
  output gpr_addr_t   ev0_rd_ex,
  output gpr_addr_t   ev0_rs1_addr_ex,
  output gpr_addr_t   ev0_rs2_addr_ex,
  output imm_t        ev0_imm_ex,
  output reg_t        ev0_rs1_data_ex,
  output reg_t        ev0_rs2_data_ex,
  output pc_t         ev0_pc_ex,
  output opcode_t     ev1_opcode_ex,
  output funct3_t     ev1_funct3_ex,
  output funct7_t     ev1_funct7_ex,
  output gpr_addr_t   ev1_rd_ex,
  output gpr_addr_t   ev1_rs1_addr_ex,
  output gpr_addr_t   ev1_rs2_addr_ex,
  output imm_t        ev1_imm_ex,
  output reg_t        ev1_rs1_data_ex,
  output reg_t        ev1_rs2_data_ex,
  output pc_t         ev1_pc_ex,
  output opcode_t     od0_opcode_ex,
  output funct3_t     od0_funct3_ex,
  output gpr_addr_t   od0_rd_ex,
  output gpr_addr_t   od0_rs1_addr_ex,
  output gpr_addr_t   od0_rs2_addr_ex,
  output imm_t        od0_imm_ex,
  output reg_t        od0_rs1_data_ex,
  output reg_t        od0_rs2_data_ex,
  output pc_t         od0_pc_ex,
  output opcode_t     od1_opcode_ex,
  output funct3_t     od1_funct3_ex,
  output gpr_addr_t   od1_rd_ex,
  output gpr_addr_t   od1_rs1_addr_ex,
  output gpr_addr_t   od1_rs2_addr_ex,
  output imm_t        od1_imm_ex,
  output reg_t        od1_rs1_data_ex,
  output reg_t        od1_rs2_data_ex,
  output pc_t         od1_pc_ex
);

  // -----------------------------------------------------------------------
  // Reorder Buffer storage
  // -----------------------------------------------------------------------
  rob_entry_t   rob_buf   [0:ROB_DEPTH-1];
  rob_state_t   rob_state [0:ROB_DEPTH-1];
  reg_t         rob_result[0:ROB_DEPTH-1];

  rob_ptr_t rob_write_ptr;
  rob_ptr_t rob_read_ptr;
  rob_ptr_t rob_commit_ptr;
  rob_ptr_t br_inflight;

  // -----------------------------------------------------------------------
  // Decode bundles -> id_slot_bundle_t (dispatch_pkg)
  // -----------------------------------------------------------------------
  id_slot_bundle_t i0_bundle;
  id_slot_bundle_t i1_bundle;

  always_comb begin
    i0_bundle = bundle_i0(
      i0_valid_id, i0_lane_sel_id, i0_reg_write_id,
      i0_opcode_id, i0_funct3_id, i0_funct7_id,
      i0_rd_addr_id, i0_rs1_addr_id, i0_rs2_addr_id,
      i0_imm_id, i0_rs1_data_id, i0_rs2_data_id, i0_pc_id
    );
    i1_bundle = bundle_i1(
      i1_valid_id, i1_lane_sel_id, i1_reg_write_id,
      i1_rs1_use_id, i1_rs2_use_id,
      i1_opcode_id, i1_funct3_id, i1_funct7_id,
      i1_rd_addr_id, i1_rs1_addr_id, i1_rs2_addr_id,
      i1_imm_id, i1_rs1_data_id, i1_rs2_data_id, i1_pc_id
    );
  end

  // -----------------------------------------------------------------------
  // ROB occupancy — allocate side (write pointer)
  // -----------------------------------------------------------------------
  wire [1:0]  in_valids    = rob_in_valids(i0_valid_id, i1_valid_id);
  wire rob_ptr_t rob_count  = rob_occupancy(rob_write_ptr, rob_commit_ptr);
  wire rob_ptr_t rob_free   = rob_free_slots(rob_count);
  wire        can_alloc    = rob_can_alloc(rob_free, in_valids);
  wire        alloc_ok     = enable && !flush && (in_valids != 2'd0) && can_alloc;

  assign stall_id = rob_stall_fetch(enable, flush, in_valids, can_alloc);

  // -----------------------------------------------------------------------
  // ROB dispatch — read pointer presents oldest undispatched pair to lanes
  // -----------------------------------------------------------------------
  wire [ROB_AW-1:0] write_idx   = rob_write_ptr[ROB_AW-1:0];
  wire [ROB_AW-1:0] read_idx0   = rob_read_ptr[ROB_AW-1:0];
  wire [ROB_AW-1:0] read_idx1   = rob_read_ptr[ROB_AW-1:0] + 1'b1;
  wire [ROB_AW-1:0] commit_idx0 = rob_commit_ptr[ROB_AW-1:0];
  wire [ROB_AW-1:0] commit_idx1 = rob_commit_ptr[ROB_AW-1:0] + 1'b1;

  wire rob_ptr_t pending = rob_pending_dispatch(rob_write_ptr, rob_read_ptr);

  rob_entry_t rob_head0, rob_head1;
  assign rob_head0 = rob_buf[read_idx0];
  assign rob_head1 = rob_buf[read_idx1];

  wire disp0 = rob_disp0_en(pending, rob_state[read_idx0]);
  wire disp1 = rob_disp1_en(disp0, pending, rob_state[read_idx1]);

  wire [1:0] dispatch_count = rob_dispatch_count(disp0, disp1);

  wire head0_even = (rob_head0.lane_sel == 1'b0);
  wire head1_even = (rob_head1.lane_sel == 1'b0);

  assign ev0_enable_ex = disp0 && rob_head0.valid &&  head0_even;
  assign od0_enable_ex = disp0 && rob_head0.valid && !head0_even;
  assign ev1_enable_ex = disp1 && rob_head1.valid &&  head1_even;
  assign od1_enable_ex = disp1 && rob_head1.valid && !head1_even;

  assign i0_reg_write_ex = disp0 && rob_head0.valid && rob_head0.reg_write;
  assign i1_reg_write_ex = disp1 && rob_head1.valid && rob_head1.reg_write;
  assign i0_pc_ex = disp0 ? rob_head0.pc : '0;
  assign i1_pc_ex = disp1 ? rob_head1.pc : '0;

  assign ev0_opcode_ex   = rob_head0.opcode;
  assign ev0_funct3_ex   = rob_head0.funct3;
  assign ev0_funct7_ex   = rob_head0.funct7;
  assign ev0_rd_ex       = rob_head0.rd;
  assign ev0_rs1_addr_ex = rob_head0.rs1;
  assign ev0_rs2_addr_ex = rob_head0.rs2;
  assign ev0_imm_ex      = rob_head0.imm;
  assign ev0_rs1_data_ex = rob_head0.rs1_data;
  assign ev0_rs2_data_ex = rob_head0.rs2_data;
  assign ev0_pc_ex       = rob_head0.pc;

  assign od0_opcode_ex   = rob_head0.opcode;
  assign od0_funct3_ex   = rob_head0.funct3;
  assign od0_rd_ex       = rob_head0.rd;
  assign od0_rs1_addr_ex = rob_head0.rs1;
  assign od0_rs2_addr_ex = rob_head0.rs2;
  assign od0_imm_ex      = rob_head0.imm;
  assign od0_rs1_data_ex = rob_head0.rs1_data;
  assign od0_rs2_data_ex = rob_head0.rs2_data;
  assign od0_pc_ex       = rob_head0.pc;

  assign ev1_opcode_ex   = rob_head1.opcode;
  assign ev1_funct3_ex   = rob_head1.funct3;
  assign ev1_funct7_ex   = rob_head1.funct7;
  assign ev1_rd_ex       = rob_head1.rd;
  assign ev1_rs1_addr_ex = rob_head1.rs1;
  assign ev1_rs2_addr_ex = rob_head1.rs2;
  assign ev1_imm_ex      = rob_head1.imm;
  assign ev1_rs1_data_ex = rob_head1.rs1_data;
  assign ev1_rs2_data_ex = rob_head1.rs2_data;
  assign ev1_pc_ex       = rob_head1.pc;

  assign od1_opcode_ex   = rob_head1.opcode;
  assign od1_funct3_ex   = rob_head1.funct3;
  assign od1_rd_ex       = rob_head1.rd;
  assign od1_rs1_addr_ex = rob_head1.rs1;
  assign od1_rs2_addr_ex = rob_head1.rs2;
  assign od1_imm_ex      = rob_head1.imm;
  assign od1_rs1_data_ex = rob_head1.rs1_data;
  assign od1_rs2_data_ex = rob_head1.rs2_data;
  assign od1_pc_ex       = rob_head1.pc;

  // -----------------------------------------------------------------------
  // Branch speculation — tag entries allocated behind unresolved branches
  // -----------------------------------------------------------------------
  wire i0_is_br = rob_is_branch(i0_opcode_id);
  wire i1_is_br = rob_is_branch(i1_opcode_id);

  wire spec_i0 = rob_spec_i0(br_inflight);
  wire spec_i1 = rob_spec_i1(br_inflight, i0_valid_id, i0_is_br);

  wire rob_ptr_t alloc_branches = rob_alloc_branches(
    alloc_ok, i0_valid_id, i0_is_br, i1_valid_id, i1_is_br
  );

  wire cmt0_is_br = rob_is_branch(rob_buf[commit_idx0].opcode);
  wire cmt1_is_br = rob_is_branch(rob_buf[commit_idx1].opcode);
  wire rob_ptr_t cmt_branches = rob_commit_branches(
    commit_en, commit_count, cmt0_is_br, cmt1_is_br
  );

  // -----------------------------------------------------------------------
  // Sequential ROB update — dispatch, complete, commit, allocate
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      rob_write_ptr  <= '0;
      rob_read_ptr   <= '0;
      rob_commit_ptr <= '0;
      br_inflight    <= '0;
    end else if (!enable) begin
      // pipeline frozen — hold all pointers
    end else begin
      if (disp0)
        rob_state[read_idx0] <= rob_state_after_dispatch(rob_state[read_idx0]);
      if (disp1)
        rob_state[read_idx1] <= rob_state_after_dispatch(rob_state[read_idx1]);
      rob_read_ptr <= rob_read_ptr + {3'b0, dispatch_count};

      if (set_complete_en) begin
        rob_result[set_complete_idx] <= set_complete_result;
        if (rob_complete_valid(rob_state[set_complete_idx]))
          rob_state[set_complete_idx] <=
            rob_state_after_complete(rob_state[set_complete_idx]);
      end

      if (commit_en)
        rob_commit_ptr <= rob_commit_ptr + {3'b0, commit_count};

      if (alloc_ok) begin
        if (i0_valid_id) begin
          rob_buf[write_idx]   <= pack_rob_entry(i0_bundle);
          rob_state[write_idx] <= rob_state_on_alloc(spec_i0);
        end
        if (i1_valid_id) begin
          rob_buf[write_idx + i0_valid_id]   <= pack_rob_entry(i1_bundle);
          rob_state[write_idx + i0_valid_id] <= rob_state_on_alloc(spec_i1);
        end
        rob_write_ptr <= rob_write_ptr + {3'b0, in_valids};
      end

      br_inflight <= br_inflight + alloc_branches - cmt_branches;
    end
  end

endmodule
