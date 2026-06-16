`timescale 1ns / 1ps

// Shared constants and types for RV-DIS (RV32I scalar only; SIMD commented out).
package rv_dis_pkg;

  // Instruction length = 32 bits
  localparam int ILEN = 32;
  // Instruction size = 8 * 2^15 = 32KB
  localparam int I_SIZE = 8*2**15; 
  // number addressable 8-bit instruction chunks
  localparam int NUM_IADDR = I_SIZE/8; 

  // Scalar GPR / datapath width (RV32I) — register length in bits
  localparam int RLEN = 32;
  localparam int NUM_GPR = 32;   // x0–x31
  localparam int NUM_RADDR = NUM_GPR; 
  // Register size = 32 * 32 = 1024 bits = 128 bytes
  localparam int R_SIZE = NUM_RADDR*RLEN; 

  // Cache length = 32 bits
  localparam int MLEN = 32; 
  // memory size = 8 * 2^15 = 32KB
  localparam int M_SIZE = 8*2**15; 
  // number of 32-bit memory chunks
  localparam int NUM_MADDR = M_SIZE/32; 

  // number of caches
  localparam int NUM_CACHES = 2; 
  // each cache size = 8 * 2^16 = 64KB
  localparam int C_SIZE = 8*2**16; 
  // total cache size = 2 * 64KB = 128KB
  localparam int TOTAL_C_SIZE = NUM_CACHES*C_SIZE; 

  // Memory addressing: one address = one byte (RV32I)
  localparam int ADDR_UNIT_BITS = 8;

  typedef logic [ILEN-1:0] instr_t;
  typedef logic [RLEN-1:0] reg_t;

  // typedef logic [VLEN-1:0] vreg_t;

  // RV32I major opcodes
  localparam logic [6:0] OPC_OP     = 7'b0110011;
  localparam logic [6:0] OPC_OP_IMM = 7'b0010011;
  localparam logic [6:0] OPC_LOAD   = 7'b0000011;
  localparam logic [6:0] OPC_STORE  = 7'b0100011;
  localparam logic [6:0] OPC_BRANCH = 7'b1100011;
  localparam logic [6:0] OPC_JAL    = 7'b1101111;
  localparam logic [6:0] OPC_JALR   = 7'b1100111;
  localparam logic [6:0] OPC_AUIPC  = 7'b0010111;
  localparam logic [6:0] OPC_LUI    = 7'b0110111;

  // --- Vector/SIMD opcodes (disabled; custom-0 / custom-1) ---
  // localparam logic [6:0] OPC_VEC_ALU = 7'b0001011;
  // localparam logic [6:0] OPC_VEC_MEM = 7'b0101011;
  // localparam logic [2:0] F3_VEC_B = 3'b000;
  // localparam logic [2:0] F3_VEC_H = 3'b001;
  // localparam logic [2:0] F3_VEC_W = 3'b010;
  // localparam logic [2:0] F3_VLD128 = 3'b000;
  // localparam logic [2:0] F3_VST128 = 3'b001;
  // localparam logic [6:0] F7_VADD = 7'b0000000;
  // localparam logic [6:0] F7_VSUB = 7'b0000001;
  // localparam logic [6:0] F7_VAND = 7'b0000010;
  // localparam logic [6:0] F7_VOR  = 7'b0000011;
  // localparam logic [6:0] F7_VXOR = 7'b0000100;

  // funct3 — integer register-register / register-immediate ALU
  localparam logic [2:0] F3_ADD_SUB = 3'b000;
  localparam logic [2:0] F3_SLL     = 3'b001;
  localparam logic [2:0] F3_SLT     = 3'b010;
  localparam logic [2:0] F3_XOR     = 3'b100;
  localparam logic [2:0] F3_SRL_SRA = 3'b101;
  localparam logic [2:0] F3_OR      = 3'b110;
  localparam logic [2:0] F3_AND     = 3'b111;

  // funct3 — loads / stores
  // localparam logic [2:0] F3_LB  = 3'b000;
  // localparam logic [2:0] F3_LH  = 3'b001;
  localparam logic [2:0] F3_LW  = 3'b010;
  // localparam logic [2:0] F3_LBU = 3'b100;
  // localparam logic [2:0] F3_LHU = 3'b101;

  // localparam logic [2:0] F3_SB = 3'b000;
  // localparam logic [2:0] F3_SH = 3'b001;
  localparam logic [2:0] F3_SW = 3'b010;

  // funct3 — branches
  localparam logic [2:0] F3_BEQ  = 3'b000;
  localparam logic [2:0] F3_BNE  = 3'b001;
  localparam logic [2:0] F3_BLT  = 3'b100;
  localparam logic [2:0] F3_BGE  = 3'b101;

  //localparam logic [2:0] F3_BLTU = 3'b110;
  //localparam logic [2:0] F3_BGEU = 3'b111;

  // funct7 — SUB/SRA use bit 5 set (R-type; I-type shifts use imm[11:5])
  localparam logic [6:0] F7_SUB = 7'b0100000;
  localparam logic [6:0] F7_SRA = 7'b0100000;

  typedef enum logic [3:0] {
    ALU_ADD,
    ALU_SUB,
    ALU_SLL,
    ALU_SLT,
    ALU_XOR,
    ALU_SRL,
    ALU_SRA,
    ALU_AND,
    ALU_OR
  } alu_op_e;

  // typedef enum logic [2:0] { VEC_ALU_ADD, VEC_ALU_SUB, ... } vec_alu_op_e;
  // typedef enum logic [1:0] { LANE_B, LANE_H, LANE_W } lane_mode_e;

  // Static even/odd partition (RV-DIS): which execution lane owns this opcode class
  typedef enum logic [1:0] {
    LANE_NONE = 2'b00,
    LANE_EVEN = 2'b01,
    LANE_ODD  = 2'b10
  } lane_sel_e;

  // Single I1 slot buffered at dispatch for in-order hazard replay (depth 1).
  typedef struct packed {
    logic        valid;
    lane_sel_e   lane;
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic        rs1_use;
    logic        rs2_use;
    logic        reg_write;
    logic [31:0] imm;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] pc;
    logic [4:0]  producer_rd;
    logic [31:0] bundle_i0_pc;
    logic [31:0] bundle_i1_pc;
    logic [1:0]  wait_total;  // 1=ALU RAW, 2=load-use
    logic [1:0]  wait_cnt;
  } i1_buffer_node_t;

  // No functions in this package — types/constants only.
  // Scalar decode: rtl/s2_decode/decode_pkg.sv

endpackage
