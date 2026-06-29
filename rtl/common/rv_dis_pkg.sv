`timescale 1ns / 1ps

// RV-DIS shared package — RV32I scalar core (dual-issue). Types, geometry, ISA constants.
// Instruction decode helpers: rtl/s2_decode/core/decode_funct/decode.sv (decode_pkg).
package rv_dis_pkg;

  // =========================================================================
  // Widths
  // =========================================================================
  localparam int ILEN = 32;          // instruction width
  localparam int RLEN = 32;          // GPR / datapath width
  localparam int NUM_GPR = 32;     // x0–x31

  // =========================================================================
  // Memory geometry (byte addressing — one address = 8 bits)
  // =========================================================================
  localparam int ADDR_UNIT_BITS = 8;
  localparam int I_SIZE         = 8 * (1 << 15);  // 32 KiB instruction space
  localparam int M_SIZE         = 8 * (1 << 15);  // 32 KiB data space
  localparam int PC_INDEX_AW    = 13;             // insn index PC[14:2] over I$

  // =========================================================================
  // Port / signal typedefs — use on module boundaries (not bare logic [N:0])
  // =========================================================================
  typedef logic [ILEN-1:0] instr_t;
  typedef logic [RLEN-1:0] reg_t;
  typedef logic [RLEN-1:0] pc_t;
  typedef logic [RLEN-1:0] imm_t;
  typedef logic [6:0]      opcode_t;
  typedef logic [2:0]      funct3_t;
  typedef logic [6:0]      funct7_t;
  typedef logic [4:0]      gpr_addr_t;
  typedef logic [1:0]      br_state_t;
  typedef logic [3:0]      mem_besel_t;

  // =========================================================================
  // RV32I opcodes (major opcode field)
  // =========================================================================
  localparam opcode_t OPC_OP     = 7'b0110011;
  localparam opcode_t OPC_OP_IMM = 7'b0010011;
  localparam opcode_t OPC_LOAD   = 7'b0000011;
  localparam opcode_t OPC_STORE  = 7'b0100011;
  localparam opcode_t OPC_BRANCH = 7'b1100011;
  localparam opcode_t OPC_JAL    = 7'b1101111;
  localparam opcode_t OPC_JALR   = 7'b1100111;
  localparam opcode_t OPC_AUIPC  = 7'b0010111;
  localparam opcode_t OPC_LUI    = 7'b0110111;

  // =========================================================================
  // funct3
  // =========================================================================
  // ALU (OP / OP-IMM)
  localparam funct3_t F3_ADD_SUB = 3'b000;
  localparam funct3_t F3_SLL     = 3'b001;
  localparam funct3_t F3_SLT     = 3'b010;
  localparam funct3_t F3_XOR     = 3'b100;
  localparam funct3_t F3_SRL_SRA = 3'b101;
  localparam funct3_t F3_OR      = 3'b110;
  localparam funct3_t F3_AND     = 3'b111;

  // Load / store (LW / SW only in this core)
  localparam funct3_t F3_LW = 3'b010;
  localparam funct3_t F3_SW = 3'b010;

  // Branch
  localparam funct3_t F3_BEQ = 3'b000;
  localparam funct3_t F3_BNE = 3'b001;
  localparam funct3_t F3_BLT = 3'b100;
  localparam funct3_t F3_BGE = 3'b101;

  // =========================================================================
  // funct7 (R-type; I-type shifts use imm[11:5])
  // =========================================================================
  localparam funct7_t F7_SUB = 7'b0100000;
  localparam funct7_t F7_SRA = 7'b0100000;

  // lane_sel — 0 = even (OP / OP-IMM), 1 = odd (load/store/branch/jump/LUI/AUIPC)

  // =========================================================================
  // Dispatch — Reorder Buffer entry (id_ex_dispatch).
  // Lifecycle codes and helpers: rtl/s3_execution/funct_pkg/dispatch.sv (dispatch_pkg).
  // =========================================================================
  localparam int ROB_DEPTH = 16;
  localparam int ROB_AW    = 4;

  typedef struct packed {
    logic        valid;
    logic        lane_sel;
    opcode_t     opcode;
    funct3_t     funct3;
    funct7_t     funct7;
    gpr_addr_t   rd;
    gpr_addr_t   rs1;
    gpr_addr_t   rs2;
    logic        rs1_use;
    logic        rs2_use;
    logic        reg_write;
    imm_t        imm;
    reg_t        rs1_data;
    reg_t        rs2_data;
    pc_t         pc;
  } rob_entry_t;

  // =========================================================================
  // Dispatch — single I1 replay slot (scoreboard RAW hold)
  // =========================================================================
  typedef struct packed {
    logic        valid;
    logic        lane_sel;
    opcode_t     opcode;
    funct3_t     funct3;
    funct7_t     funct7;
    gpr_addr_t   rd;
    gpr_addr_t   rs1;
    gpr_addr_t   rs2;
    logic        rs1_use;
    logic        rs2_use;
    logic        reg_write;
    imm_t        imm;
    reg_t        rs1_data;
    reg_t        rs2_data;
    pc_t         pc;
    gpr_addr_t   producer_rd;
    pc_t         bundle_i0_pc;
    pc_t         bundle_i1_pc;
    logic [1:0]  wait_total;  // 1 = ALU RAW, 2 = load-use
    logic [1:0]  wait_cnt;
  } i1_buffer_node_t;

  // =========================================================================
  // Immediate helpers
  // =========================================================================
  // imm_align4 — force imm[1:0]=00 on branch/jump offsets (B, J, JALR)
  function automatic imm_t imm_align4(input imm_t imm);
    imm_align4 = {imm[31:2], 2'b00};
  endfunction

  // sign_extend — I-type / OP-IMM 12-bit field to 32-bit byte offset
  function automatic imm_t sign_extend(input logic [11:0] imm12);
    sign_extend = {{20{imm12[11]}}, imm12};
  endfunction

endpackage
