`timescale 1ns / 1ps

// ID/EX dispatch helpers — Reorder Buffer types, lifecycle codes, and pure functions.
// Consumed by id_ex_dispatch.sv (the ROB module).
package dispatch_pkg;

  import rv_dis_pkg::*;

  // -------------------------------------------------------------------------
  // Reorder Buffer geometry (mirrors rv_dis_pkg ROB_DEPTH / ROB_AW)
  // -------------------------------------------------------------------------
  localparam int ROB_CAP = ROB_DEPTH;

  // -------------------------------------------------------------------------
  // 3-bit ROB lifecycle codes (project_outline)
  // -------------------------------------------------------------------------
  typedef logic [2:0] rob_state_t;

  localparam rob_state_t ROB_NEW       = 3'b000;
  localparam rob_state_t ROB_READ      = 3'b001;
  localparam rob_state_t ROB_EXECUTED  = 3'b010;
  localparam rob_state_t ROB_SPEC_NEW  = 3'b100;
  localparam rob_state_t ROB_SPEC_READ = 3'b101;
  localparam rob_state_t ROB_SPEC_EXEC = 3'b110;

  typedef logic [ROB_AW:0] rob_ptr_t;

  // -------------------------------------------------------------------------
  // Data structures
  // -------------------------------------------------------------------------

  // Decode bundle presented at the ID/EX boundary (one dual-issue slot).
  typedef struct packed {
    logic      valid;
    logic      lane_sel;
    logic      reg_write;
    logic      rs1_use;
    logic      rs2_use;
    opcode_t   opcode;
    funct3_t   funct3;
    funct7_t   funct7;
    gpr_addr_t rd;
    gpr_addr_t rs1;
    gpr_addr_t rs2;
    imm_t      imm;
    reg_t      rs1_data;
    reg_t      rs2_data;
    pc_t       pc;
  } id_slot_bundle_t;

  // Full ROB slot: decoded entry + lifecycle state + execution result.
  typedef struct packed {
    rob_entry_t  entry;
    rob_state_t  state;
    reg_t        result;
  } rob_slot_t;

  // -------------------------------------------------------------------------
  // Pack decode bundle -> ROB entry
  // -------------------------------------------------------------------------
  function automatic rob_entry_t pack_rob_entry(input id_slot_bundle_t slot);
    pack_rob_entry           = '0;
    pack_rob_entry.valid     = slot.valid;
    pack_rob_entry.lane_sel  = slot.lane_sel;
    pack_rob_entry.opcode    = slot.opcode;
    pack_rob_entry.funct3    = slot.funct3;
    pack_rob_entry.funct7    = slot.funct7;
    pack_rob_entry.rd        = slot.rd;
    pack_rob_entry.rs1       = slot.rs1;
    pack_rob_entry.rs2       = slot.rs2;
    pack_rob_entry.rs1_use   = slot.rs1_use;
    pack_rob_entry.rs2_use   = slot.rs2_use;
    pack_rob_entry.reg_write = slot.reg_write;
    pack_rob_entry.imm       = slot.imm;
    pack_rob_entry.rs1_data  = slot.rs1_data;
    pack_rob_entry.rs2_data  = slot.rs2_data;
    pack_rob_entry.pc        = slot.pc;
  endfunction

  // I0 always reads both GPR operands at dispatch.
  function automatic id_slot_bundle_t bundle_i0(
    input logic      valid,
    input logic      lane_sel,
    input logic      reg_write,
    input opcode_t   opcode,
    input funct3_t   funct3,
    input funct7_t   funct7,
    input gpr_addr_t rd,
    input gpr_addr_t rs1,
    input gpr_addr_t rs2,
    input imm_t      imm,
    input reg_t      rs1_data,
    input reg_t      rs2_data,
    input pc_t       pc
  );
    bundle_i0.valid     = valid;
    bundle_i0.lane_sel  = lane_sel;
    bundle_i0.reg_write = reg_write;
    bundle_i0.rs1_use   = 1'b1;
    bundle_i0.rs2_use   = 1'b1;
    bundle_i0.opcode    = opcode;
    bundle_i0.funct3    = funct3;
    bundle_i0.funct7    = funct7;
    bundle_i0.rd        = rd;
    bundle_i0.rs1       = rs1;
    bundle_i0.rs2       = rs2;
    bundle_i0.imm       = imm;
    bundle_i0.rs1_data  = rs1_data;
    bundle_i0.rs2_data  = rs2_data;
    bundle_i0.pc        = pc;
  endfunction

  function automatic id_slot_bundle_t bundle_i1(
    input logic      valid,
    input logic      lane_sel,
    input logic      reg_write,
    input logic      rs1_use,
    input logic      rs2_use,
    input opcode_t   opcode,
    input funct3_t   funct3,
    input funct7_t   funct7,
    input gpr_addr_t rd,
    input gpr_addr_t rs1,
    input gpr_addr_t rs2,
    input imm_t      imm,
    input reg_t      rs1_data,
    input reg_t      rs2_data,
    input pc_t       pc
  );
    bundle_i1.valid     = valid;
    bundle_i1.lane_sel  = lane_sel;
    bundle_i1.reg_write = reg_write;
    bundle_i1.rs1_use   = rs1_use;
    bundle_i1.rs2_use   = rs2_use;
    bundle_i1.opcode    = opcode;
    bundle_i1.funct3    = funct3;
    bundle_i1.funct7    = funct7;
    bundle_i1.rd        = rd;
    bundle_i1.rs1       = rs1;
    bundle_i1.rs2       = rs2;
    bundle_i1.imm       = imm;
    bundle_i1.rs1_data  = rs1_data;
    bundle_i1.rs2_data  = rs2_data;
    bundle_i1.pc        = pc;
  endfunction

  // -------------------------------------------------------------------------
  // ROB lifecycle helpers
  // -------------------------------------------------------------------------
  function automatic logic rob_undispatched(input rob_state_t state);
    return (state == ROB_NEW) || (state == ROB_SPEC_NEW);
  endfunction

  function automatic rob_state_t rob_state_after_dispatch(input rob_state_t state);
    if (state == ROB_SPEC_NEW)
      return ROB_SPEC_READ;
    return ROB_READ;
  endfunction

  function automatic rob_state_t rob_state_on_alloc(input logic speculative);
    return speculative ? ROB_SPEC_NEW : ROB_NEW;
  endfunction

  function automatic rob_state_t rob_state_after_complete(input rob_state_t state);
    if (state == ROB_READ)
      return ROB_EXECUTED;
    if (state == ROB_SPEC_READ)
      return ROB_SPEC_EXEC;
    return state;
  endfunction

  function automatic logic rob_complete_valid(input rob_state_t state);
    return (state == ROB_READ) || (state == ROB_SPEC_READ);
  endfunction

  // -------------------------------------------------------------------------
  // ROB occupancy / flow control
  // -------------------------------------------------------------------------
  function automatic logic [1:0] rob_in_valids(
    input logic i0_valid,
    input logic i1_valid
  );
    return {1'b0, i0_valid} + {1'b0, i1_valid};
  endfunction

  function automatic rob_ptr_t rob_occupancy(
    input rob_ptr_t write_ptr,
    input rob_ptr_t commit_ptr
  );
    return write_ptr - commit_ptr;
  endfunction

  function automatic rob_ptr_t rob_free_slots(input rob_ptr_t occupancy);
    return ROB_CAP - occupancy;
  endfunction

  function automatic logic rob_can_alloc(
    input rob_ptr_t free_slots,
    input logic [1:0] in_valids
  );
    return (free_slots >= {3'b0, in_valids});
  endfunction

  function automatic logic rob_stall_fetch(
    input logic       enable,
    input logic       flush,
    input logic [1:0] in_valids,
    input logic       can_alloc
  );
    return enable && !flush && (in_valids != 2'd0) && !can_alloc;
  endfunction

  function automatic rob_ptr_t rob_pending_dispatch(
    input rob_ptr_t write_ptr,
    input rob_ptr_t read_ptr
  );
    return write_ptr - read_ptr;
  endfunction

  function automatic logic rob_disp0_en(
    input rob_ptr_t   pending,
    input rob_state_t state0
  );
    return (pending >= 5'd1) && rob_undispatched(state0);
  endfunction

  function automatic logic rob_disp1_en(
    input logic       disp0,
    input rob_ptr_t   pending,
    input rob_state_t state1
  );
    return disp0 && (pending >= 5'd2) && rob_undispatched(state1);
  endfunction

  function automatic logic [1:0] rob_dispatch_count(
    input logic disp0,
    input logic disp1
  );
    return {1'b0, disp0} + {1'b0, disp1};
  endfunction

  // -------------------------------------------------------------------------
  // Branch speculation bookkeeping
  // -------------------------------------------------------------------------
  function automatic logic rob_is_branch(input opcode_t opcode);
    return (opcode == OPC_BRANCH);
  endfunction

  function automatic logic rob_spec_i0(input rob_ptr_t br_inflight);
    return (br_inflight != 0);
  endfunction

  function automatic logic rob_spec_i1(
    input rob_ptr_t br_inflight,
    input logic     i0_valid,
    input logic     i0_is_br
  );
    return (br_inflight != 0) || (i0_valid && i0_is_br);
  endfunction

  function automatic rob_ptr_t rob_alloc_branches(
    input logic alloc_ok,
    input logic i0_valid,
    input logic i0_is_br,
    input logic i1_valid,
    input logic i1_is_br
  );
    if (!alloc_ok)
      return '0;
    return {{ROB_AW{1'b0}}, (i0_valid && i0_is_br)} +
           {{ROB_AW{1'b0}}, (i1_valid && i1_is_br)};
  endfunction

  function automatic rob_ptr_t rob_commit_branches(
    input logic      commit_en,
    input logic [1:0] commit_count,
    input logic      cmt0_is_br,
    input logic      cmt1_is_br
  );
    logic cmt0_br;
    logic cmt1_br;
    cmt0_br = commit_en && (commit_count >= 2'd1) && cmt0_is_br;
    cmt1_br = commit_en && (commit_count >= 2'd2) && cmt1_is_br;
    return {{ROB_AW{1'b0}}, cmt0_br} + {{ROB_AW{1'b0}}, cmt1_br};
  endfunction

endpackage
