`timescale 1ns / 1ps

// Executable RV32I decode specification for decoder.sv.
//
// This model deliberately does not import decode_pkg or reproduce the DUT's
// helper graph.  gm_decode() treats the instruction as a software parser would:
// identify its ISA format, validate the supported encoding, then return one
// complete semantic result to the scoreboard.
import rv_dis_pkg::*;

module decoder_gm (
  input  instr_t      instr,
  output logic        lane_sel,
  output logic        brch_en,
  output logic        jump_en,
  output opcode_t     opcode,
  output funct3_t     funct3,
  output funct7_t     funct7,
  output gpr_addr_t   rd_addr,
  output gpr_addr_t   rs1_addr,
  output gpr_addr_t   rs2_addr,
  output word_t       imm,
  output logic        valid,
  output logic        rs1_use,
  output logic        rs2_use,
  output logic        store_en,
  output logic        reg_write
);

  typedef struct packed {
    opcode_t   opcode;
    funct3_t   funct3;
    funct7_t   funct7;
    gpr_addr_t rd;
    gpr_addr_t rs1;
    gpr_addr_t rs2;
    word_t     immediate;
    logic      valid;
    logic      rs1_use;
    logic      rs2_use;
    logic      lane_sel;
    logic      branch;
    logic      jump;
    logic      is_store;
    logic      writes_rd;
  } decode_result_t;

  // RV32I OP encodings implemented by the scalar core.
  function automatic logic legal_register_alu(
    input funct3_t f3,
    input funct7_t f7
  );
    logic base_alu;
    logic sub_or_sra;
    base_alu = (f7 == 7'b0000000);
    sub_or_sra = (f7 == 7'b0100000) &&
                 ((f3 == F3_ADD_SUB) || (f3 == F3_SRL_SRA));
    return base_alu || sub_or_sra;
  endfunction

  // RV32I OP-IMM: all non-shifts accept imm[11:0]; shifts constrain funct7.
  function automatic logic legal_immediate_alu(
    input funct3_t f3,
    input funct7_t f7
  );
    if (f3 == F3_SLL)
      return f7 == 7'b0000000;
    if (f3 == F3_SRL_SRA)
      return (f7 == 7'b0000000) || (f7 == 7'b0100000);
    return 1'b1;
  endfunction

  function automatic logic legal_branch(input funct3_t f3);
    return (f3 == F3_BEQ) || (f3 == F3_BNE) ||
           (f3 == F3_BLT) || (f3 == F3_BGE);
  endfunction

  function automatic decode_result_t gm_decode(input instr_t insn);
    decode_result_t result;
    opcode_t         opc;
    funct3_t         f3;
    funct7_t         f7;
    gpr_addr_t       encoded_rd;

    opc = insn[6:0];
    f3 = insn[14:12];
    f7 = insn[31:25];
    encoded_rd = insn[11:7];

    // Deterministic invalid-instruction result. Raw fields remain observable,
    // while all architectural side effects default off.
    result = '0;
    result.opcode = opc;
    result.funct3 = f3;
    result.rd = encoded_rd;
    result.rs1 = insn[19:15];
    result.immediate = sign_extend(insn[31:20]);

    if (opc == OPC_OP) begin
      result.valid = legal_register_alu(f3, f7);
      result.funct7 = f7;
      result.rs1_use = 1'b1;
      result.rs2_use = 1'b1;
      result.rs2 = insn[24:20];
      result.immediate = '0;
      result.writes_rd = result.valid && (encoded_rd != '0);
    end else if (opc == OPC_OP_IMM) begin
      result.valid = legal_immediate_alu(f3, f7);
      result.rs1_use = 1'b1;
      result.immediate = sign_extend(insn[31:20]);
      if ((f3 == F3_SLL) || (f3 == F3_SRL_SRA))
        result.funct7 = f7;
      result.writes_rd = result.valid && (encoded_rd != '0);
    end else if (opc == OPC_LOAD) begin
      // RV-DIS scalar memory subset: LW only.
      result.valid = (f3 == F3_LW);
      result.rs1_use = 1'b1;
      result.lane_sel = 1'b1;
      result.immediate = sign_extend(insn[31:20]);
      result.writes_rd = result.valid && (encoded_rd != '0);
    end else if (opc == OPC_STORE) begin
      // RV-DIS scalar memory subset: SW only.
      result.valid = (f3 == F3_SW);
      result.rd = '0;
      result.rs1_use = 1'b1;
      result.rs2_use = 1'b1;
      result.rs2 = insn[24:20];
      result.lane_sel = 1'b1;
      result.is_store = result.valid;
      result.immediate = {{20{insn[31]}}, insn[31:25], insn[11:7]};
    end else if (opc == OPC_BRANCH) begin
      result.valid = legal_branch(f3);
      result.rd = '0;
      result.rs1_use = 1'b1;
      result.rs2_use = 1'b1;
      result.rs2 = insn[24:20];
      result.lane_sel = 1'b1;
      result.branch = result.valid;
      // B-immediate already encodes bit 0 as zero; preserve encoded bit 1.
      result.immediate = {
        {19{insn[31]}}, insn[31], insn[7],
        insn[30:25], insn[11:8], 1'b0
      };
    end else if (opc == OPC_JAL) begin
      result.valid = 1'b1;
      result.funct3 = '0;
      result.rs1 = '0;
      result.lane_sel = 1'b1;
      result.branch = 1'b1;
      result.jump = 1'b1;
      result.writes_rd = (encoded_rd != '0);
      // J-immediate is a signed byte offset with an implicit zero bit 0.
      result.immediate = {
        {11{insn[31]}}, insn[31], insn[19:12],
        insn[20], insn[30:21], 1'b0
      };
    end else if (opc == OPC_JALR) begin
      // JALR is defined only for funct3=000.
      result.valid = (f3 == 3'b000);
      result.rs1_use = 1'b1;
      result.lane_sel = 1'b1;
      result.branch = result.valid;
      result.jump = result.valid;
      result.writes_rd = result.valid && (encoded_rd != '0);
      // JALR consumes the ordinary signed I-immediate. Target bit 0 is cleared
      // by jump execution, not by instruction decoding.
      result.immediate = sign_extend(insn[31:20]);
    end else if ((opc == OPC_LUI) || (opc == OPC_AUIPC)) begin
      result.valid = 1'b1;
      result.funct3 = '0;
      result.rs1 = '0;
      result.lane_sel = 1'b1;
      result.writes_rd = (encoded_rd != '0);
      result.immediate = {insn[31:12], 12'b0};
    end

    return result;
  endfunction

  decode_result_t expected;
  assign expected = gm_decode(instr);

  assign opcode    = expected.opcode;
  assign funct3    = expected.funct3;
  assign funct7    = expected.funct7;
  assign rd_addr   = expected.rd;
  assign rs1_addr  = expected.rs1;
  assign rs2_addr  = expected.rs2;
  assign imm       = expected.immediate;
  assign valid     = expected.valid;
  assign rs1_use   = expected.rs1_use;
  assign rs2_use   = expected.rs2_use;
  assign lane_sel  = expected.lane_sel;
  assign brch_en   = expected.branch;
  assign jump_en   = expected.jump;
  assign store_en  = expected.is_store;
  assign reg_write = expected.writes_rd;

endmodule
