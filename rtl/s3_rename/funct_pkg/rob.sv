`timescale 1ns / 1ps

// Reorder Buffer helpers — 32-entry circular queue, banked as 16×2.
//   flat = {row[3:0], way[0]}   I0→way0, I1→way1
//   PRF tag = {1'b1, flat} → p32..p63
package rob_pkg;

import rv_dis_pkg::*;

localparam int ROB_DEPTH   = 32;
localparam int ROB_WAYS    = 2;
localparam int ROB_WAY_AW  = 1;
localparam int ROB_SET_AW  = 4;
localparam int ROB_SETS    = 16;
localparam int ROB_INDEX_W = 5;

typedef logic [ROB_INDEX_W:0]   rob_ptr_t;   // head/tail + wrap
typedef logic [ROB_INDEX_W-1:0] rob_flat_t;  // 0..31
typedef logic [ROB_SET_AW-1:0]  rob_set_t;   // row
typedef logic [ROB_WAY_AW-1:0]  rob_way_t;   // way

function automatic rob_set_t rob_row(input rob_flat_t flat);
  return flat[ROB_INDEX_W-1:ROB_WAY_AW];
endfunction

function automatic rob_way_t rob_col(input rob_flat_t flat);
  return flat[ROB_WAY_AW-1:0];
endfunction

function automatic rob_flat_t rob_flat(input prf_addr_t idx);
  return idx[ROB_INDEX_W-1:0];
endfunction

function automatic rob_set_t rob_set(input prf_addr_t idx);
  return rob_row(rob_flat(idx));
endfunction

function automatic rob_way_t rob_way(input prf_addr_t idx);
  return rob_col(rob_flat(idx));
endfunction

function automatic prf_addr_t rob_to_prf(input rob_flat_t flat);
  return {1'b1, flat};
endfunction

function automatic rob_flat_t prf_to_rob(input prf_addr_t tag);
  return rob_flat(tag);
endfunction

typedef struct packed {
  logic       complete;
  logic       reg_write;
  logic       is_branch;
  logic       is_store;
  logic       spec_en;    // 0→path0/map_br1, 1→path1/map_br0
  logic       state_valid; // BHT hit at decode (0 = default state)
  br_state_t  brch_state;  // predicted BHT state snapshot
  gpr_addr_t  rd;
  logic       br_taken;
} rob_payload_t;

localparam int ROB_PAYLOAD_W = $bits(rob_payload_t);
localparam int ROB_LINE_W    = ROB_PAYLOAD_W + 1;

typedef logic [ROB_LINE_W-1:0] rob_line_t;

function automatic rob_payload_t rob_entry(
  input logic       reg_write,
  input logic       is_branch,
  input logic       is_store,
  input logic       spec_en,
  input logic       state_valid,
  input br_state_t  brch_state,
  input gpr_addr_t  rd
);
  rob_entry.complete    = 1'b0;
  rob_entry.reg_write   = reg_write;
  rob_entry.is_branch   = is_branch;
  rob_entry.is_store    = is_store;
  rob_entry.spec_en     = spec_en;
  rob_entry.state_valid = state_valid;
  rob_entry.brch_state  = brch_state;
  rob_entry.rd          = rd;
  rob_entry.br_taken    = 1'b0;
endfunction

function automatic rob_line_t rob_write(
  input logic         valid,
  input rob_payload_t payload
);
  return {valid, payload};
endfunction

// Wback — retirement control only (complete + branch taken). No EX result data.
function automatic rob_payload_t rob_wback(
  input rob_payload_t payload,
  input logic         br_taken
);
  rob_wback          = payload;
  rob_wback.complete = 1'b1;
  rob_wback.br_taken = br_taken;
endfunction

function automatic logic rob_valid(input rob_line_t line);
  return line[ROB_PAYLOAD_W];
endfunction

function automatic rob_payload_t rob_read(
  input rob_line_t    line,
  input rob_payload_t dflt
);
  if (rob_valid(line))
    return line[ROB_PAYLOAD_W-1:0];
  return dflt;
endfunction

function automatic logic rob_on_path(
  input logic entry_spec,
  input logic active_spec
);
  return entry_spec == active_spec;
endfunction

endpackage
