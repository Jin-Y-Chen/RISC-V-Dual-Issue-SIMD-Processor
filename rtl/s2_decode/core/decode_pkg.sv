`timescale 1ns / 1ps

// ID-stage decode: immediates, instruction fields, lane_sel, legality, ALU op.
package decode_pkg;

  import rv_dis_pkg::*;

  // -------------------------------------------------------------------------
  // Immediate decode
  //
  // RISC-V scatters immediate bits across non-contiguous instruction fields.
  // Each function gathers those slices and sign-extends to 32-bit byte offsets
  // (ADDR_UNIT_BITS = 8: one address = one byte).
  // imm_align4: force imm[1:0]=00 on branch/jump PC-relative offsets (B, J, JALR).
  // Load/store/OP-IMM use full sign-extended immediates (no align4).
  // B/J types leave imm[0] implicit in the encoding; decode appends 1'b0.
  // -------------------------------------------------------------------------

  function automatic logic [31:0] imm_align4(input logic [31:0] imm);
    return {imm[31:2], 2'b00};
  endfunction

  function automatic logic [31:0] sign_extend(input logic [11:0] imm12);
    return {{20{imm12[11]}}, imm12};
  endfunction

  function automatic logic [31:0] imm_i(input logic [31:0] instr);
    return sign_extend(instr[31:20]);
  endfunction

  function automatic logic [31:0] imm_jalr(input logic [31:0] instr);
    return imm_align4(imm_i(instr));
  endfunction

  // OP-IMM: full sign-extended imm[11:0] (addi, slti, shifts, logic-imms, etc.)
  function automatic logic [31:0] imm_op_imm(input logic [31:0] instr);
    return sign_extend(instr[31:20]);
  endfunction

  function automatic logic [31:0] imm_s(input logic [31:0] instr);
    return {{20{instr[31]}}, instr[31:25], instr[11:7]};
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
      OPC_OP_IMM: decode_imm = imm_op_imm(instr);
      OPC_LOAD:   decode_imm = imm_i(instr);
      OPC_JALR:   decode_imm = imm_jalr(instr);
      OPC_STORE:  decode_imm = imm_s(instr);
      OPC_BRANCH: decode_imm = imm_b(instr);
      OPC_JAL: decode_imm = imm_j(instr);
      OPC_LUI,
      OPC_AUIPC: decode_imm = imm_u(instr);
      OPC_OP:      decode_imm = 32'd0;  // R-type: no immediate
      // OPC_VEC_MEM: decode_imm = (funct3 == F3_VST128) ? imm_s(instr) : imm_i(instr);
      default: decode_imm = imm_i(instr);
    endcase
  endfunction

  function automatic logic [6:0] decode_opcode(input logic [31:0] instr);
    return instr[6:0];
  endfunction

  function automatic logic [2:0] decode_funct3(input logic [31:0] instr);
    return instr[14:12];
  endfunction

  function automatic logic [6:0] decode_funct7(input logic [31:0] instr);
    return instr[31:25];
  endfunction

  function automatic logic [4:0] decode_rd(input logic [31:0] instr);
    return instr[11:7];
  endfunction

  function automatic logic [4:0] decode_rs1(input logic [31:0] instr);
    return instr[19:15];
  endfunction

  function automatic logic [4:0] decode_rs2(input logic [31:0] instr);
    return instr[24:20];
  endfunction

  // GPR index outputs: unused register fields are zero (not imm/relocation slots).
  function automatic logic [4:0] decode_rd_gpr(
    input logic [6:0] opcode,
    input logic [31:0] instr
  );
    unique case (opcode)
      OPC_STORE,
      OPC_BRANCH: decode_rd_gpr = 5'd0;
      default:    decode_rd_gpr = decode_rd(instr);
    endcase
  endfunction

  function automatic logic [4:0] decode_rs1_gpr(
    input logic [6:0] opcode,
    input logic [31:0] instr
  );
    unique case (opcode)
      OPC_LUI,
      OPC_AUIPC,
      OPC_JAL: decode_rs1_gpr = 5'd0;
      default: decode_rs1_gpr = decode_rs1(instr);
    endcase
  endfunction

  function automatic logic [4:0] decode_rs2_gpr(
    input logic [6:0] opcode,
    input logic [31:0] instr
  );
    if (decode_rs2_use(opcode))
      decode_rs2_gpr = decode_rs2(instr);
    else
      decode_rs2_gpr = 5'd0;
  endfunction

  function automatic logic [2:0] decode_funct3_gpr(input logic [6:0] opcode, input logic [31:0] instr);
    unique case (opcode)
      OPC_LUI,
      OPC_AUIPC,
      OPC_JAL: decode_funct3_gpr = 3'd0;
      default: decode_funct3_gpr = decode_funct3(instr);
    endcase
  endfunction

  function automatic logic [6:0] decode_funct7_gpr(
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [31:0] instr
  );
    unique case (opcode)
      OPC_OP: decode_funct7_gpr = decode_funct7(instr);
      OPC_OP_IMM: begin
        if (funct3 == F3_SLL || funct3 == F3_SRL_SRA)
          decode_funct7_gpr = decode_funct7(instr);
        else
          decode_funct7_gpr = 7'd0;
      end
      default: decode_funct7_gpr = 7'd0;
    endcase
  endfunction

  function automatic lane_sel_e decode_lane_sel(input logic [6:0] opcode);
    unique case (opcode)
      OPC_OP,
      OPC_OP_IMM: decode_lane_sel = LANE_EVEN;
      OPC_LOAD,
      OPC_STORE,
      OPC_BRANCH,
      OPC_JAL,
      OPC_JALR,
      OPC_LUI,
      OPC_AUIPC:  decode_lane_sel = LANE_ODD;
      default:    decode_lane_sel = LANE_NONE;
    endcase
  endfunction

  function automatic logic decode_brch_en(input logic [6:0] opcode);
    unique case (opcode)
      OPC_BRANCH,
      OPC_JAL,
      OPC_JALR: decode_brch_en = 1'b1;
      default:  decode_brch_en = 1'b0;
    endcase
  endfunction

  // RV32I subset implemented in even_lane / odd_lane (SB/SH/LB/LH and *U branches off)
  function automatic logic insn_legal_scalar(
    input logic [6:0] opcode,
    input logic [2:0] funct3
  );
    unique case (opcode)
      OPC_OP,
      OPC_OP_IMM: insn_legal_scalar = 1'b1;
      OPC_LOAD:   insn_legal_scalar = (funct3 == F3_LW);
      OPC_STORE:  insn_legal_scalar = (funct3 == F3_SW);
      OPC_BRANCH: insn_legal_scalar = (funct3 == F3_BEQ) || (funct3 == F3_BNE) ||
                                      (funct3 == F3_BLT) || (funct3 == F3_BGE);
      OPC_JAL,
      OPC_JALR,
      OPC_LUI,
      OPC_AUIPC:  insn_legal_scalar = 1'b1;
      default:    insn_legal_scalar = 1'b0;
    endcase
  endfunction

  function automatic logic decode_rs1_use(input logic [6:0] opcode);
    unique case (opcode)
      OPC_OP,
      OPC_OP_IMM,
      OPC_LOAD,
      OPC_STORE,
      OPC_BRANCH,
      OPC_JALR: decode_rs1_use = 1'b1;
      default:  decode_rs1_use = 1'b0;
    endcase
  endfunction

  function automatic logic decode_rs2_use(input logic [6:0] opcode);
    unique case (opcode)
      OPC_OP,
      OPC_STORE,
      OPC_BRANCH: decode_rs2_use = 1'b1;
      default:    decode_rs2_use = 1'b0;
    endcase
  endfunction

  function automatic logic decode_reg_write(
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [4:0] rd
  );
    if (rd == 5'd0)
      decode_reg_write = 1'b0;
    else
      unique case (opcode)
        OPC_OP,
        OPC_OP_IMM,
        OPC_JAL,
        OPC_JALR,
        OPC_LUI,
        OPC_AUIPC: decode_reg_write = 1'b1;
        OPC_LOAD:  decode_reg_write = (funct3 == F3_LW);
        default:   decode_reg_write = 1'b0;
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
          F3_SLL:     decode_alu_op = ALU_SLL;
          F3_SLT:     decode_alu_op = ALU_SLT;
          F3_XOR:     decode_alu_op = ALU_XOR;
          F3_SRL_SRA: decode_alu_op = (funct7 == F7_SRA) ? ALU_SRA : ALU_SRL;
          F3_OR:      decode_alu_op = ALU_OR;
          F3_AND:     decode_alu_op = ALU_AND;
          default:    decode_alu_op = ALU_ADD;
        endcase
      end
      default: decode_alu_op = ALU_ADD;
    endcase
  endfunction

endpackage
