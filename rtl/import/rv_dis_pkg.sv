`timescale 1ns / 1ps
`ifndef RV_DIS_PKG_SV
`define RV_DIS_PKG_SV

// RV-DIS shared package — RV32I scalar core (dual-issue). Types, geometry, ISA constants.
// Instruction decode helpers: rtl/s2_decode/core/decode_funct/decode.sv (decode_pkg).
package rv_dis_pkg;

  // =========================================================================
  // Widths
  // =========================================================================
  localparam int ILEN = 32;          // instruction width
  localparam int RLEN = 32;          // GPR / datapath width
  localparam int NUM_GPR = 32;     // x0–x31
  // Physical register file (PRF) — arch x0–x31 plus rename temps (e.g. p32+)
  localparam int NUM_PRF = 64;
  localparam int PRF_AW  = $clog2(NUM_PRF);

  // =========================================================================
  // Memory geometry (byte addressing — one address = 8 bits)
  // =========================================================================
  localparam int ADDR_UNIT_BITS = 8;
  localparam int I_SIZE         = 8 * (1 << 15);  // 32 KiB instruction space
  localparam int M_SIZE         = 8 * (1 << 15);  // 32 KiB data space
  // 32-bit insn slots over byte-addressed storage => index width over PC[14:2].
  localparam int PC_INDEX_AW    = $clog2(I_SIZE / (4 * ADDR_UNIT_BITS));

  // =========================================================================
  // Port / signal typedefs — use on module boundaries (not bare logic [N:0])
  // =========================================================================
  typedef logic [ILEN-1:0] instr_t;
  typedef logic [RLEN-1:0] word_t;   // GPR value, PC, immediate, memory word

  // Architectural NOP: addi x0, x0, 0 (used for IF/ID bubbles).
  localparam instr_t INSTR_NOP = 32'h0000_0013;
  typedef logic [6:0]      opcode_t;
  typedef logic [2:0]      funct3_t;
  typedef logic [6:0]      funct7_t;
  typedef logic [4:0]      gpr_addr_t;      // ISA x0–x31 (architectural)
  typedef logic [PRF_AW-1:0] prf_addr_t;    // physical register index p0–p63
  typedef logic [1:0]      br_state_t;
  // Branch speculation map: {i1_pred_taken, i0_pred_taken}
  // 00 none, 01 i0, 10 i1, 11 both (from pc_selector).
  typedef logic [1:0]      br_map_t;
  localparam br_map_t BR_MAP_NONE = 2'b00;
  localparam br_map_t BR_MAP_I0   = 2'b01;
  localparam br_map_t BR_MAP_I1   = 2'b10;
  localparam br_map_t BR_MAP_BOTH = 2'b11;
  typedef logic [3:0]      mem_besel_t;

  // =========================================================================
  // Global defaults
  // =========================================================================
  localparam word_t RESET_PC = word_t'(32'h0000_0000);
  localparam word_t RESET_PC_INIT = RESET_PC;

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

  // =========================================================================
  // Immediate helpers
  // =========================================================================
  // imm_align4 — force imm[1:0]=00 on branch/jump offsets (B, J, JALR)
  function word_t imm_align4;
    input word_t imm;
    begin
      imm_align4 = {imm[31:2], 2'b00};
    end
  endfunction

  function word_t sign_extend;
    input [11:0] imm12;
    begin
      sign_extend = {{20{imm12[11]}}, imm12};
    end
  endfunction

endpackage
`endif
