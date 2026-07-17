`timescale 1ns / 1ps

// Reorder Buffer — geometry like I$/BTB (cache_pkg style).
// Storage: SETS × WAYS bank; flat ROB index = {set, way}.
package rob_pkg;

import rv_dis_pkg::*;

// -------------------------------------------------------------------------
// 2-way set-associative geometry (dual-issue: I0→way0, I1→way1 per set)
// -------------------------------------------------------------------------
localparam int ROB_WAYS    = 2;
localparam int ROB_WAY_AW  = (ROB_WAYS <= 1) ? 0 : $clog2(ROB_WAYS);
localparam int ROB_INDEX_W = ROB_AW;                        // from rv_dis_pkg
localparam int ROB_SET_AW  = ROB_INDEX_W - ROB_WAY_AW;      // 3
localparam int ROB_SETS    = (1 << ROB_INDEX_W) / ROB_WAYS; // 8
// ROB_DEPTH from rv_dis_pkg (SETS × WAYS)

typedef logic [ROB_AW:0]       rob_ptr_t;
typedef logic [ROB_SET_AW-1:0] rob_set_t;
typedef logic [ROB_WAY_AW-1:0] rob_way_t;

// Flat index → set / way.
function automatic rob_set_t rob_idx_set(input rob_idx_t idx);
  return idx[ROB_AW-1:ROB_WAY_AW];
endfunction

function automatic rob_way_t rob_idx_way(input rob_idx_t idx);
  return idx[ROB_WAY_AW-1:0];
endfunction

// bank[set][way] line = {valid, payload}
typedef struct packed {
  logic       complete;   // 1
  logic       reg_write;  // 1
  logic       is_branch;  // 1
  br_map_t    brch_map;   // 2
  gpr_addr_t  rd;         // 5
  prf_addr_t  prd;        // 6
  prf_addr_t  prd_old;    // 6
  logic       br_taken;   // 1 — branch only; data values write PRF at EX
} rob_payload_t;

localparam int ROB_PAYLOAD_W = $bits(rob_payload_t);
localparam int ROB_LINE_W    = ROB_PAYLOAD_W + 1;  // {valid, payload}

typedef logic [ROB_PAYLOAD_W:0] rob_line_t;

// Pack/unpack like cache_pkg cache_set_write / cache_way_read (wider payload).
function automatic rob_line_t rob_way_write(
  input logic         valid,
  input rob_payload_t payload
);
  return {valid, payload};
endfunction

function automatic logic rob_way_valid(input rob_line_t line);
  return line[ROB_PAYLOAD_W];
endfunction

function automatic rob_payload_t rob_way_read(
  input rob_line_t    line,
  input rob_payload_t default_payload
);
  if (rob_way_valid(line))
    return line[ROB_PAYLOAD_W-1:0];
  return default_payload;
endfunction

function automatic rob_payload_t rob_payload_make(
  input logic       complete,
  input logic       reg_write,
  input logic       is_branch,
  input br_map_t    brch_map,
  input gpr_addr_t  rd,
  input prf_addr_t  prd,
  input prf_addr_t  prd_old,
  input logic       br_taken
);
  rob_payload_make.complete  = complete;
  rob_payload_make.reg_write = reg_write;
  rob_payload_make.is_branch = is_branch;
  rob_payload_make.brch_map  = brch_map;
  rob_payload_make.rd        = rd;
  rob_payload_make.prd       = prd;
  rob_payload_make.prd_old   = prd_old;
  rob_payload_make.br_taken  = br_taken;
endfunction

// Branch commit → winning RAT column: 0=path0/map_br0, 1=path1/map_br1.
// brch_map on branch entries is BR_MAP_I0 (i0) or BR_MAP_I1 (i1).
// ROB drives resolve_en + rat_path to RAT on branch commit.
function automatic logic rob_branch_rat_path(
  input br_map_t brch_map,
  input logic    taken
);
  if (brch_map == BR_MAP_I0)
    return taken ? 1'b0 : 1'b1;
  if (brch_map == BR_MAP_I1)
    return taken ? 1'b1 : 1'b0;
  return 1'b0;
endfunction

endpackage
