`timescale 1ns / 1ps

// Reorder Buffer — queue operations (allocate, dispatch, complete, search, flow).
// Types and constants: rob_pkg (rob.sv).
package rob_queue_pkg;

  import rv_dis_pkg::*;
  import rob_pkg::*;

// -------------------------------------------------------------------------
// Entry constructors — allocate at write pointer
// -------------------------------------------------------------------------
function automatic ID_packet_t ID_packet_pack(
  input logic      lane_sel,
  input logic      reg_write,
  input logic      rs1_use,
  input logic      rs2_use,
  input opcode_t   opcode,
  input funct3_t   funct3,
  input funct7_t   funct7,
  input gpr_addr_t rs1,
  input gpr_addr_t rs2,
  input word_t     imm,
  input word_t     rs1_data,
  input word_t     rs2_data,
  input word_t     pc
);
  ID_packet_pack.lane_sel  = lane_sel;
  ID_packet_pack.reg_write = reg_write;
  ID_packet_pack.rs1_use   = rs1_use;
  ID_packet_pack.rs2_use   = rs2_use;
  ID_packet_pack.opcode    = opcode;
  ID_packet_pack.funct3    = funct3;
  ID_packet_pack.funct7    = funct7;
  ID_packet_pack.rs1       = rs1;
  ID_packet_pack.rs2       = rs2;
  ID_packet_pack.imm       = imm;
  ID_packet_pack.rs1_data  = rs1_data;
  ID_packet_pack.rs2_data  = rs2_data;
  ID_packet_pack.pc        = pc;
endfunction

function automatic rob_data_t rob_data_make(
  input ID_packet_t packet,
  input rob_state_t state,
  input word_t      result
);
  rob_data_make.packet = packet;
  rob_data_make.state  = state;
  rob_data_make.result = result;
endfunction

function automatic rob_entry_t rob_entry_make(
  input logic       valid,
  input gpr_addr_t  tag,
  input ID_packet_t packet,
  input rob_state_t state,
  input word_t      result
);
  rob_entry_make.valid = valid;
  rob_entry_make.tag   = tag;
  rob_entry_make.data  = rob_data_make(packet, state, result);
endfunction

function automatic rob_entry_t bundle_i0(
  input logic      valid,
  input logic      lane_sel,
  input logic      reg_write,
  input opcode_t   opcode,
  input funct3_t   funct3,
  input funct7_t   funct7,
  input gpr_addr_t rd,
  input gpr_addr_t rs1,
  input gpr_addr_t rs2,
  input word_t     imm,
  input word_t     rs1_data,
  input word_t     rs2_data,
  input word_t     pc,
  input rob_state_t state,
  input word_t      result
);
  return rob_entry_make(
    valid,
    rd,
    ID_packet_pack(
      lane_sel, reg_write, 1'b1, 1'b1,
      opcode, funct3, funct7, rs1, rs2,
      imm, rs1_data, rs2_data, pc
    ),
    state,
    result
  );
endfunction

function automatic rob_entry_t bundle_i1(
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
  input word_t     imm,
  input word_t     rs1_data,
  input word_t     rs2_data,
  input word_t     pc,
  input rob_state_t state,
  input word_t      result
);
  return rob_entry_make(
    valid,
    rd,
    ID_packet_pack(
      lane_sel, reg_write, rs1_use, rs2_use,
      opcode, funct3, funct7, rs1, rs2,
      imm, rs1_data, rs2_data, pc
    ),
    state,
    result
  );
endfunction

// -------------------------------------------------------------------------
// Cache bank — read at read/commit pointer, write at allocate/complete
// -------------------------------------------------------------------------
function automatic logic [ROB_DATA_W:0] rob_cache_pack(
  input logic      valid,
  input rob_data_t data
);
  return {valid, data};
endfunction

function automatic logic rob_cache_valid(input logic [ROB_DATA_W:0] entry);
  return entry[ROB_DATA_W];
endfunction

function automatic rob_data_t rob_cache_data(
  input logic [ROB_DATA_W:0] entry
);
  return entry[ROB_DATA_W-1:0];
endfunction

function automatic rob_data_t rob_cache_data_read(
  input logic [ROB_DATA_W:0] entry,
  input rob_data_t           default_data
);
  if (!entry[ROB_DATA_W])
    return default_data;
  return entry[ROB_DATA_W-1:0];
endfunction

function automatic logic [ROB_DATA_W:0] rob_entry_to_cache(input rob_entry_t entry);
  return rob_cache_pack(entry.valid, entry.data);
endfunction

function automatic rob_entry_t rob_cache_read_entry(
  input logic [ROB_DATA_W:0] entry,
  input gpr_addr_t           tag
);
  rob_data_t data;
  data = rob_cache_data_read(entry, '0);
  return rob_entry_make(rob_cache_valid(entry), tag, data.packet, data.state, data.result);
endfunction

// -------------------------------------------------------------------------
// 16-way parallel tag search — all ways compared in one combinational pass
// -------------------------------------------------------------------------
function automatic logic [ROB_WAYS-1:0] rob_window_mask(
  input rob_ptr_t commit_ptr,
  input rob_ptr_t write_ptr
);
  rob_ptr_t occ;
  rob_ptr_t slot_ptr;
  logic [ROB_AW-1:0] slot_idx;
  occ = write_ptr - commit_ptr;
  for (int w = 0; w < ROB_WAYS; w++)
    rob_window_mask[w] = 1'b0;
  for (int k = 0; k < ROB_WAYS; k++) begin
    if (k < occ) begin
      slot_ptr = commit_ptr + rob_ptr_t'(k);
      slot_idx = slot_ptr[ROB_AW-1:0];
      rob_window_mask[slot_idx] = 1'b1;
    end
  end
endfunction

function automatic logic [ROB_WAYS-1:0] rob_tag_match_vec(
  input gpr_addr_t           tags [ROB_WAYS],
  input logic [ROB_DATA_W:0] bank [ROB_WAYS],
  input gpr_addr_t           query
);
  for (int w = 0; w < ROB_WAYS; w++)
    rob_tag_match_vec[w] = rob_cache_valid(bank[w]) && (tags[w] == query);
endfunction

function automatic logic [ROB_WAYS-1:0] rob_search_vec(
  input gpr_addr_t           tags [ROB_WAYS],
  input logic [ROB_DATA_W:0] bank [ROB_WAYS],
  input gpr_addr_t           query,
  input rob_ptr_t            commit_ptr,
  input rob_ptr_t            write_ptr
);
  return rob_window_mask(commit_ptr, write_ptr) & rob_tag_match_vec(tags, bank, query);
endfunction

function automatic logic rob_search_hit(input logic [ROB_WAYS-1:0] match_vec);
  return |match_vec;
endfunction

function automatic rob_ptr_t rob_slot_ring_dist(
  input logic [ROB_AW-1:0] idx,
  input rob_ptr_t          commit_ptr,
  input rob_ptr_t          write_ptr
);
  rob_ptr_t occ;
  rob_ptr_t slot_ptr;
  logic [ROB_AW-1:0] slot_idx;
  occ = write_ptr - commit_ptr;
  for (int k = 0; k < ROB_WAYS; k++) begin
    if (k < occ) begin
      slot_ptr = commit_ptr + rob_ptr_t'(k);
      slot_idx = slot_ptr[ROB_AW-1:0];
      if (slot_idx == idx)
        return rob_ptr_t'(k);
    end
  end
  return rob_ptr_t'(-1);
endfunction

// Youngest in-window match = largest ring distance from commit (most recently allocated).
function automatic logic [ROB_AW-1:0] rob_pick_youngest_way(
  input logic [ROB_WAYS-1:0] match_vec,
  input rob_ptr_t            commit_ptr,
  input rob_ptr_t            write_ptr
);
  rob_ptr_t best_ring;
  rob_ptr_t ring_pos;
  logic [ROB_AW-1:0] best_way;
  best_ring = rob_ptr_t'(-1);
  best_way  = '0;
  for (int w = 0; w < ROB_WAYS; w++) begin
    if (!match_vec[w])
      continue;
    ring_pos = rob_slot_ring_dist(ROB_AW'(w), commit_ptr, write_ptr);
    if (ring_pos >= best_ring) begin
      best_ring = ring_pos;
      best_way  = ROB_AW'(w);
    end
  end
  return best_way;
endfunction

function automatic logic [ROB_AW-1:0] rob_search_youngest_way(
  input gpr_addr_t           tags [ROB_WAYS],
  input logic [ROB_DATA_W:0] bank [ROB_WAYS],
  input gpr_addr_t           query,
  input rob_ptr_t            commit_ptr,
  input rob_ptr_t            write_ptr
);
  logic [ROB_WAYS-1:0] match_vec;
  match_vec = rob_search_vec(tags, bank, query, commit_ptr, write_ptr);
  if (!rob_search_hit(match_vec))
    return '0;
  return rob_pick_youngest_way(match_vec, commit_ptr, write_ptr);
endfunction

function automatic rob_entry_t rob_search_tag_entry(
  input gpr_addr_t           tags [ROB_WAYS],
  input logic [ROB_DATA_W:0] bank [ROB_WAYS],
  input gpr_addr_t           query,
  input rob_ptr_t            commit_ptr,
  input rob_ptr_t            write_ptr
);
  logic [ROB_WAYS-1:0] match_vec;
  logic [ROB_AW-1:0]    way;
  match_vec = rob_search_vec(tags, bank, query, commit_ptr, write_ptr);
  if (!rob_search_hit(match_vec))
    return '0;
  way = rob_pick_youngest_way(match_vec, commit_ptr, write_ptr);
  return rob_cache_read_entry(bank[way], tags[way]);
endfunction

function automatic word_t rob_forward_operand(
  input gpr_addr_t           tags [ROB_WAYS],
  input logic [ROB_DATA_W:0] bank [ROB_WAYS],
  input gpr_addr_t           arch_reg,
  input word_t               decode_data,
  input rob_ptr_t            commit_ptr,
  input rob_ptr_t            write_ptr
);
  logic [ROB_WAYS-1:0] match_vec;
  logic [ROB_AW-1:0]    way;
  rob_data_t             data;
  match_vec = rob_search_vec(tags, bank, arch_reg, commit_ptr, write_ptr);
  if (!rob_search_hit(match_vec))
    return decode_data;
  way  = rob_pick_youngest_way(match_vec, commit_ptr, write_ptr);
  data = rob_cache_data_read(bank[way], '0);
  if ((data.state == ROB_EXECUTED) || (data.state == ROB_SPEC_EXEC))
    return data.result;
  return decode_data;
endfunction

// -------------------------------------------------------------------------
// Lifecycle — new -> read -> executed -> commit (freed)
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

function automatic rob_data_t rob_data_update_state(
  input rob_data_t  data,
  input rob_state_t state
);
  rob_data_update_state = data;
  rob_data_update_state.state = state;
endfunction

function automatic rob_data_t rob_data_update_complete(
  input rob_data_t  data,
  input rob_state_t state,
  input word_t      result
);
  rob_data_update_complete = data;
  rob_data_update_complete.result = result;
  rob_data_update_complete.state  = state;
endfunction

// -------------------------------------------------------------------------
// Flow control — write/read/commit pointers and dispatch from read pointer
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
  return rob_ptr_t'(ROB_CAP) - occupancy;
endfunction

function automatic logic rob_can_alloc(
  input rob_ptr_t   free_slots,
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

endpackage
