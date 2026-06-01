`timescale 1ns / 1ps

// Shared constants and types for RV-DIS (RV32I scalar only; SIMD commented out).
package rv_dis_pkg;

  // Datapath / register widths:
  //   ILEN — 32-bit instruction word (RV32I)
  //   XLEN — scalar GPR width (x0–x31)
  localparam int ILEN    = 32;

  //register size = XLEN * NUM_GPR = 32 * 32 = 1024 bits = 128 bytes
  localparam int XLEN    = 32; // Register width = 32 bits
  localparam int NUM_GPR = 32; // Number registers = 32 (x0-x31)

  // --- SIMD (disabled) ---
  // localparam int VLEN      = 128;
  // localparam int NUM_VREG  = 8;
  // localparam int VLEN_BYTES = VLEN / 8;
  // localparam int VADDR_ALIGN = VLEN_BYTES;

  // Memory addressing (RV32I-compatible, RV-DIS scalar path):
  //   ADDR_UNIT_BITS = 8 — each address increment is one byte (standard RISC-V).
  //   Immediates are byte offsets (rs1 + imm, pc + imm), not 16-bit-word addresses.
  //   (RVC uses 16-bit *instructions* at 2-byte PC alignment; this core uses ILEN=32 @ PC%4.)
  localparam int ADDR_UNIT_BITS = 8;

  typedef logic [ILEN-1:0] instr_t;
  typedef logic [XLEN-1:0] xlen_t;
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

  // No functions in this package — types/constants only.
  // Scalar decode: rtl/s2_decode/rv_dis_decode_pkg.sv

endpackage
