`timescale 1ns / 1ps

// Register rename + EX/RS packet view — ROB read -> reservation station routing.
package rob_rename_pkg;

  import rv_dis_pkg::*;
  import rob_pkg::*;
  import rob_queue_pkg::*;

// -------------------------------------------------------------------------
// Renamed dispatch / RS types
// -------------------------------------------------------------------------
typedef struct packed {
  logic       valid;
  gpr_addr_t  renamed_tag;
  ID_packet_t packet;
} EX_packet_t;

localparam int RS_DEPTH = 4;
localparam int RS_AW    = 2;

typedef logic [RS_AW:0] rs_cnt_t;

typedef struct packed {
  logic       valid;
  gpr_addr_t  renamed_tag;
  ID_packet_t packet;
} rs_entry_t;

// Destination rename — identity map until a physical rename table is added.
function automatic gpr_addr_t rename_dest_tag(input gpr_addr_t arch_rd);
  return arch_rd;
endfunction

// -------------------------------------------------------------------------
// ROB read -> renamed EX packet (dispatch to RS / execute)
// -------------------------------------------------------------------------
function automatic EX_packet_t EX_packet_from_entry(input rob_entry_t entry);
  EX_packet_from_entry.valid       = entry.valid;
  EX_packet_from_entry.renamed_tag = rename_dest_tag(entry.tag);
  EX_packet_from_entry.packet      = entry.data.packet;
endfunction

function automatic EX_packet_t rob_cache_read_ex(
  input logic [ROB_DATA_W:0] entry,
  input gpr_addr_t           tag
);
  return EX_packet_from_entry(rob_cache_read_entry(entry, tag));
endfunction

function automatic EX_packet_t EX_packet_if(
  input logic       en,
  input EX_packet_t packet
);
  return en ? packet : '0;
endfunction

function automatic EX_packet_t rob_apply_forward(
  input EX_packet_t          pkt,
  input gpr_addr_t           tags [ROB_WAYS],
  input logic [ROB_DATA_W:0] bank [ROB_WAYS],
  input rob_ptr_t            commit_ptr,
  input rob_ptr_t            write_ptr
);
  rob_apply_forward = pkt;
  if (!pkt.valid)
    return pkt;
  if (pkt.packet.rs1_use)
    rob_apply_forward.packet.rs1_data = rob_forward_operand(
      tags, bank, pkt.packet.rs1, pkt.packet.rs1_data, commit_ptr, write_ptr
    );
  if (pkt.packet.rs2_use)
    rob_apply_forward.packet.rs2_data = rob_forward_operand(
      tags, bank, pkt.packet.rs2, pkt.packet.rs2_data, commit_ptr, write_ptr
    );
endfunction

function automatic EX_packet_t ex_packet_route_even(
  input logic       disp_en,
  input EX_packet_t packet
);
  return EX_packet_if(disp_en && packet.valid && !packet.packet.lane_sel, packet);
endfunction

function automatic EX_packet_t ex_packet_route_odd(
  input logic       disp_en,
  input EX_packet_t packet
);
  return EX_packet_if(disp_en && packet.valid && packet.packet.lane_sel, packet);
endfunction

function automatic logic ex_packet_valid(
  input logic       disp_en,
  input EX_packet_t packet
);
  return disp_en && packet.valid;
endfunction

function automatic logic ex_packet_reg_write(
  input logic       disp_en,
  input EX_packet_t packet
);
  return disp_en && packet.valid && packet.packet.reg_write;
endfunction

// -------------------------------------------------------------------------
// Reservation station entry helpers
// -------------------------------------------------------------------------
function automatic rs_entry_t rs_entry_from_ex(input EX_packet_t ex);
  rs_entry_from_ex.valid       = ex.valid;
  rs_entry_from_ex.renamed_tag = ex.renamed_tag;
  rs_entry_from_ex.packet      = ex.packet;
endfunction

function automatic EX_packet_t ex_from_rs_entry(input rs_entry_t entry);
  ex_from_rs_entry.valid       = entry.valid;
  ex_from_rs_entry.renamed_tag = entry.renamed_tag;
  ex_from_rs_entry.packet      = entry.packet;
endfunction

endpackage
