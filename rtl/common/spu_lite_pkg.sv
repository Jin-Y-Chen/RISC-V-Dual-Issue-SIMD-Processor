`timescale 1ns / 1ps

// Shared constants and types for RV-DIS (RV32I scalar active; vector/SIMD reserved below).
package spu_lite_pkg;

  // Datapath / register widths (three different quantities — do not confuse):
  //   ILEN  — every encoded instruction is a fixed 32-bit word (RV32I base ISA).
  //   XLEN  — scalar GPR width (x0–x31); also width of scalar ALU results.
  //   VLEN  — vector register width for 128-bit SIMD (v0–v7); separate from GPRs.
  localparam int ILEN      = 32;
  localparam int XLEN      = 32;
  localparam int VLEN      = 128;
  localparam int NUM_GPR   = 32;
  localparam int NUM_VREG  = 8;
  localparam int VLEN_BYTES = VLEN / 8;  // 16 bytes per vector register
  localparam int VADDR_ALIGN = VLEN_BYTES; // VLD128/VST128 alignment

  // Memory addressing (RV32I-compatible, RV-DIS scalar path):
  //   ADDR_UNIT_BITS = 8 — each address increment is one byte (standard RISC-V).
  //   Immediates are byte offsets (rs1 + imm, pc + imm), not 16-bit-word addresses.
  //   (RVC uses 16-bit *instructions* at 2-byte PC alignment; this core uses ILEN=32 @ PC%4.)
  localparam int ADDR_UNIT_BITS = 8;

  typedef logic [ILEN-1:0]  instr_t;
  typedef logic [XLEN-1:0]  xlen_t;
  typedef logic [VLEN-1:0]  vreg_t;

  // RV32I major opcodes
  localparam logic [6:0] OPC_OP     = 7'b0110011;
  localparam logic [6:0] OPC_OP_IMM = 7'b0010011;
  localparam logic [6:0] OPC_LOAD   = 7'b0000011;
  localparam logic [6:0] OPC_STORE  = 7'b0100011;
  localparam logic [6:0] OPC_BRANCH = 7'b1100011;
  localparam logic [6:0] OPC_JAL    = 7'b1101111;
  localparam logic [6:0] OPC_JALR   = 7'b1100111;

  // --- Vector/SIMD (not wired in s3_execution yet; for future even/odd lanes) ---
  // Custom opcodes (RV32I custom-0 / custom-1 — not RISC-V "V" OP-V)
  localparam logic [6:0] OPC_VEC_ALU = 7'b0001011; // even lane: VADD..VXOR
  localparam logic [6:0] OPC_VEC_MEM = 7'b0101011; // odd lane:  VLD128/VST128

  // funct3 — SIMD lane width (.b / .h / .w)
  localparam logic [2:0] F3_VEC_B = 3'b000; // 16 x  8-bit
  localparam logic [2:0] F3_VEC_H = 3'b001; //  8 x 16-bit
  localparam logic [2:0] F3_VEC_W = 3'b010; //  4 x 32-bit

  // funct3 — vector memory (under OPC_VEC_MEM)
  localparam logic [2:0] F3_VLD128 = 3'b000;
  localparam logic [2:0] F3_VST128 = 3'b001;

  // funct7 — vector ALU operation (under OPC_VEC_ALU)
  localparam logic [6:0] F7_VADD = 7'b0000000;
  localparam logic [6:0] F7_VSUB = 7'b0000001;
  localparam logic [6:0] F7_VAND = 7'b0000010;
  localparam logic [6:0] F7_VOR  = 7'b0000011;
  localparam logic [6:0] F7_VXOR = 7'b0000100;

  // funct3 — integer register-register / register-immediate ALU
  localparam logic [2:0] F3_ADD_SUB = 3'b000;
  localparam logic [2:0] F3_XOR     = 3'b100;
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

  // funct7 — SUB is ADD with bit 5 set (R-type only)
  localparam logic [6:0] F7_SUB = 7'b0100000;

  typedef enum logic [2:0] {
    ALU_ADD,
    ALU_SUB,
    ALU_AND,
    ALU_OR,
    ALU_XOR
  } alu_op_e;

  typedef enum logic [1:0] {
    ALU_A_RS1,
    ALU_A_PC
  } alu_a_sel_e;

  typedef enum logic [1:0] {
    ALU_B_RS2,
    ALU_B_IMM,
    ALU_B_FOUR
  } alu_b_sel_e;

  typedef enum logic [2:0] {
    VEC_ALU_ADD,
    VEC_ALU_SUB,
    VEC_ALU_AND,
    VEC_ALU_OR,
    VEC_ALU_XOR
  } vec_alu_op_e;

  typedef enum logic [1:0] {
    LANE_B,
    LANE_H,
    LANE_W
  } lane_mode_e;

  // 3-bit vector register index carried in rd/rs1/rs2 fields [2:0]
  function automatic logic [2:0] vreg_idx(input logic [4:0] reg_field);
    return reg_field[2:0];
  endfunction

  function automatic logic is_vec_alu(input logic [6:0] opcode);
    return (opcode == OPC_VEC_ALU);
  endfunction

  function automatic logic is_vec_mem(input logic [6:0] opcode);
    return (opcode == OPC_VEC_MEM);
  endfunction

  function automatic vec_alu_op_e decode_vec_alu_op(input logic [6:0] funct7);
    unique case (funct7)
      F7_VADD: decode_vec_alu_op = VEC_ALU_ADD;
      F7_VSUB: decode_vec_alu_op = VEC_ALU_SUB;
      F7_VAND: decode_vec_alu_op = VEC_ALU_AND;
      F7_VOR:  decode_vec_alu_op = VEC_ALU_OR;
      F7_VXOR: decode_vec_alu_op = VEC_ALU_XOR;
      default: decode_vec_alu_op = VEC_ALU_ADD;
    endcase
  endfunction

  function automatic lane_mode_e decode_lane_mode(input logic [2:0] funct3);
    unique case (funct3)
      F3_VEC_B: decode_lane_mode = LANE_B;
      F3_VEC_H: decode_lane_mode = LANE_H;
      F3_VEC_W: decode_lane_mode = LANE_W;
      default:  decode_lane_mode = LANE_W;
    endcase
  endfunction

  // -------------------------------------------------------------------------
  // Immediate decode
  //
  // RISC-V scatters immediate bits across non-contiguous instruction fields.
  // Each function gathers those slices, then sign-extends to 32-bit byte offsets
  // (ADDR_UNIT_BITS = 8: one address = one byte, per RV32I).
  //
  // RV-DIS does not use 16-bit-per-address memory. Scalar LW/SW and PC math use
  // byte addresses; imm_align4 clears imm[1:0] so word ops and 32-bit fetch
  // stay aligned to multiples of 4 (see project_outline / USART byte map).
  //
  // B/J ISA encoding leaves imm[0] implicit; imm_align4 also clears imm[1].
  // -------------------------------------------------------------------------

  function automatic logic [31:0] imm_align4(input logic [31:0] imm);
    return {imm[31:2], 2'b00};
  endfunction

  function automatic logic [31:0] sign_extend(input logic [11:0] imm12);
    return {{20{imm12[11]}}, imm12};
  endfunction

  function automatic logic [31:0] imm_i(input logic [31:0] instr);
    return imm_align4({{20{instr[31]}}, instr[31:20]});
  endfunction

  function automatic logic [31:0] imm_s(input logic [31:0] instr);
    return imm_align4({{20{instr[31]}}, instr[31:25], instr[11:7]});
  endfunction

  function automatic logic [31:0] imm_b(input logic [31:0] instr);
    return imm_align4({{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0});
  endfunction

  function automatic logic [31:0] imm_j(input logic [31:0] instr);
    return imm_align4({{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0});
  endfunction

  function automatic logic [31:0] imm_u(input logic [31:0] instr);
    return {instr[31:12], 12'b0};
  endfunction

  function automatic logic [31:0] decode_imm(
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [31:0] instr
  );
    unique case (opcode)
      OPC_OP_IMM,
      OPC_LOAD,
      OPC_JALR: decode_imm = imm_i(instr);
      OPC_STORE: decode_imm = imm_s(instr);
      OPC_BRANCH: decode_imm = imm_b(instr);
      OPC_JAL: decode_imm = imm_j(instr);
      OPC_VEC_MEM: decode_imm = (funct3 == F3_VST128) ? imm_s(instr) : imm_i(instr);
      default: decode_imm = imm_i(instr);
    endcase
  endfunction

  function automatic alu_op_e decode_alu_op(
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7
  );
    unique case (opcode)
      OPC_OP, OPC_OP_IMM: begin
        unique case (funct3)
          F3_ADD_SUB: decode_alu_op = (opcode == OPC_OP && funct7 == F7_SUB) ? ALU_SUB : ALU_ADD;
          F3_XOR:     decode_alu_op = ALU_XOR;
          F3_OR:      decode_alu_op = ALU_OR;
          F3_AND:     decode_alu_op = ALU_AND;
          default:    decode_alu_op = ALU_ADD;
        endcase
      end
      default: decode_alu_op = ALU_ADD;
    endcase
  endfunction

endpackage
