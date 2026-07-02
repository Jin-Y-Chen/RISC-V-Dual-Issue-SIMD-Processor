`timescale 1ns / 1ps

// Reorder Buffer — geometry, lifecycle codes, and entry types only.
// Queue operations live in rob_queue_pkg (rob_queue.sv).
package rob_pkg;

  import rv_dis_pkg::*;

// -------------------------------------------------------------------------
// Geometry and lifecycle codes
// -------------------------------------------------------------------------
localparam int ROB_DEPTH = 16;
localparam int ROB_AW    = 4;
localparam int ROB_CAP   = ROB_DEPTH;
localparam int ROB_WAYS  = ROB_DEPTH;  // single set, 16-way parallel tag compare

typedef logic [ROB_AW:0] rob_ptr_t;

typedef logic [2:0] rob_state_t;

localparam rob_state_t ROB_NEW       = 3'b000;
localparam rob_state_t ROB_READ      = 3'b001;
localparam rob_state_t ROB_EXECUTED  = 3'b010;
localparam rob_state_t ROB_SPEC_NEW  = 3'b100;
localparam rob_state_t ROB_SPEC_READ = 3'b101;
localparam rob_state_t ROB_SPEC_EXEC = 3'b110;

// -------------------------------------------------------------------------
// Entry types — ID snapshot + ROB cache payload (rename view in rename.sv)
// -------------------------------------------------------------------------
typedef struct packed {
  logic      lane_sel;
  logic      reg_write;
  logic      rs1_use;
  logic      rs2_use;
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

typedef struct packed {
  ID_packet_t packet;
  rob_state_t state;
  word_t      result;
} rob_data_t;

typedef struct packed {
  logic      valid;
  gpr_addr_t tag;
  rob_data_t data;
} rob_entry_t;

localparam int ROB_DATA_W = $bits(rob_data_t);

endpackage
