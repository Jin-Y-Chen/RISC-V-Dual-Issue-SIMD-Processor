`timescale 1ns / 1ps

// Reorder Buffer — geometry, rename entry types, and cache bank helpers.
// Storage model: single-set, ROB_WAYS-way CAM/index bank (like I$/BTB packing).
package rob_pkg;

import rv_dis_pkg::*;

localparam int ROB_DEPTH = 16;
localparam int ROB_AW    = 4;
localparam int ROB_CAP   = ROB_DEPTH;
localparam int ROB_WAYS  = ROB_DEPTH;  // 1-set, fully associative over ways

typedef logic [ROB_AW:0] rob_ptr_t;

typedef logic [2:0] rob_state_t;

localparam rob_state_t ROB_NEW       = 3'b000;
localparam rob_state_t ROB_READ      = 3'b001;
localparam rob_state_t ROB_EXECUTED  = 3'b010;
localparam rob_state_t ROB_SPEC_NEW  = 3'b100;
localparam rob_state_t ROB_SPEC_READ = 3'b101;
localparam rob_state_t ROB_SPEC_EXEC = 3'b110;

typedef struct packed {
  logic      lane_sel;
  logic      reg_write;
  opcode_t   opcode;
  funct3_t   funct3;
  funct7_t   funct7;
  gpr_addr_t rs1;
  gpr_addr_t rs2;
  word_t     imm;
  word_t     rs1_data;
  word_t     rs2_data;
  word_t     pc;
} ID_packet_t;

// Packed ROB cache payload (valid bit sits outside in the bank line).
typedef struct packed {
  logic       complete;
  logic       reg_write;
  gpr_addr_t  rd;
  prf_addr_t  prd;
  prf_addr_t  prd_old;
  ID_packet_t meta;
  word_t      result;
} rob_payload_t;

localparam int ROB_PAYLOAD_W = $bits(rob_payload_t);
localparam int ROB_LINE_W    = ROB_PAYLOAD_W + 1;  // {valid, payload}

typedef logic [ROB_PAYLOAD_W:0] rob_line_t;

function automatic rob_line_t rob_cache_pack(
  input logic         valid,
  input rob_payload_t payload
);
  rob_cache_pack = {valid, payload};
endfunction

function automatic logic rob_cache_valid(input rob_line_t line);
  return line[ROB_PAYLOAD_W];
endfunction

function automatic rob_payload_t rob_cache_payload(input rob_line_t line);
  return line[ROB_PAYLOAD_W-1:0];
endfunction

function automatic rob_payload_t rob_cache_payload_read(
  input rob_line_t    line,
  input rob_payload_t default_payload
);
  if (rob_cache_valid(line))
    return rob_cache_payload(line);
  return default_payload;
endfunction

function automatic rob_payload_t rob_payload_make(
  input logic       complete,
  input logic       reg_write,
  input gpr_addr_t  rd,
  input prf_addr_t  prd,
  input prf_addr_t  prd_old,
  input ID_packet_t meta,
  input word_t      result
);
  rob_payload_make.complete  = complete;
  rob_payload_make.reg_write = reg_write;
  rob_payload_make.rd        = rd;
  rob_payload_make.prd       = prd;
  rob_payload_make.prd_old   = prd_old;
  rob_payload_make.meta      = meta;
  rob_payload_make.result    = result;
endfunction

// Occupancy window mask: ways between commit_ptr and write_ptr are live.
function automatic logic [ROB_WAYS-1:0] rob_window_mask(
  input rob_ptr_t commit_ptr,
  input rob_ptr_t write_ptr
);
  logic [ROB_WAYS-1:0] mask;
  rob_ptr_t            occ;
  rob_ptr_t            slot_ptr;
  integer              k;
  mask = '0;
  occ  = write_ptr - commit_ptr;
  for (k = 0; k < ROB_WAYS; k++) begin
    if (rob_ptr_t'(k) < occ) begin
      slot_ptr = commit_ptr + rob_ptr_t'(k);
      mask[slot_ptr[ROB_AW-1:0]] = 1'b1;
    end
  end
  return mask;
endfunction

// Parallel tag match (arch rd) over valid ways — CAM-style cache lookup.
function automatic logic [ROB_WAYS-1:0] rob_tag_match_vec(
  input gpr_addr_t query,
  input gpr_addr_t tag0,  input gpr_addr_t tag1,
  input gpr_addr_t tag2,  input gpr_addr_t tag3,
  input gpr_addr_t tag4,  input gpr_addr_t tag5,
  input gpr_addr_t tag6,  input gpr_addr_t tag7,
  input gpr_addr_t tag8,  input gpr_addr_t tag9,
  input gpr_addr_t tag10, input gpr_addr_t tag11,
  input gpr_addr_t tag12, input gpr_addr_t tag13,
  input gpr_addr_t tag14, input gpr_addr_t tag15,
  input logic      v0,  input logic v1,  input logic v2,  input logic v3,
  input logic      v4,  input logic v5,  input logic v6,  input logic v7,
  input logic      v8,  input logic v9,  input logic v10, input logic v11,
  input logic      v12, input logic v13, input logic v14, input logic v15
);
  logic [ROB_WAYS-1:0] m;
  m = '0;
  if (query != '0) begin
    m[0]  = v0  && (tag0  == query);
    m[1]  = v1  && (tag1  == query);
    m[2]  = v2  && (tag2  == query);
    m[3]  = v3  && (tag3  == query);
    m[4]  = v4  && (tag4  == query);
    m[5]  = v5  && (tag5  == query);
    m[6]  = v6  && (tag6  == query);
    m[7]  = v7  && (tag7  == query);
    m[8]  = v8  && (tag8  == query);
    m[9]  = v9  && (tag9  == query);
    m[10] = v10 && (tag10 == query);
    m[11] = v11 && (tag11 == query);
    m[12] = v12 && (tag12 == query);
    m[13] = v13 && (tag13 == query);
    m[14] = v14 && (tag14 == query);
    m[15] = v15 && (tag15 == query);
  end
  return m;
endfunction

endpackage
