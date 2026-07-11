`timescale 1ns / 1ps

// Golden model for rtl/s2_decode/core_mod/decoder.sv
// Independent of decode_pkg - opcode/funct3 control LUTs + field/imm helpers.
import rv_dis_pkg::*;

module decoder_gm (
  input  instr_t      instr,
  output logic        lane_sel,
  output logic        brch_en,
  output logic        jump_en,
  output opcode_t     opcode,
  output funct3_t     funct3,
  output funct7_t     funct7,
  output gpr_addr_t   rd,
  output gpr_addr_t   rs1,
  output gpr_addr_t   rs2,
  output word_t       imm,
  output logic        valid,
  output logic        rs1_use,
  output logic        rs2_use,
  output logic        reg_write
);

  // -------------------------------------------------------------------------
  // Opcode control LUT - one row per RV-DIS opcode class (keyed by opcode).
  // -------------------------------------------------------------------------
  typedef struct packed {
    logic lane_sel;
    logic brch_en;
    logic jump_en;
    logic rs1_use;
    logic rs2_use;
    logic reg_write_base;  // before rd==0 / LOAD legality
    logic [2:0] imm_sel;   // 0=I 1=S 2=B 3=J 4=U 5=JALR 6=OPIMM 7=R0
  } gm_opc_row_t;

  localparam logic [2:0] IMM_I     = 3'd0;
  localparam logic [2:0] IMM_S     = 3'd1;
  localparam logic [2:0] IMM_B     = 3'd2;
  localparam logic [2:0] IMM_J     = 3'd3;
  localparam logic [2:0] IMM_U     = 3'd4;
  localparam logic [2:0] IMM_JALR  = 3'd5;
  localparam logic [2:0] IMM_OPIMM = 3'd6;
  localparam logic [2:0] IMM_R0    = 3'd7;

  function automatic gm_opc_row_t opc_lut(input opcode_t opc);
    unique case (opc)
      //                lane brch jump rs1  rs2  regw imm
      OPC_OP:     opc_lut = '{1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, IMM_R0};
      OPC_OP_IMM: opc_lut = '{1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, IMM_OPIMM};
      OPC_LOAD:   opc_lut = '{1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, IMM_I};
      OPC_STORE:  opc_lut = '{1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, IMM_S};
      OPC_BRANCH: opc_lut = '{1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, IMM_B};
      OPC_JAL:    opc_lut = '{1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, IMM_J};
      OPC_JALR:   opc_lut = '{1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, IMM_JALR};
      OPC_LUI:    opc_lut = '{1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, IMM_U};
      OPC_AUIPC:  opc_lut = '{1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, IMM_U};
      default:    opc_lut = '{1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, IMM_I};
    endcase
  endfunction

  // Legality LUT - LOAD/STORE/BRANCH gated by funct3; others always legal if opcode known.
  function automatic logic legal_lut(input opcode_t opc, input funct3_t f3);
    unique case (opc)
      OPC_OP, OPC_OP_IMM, OPC_JAL, OPC_JALR, OPC_LUI, OPC_AUIPC:
        legal_lut = 1'b1;
      OPC_LOAD:   legal_lut = (f3 == F3_LW);
      OPC_STORE:  legal_lut = (f3 == F3_SW);
      OPC_BRANCH: legal_lut = (f3 == F3_BEQ) || (f3 == F3_BNE) ||
                              (f3 == F3_BLT) || (f3 == F3_BGE);
      default:    legal_lut = 1'b0;
    endcase
  endfunction

  function automatic word_t imm_lut(input logic [2:0] sel, input instr_t insn);
    unique case (sel)
      IMM_I:     imm_lut = sign_extend(insn[31:20]);
      IMM_S:     imm_lut = {{20{insn[31]}}, insn[31:25], insn[11:7]};
      IMM_B:     imm_lut = imm_align4({{19{insn[31]}}, insn[31], insn[7],
                                       insn[30:25], insn[11:8], 1'b0});
      IMM_J:     imm_lut = imm_align4({{11{insn[31]}}, insn[31], insn[19:12],
                                       insn[20], insn[30:21], 1'b0});
      IMM_U:     imm_lut = {insn[31:12], 12'b0};
      IMM_JALR:  imm_lut = imm_align4(sign_extend(insn[31:20]));
      IMM_OPIMM: imm_lut = sign_extend(insn[31:20]);
      default:   imm_lut = 32'd0;  // IMM_R0
    endcase
  endfunction

  opcode_t    opc_raw;
  funct3_t    f3_raw;
  gm_opc_row_t row;

  assign opc_raw = instr[6:0];
  assign f3_raw  = instr[14:12];
  assign row     = opc_lut(opc_raw);

  assign opcode = opc_raw;
  assign funct3 = (opc_raw == OPC_LUI || opc_raw == OPC_AUIPC || opc_raw == OPC_JAL)
                  ? 3'd0 : f3_raw;

  always_comb begin
    unique case (opc_raw)
      OPC_OP: funct7 = instr[31:25];
      OPC_OP_IMM: begin
        if (f3_raw == F3_SLL || f3_raw == F3_SRL_SRA)
          funct7 = instr[31:25];
        else
          funct7 = 7'd0;
      end
      default: funct7 = 7'd0;
    endcase
  end

  assign rd  = (opc_raw == OPC_STORE || opc_raw == OPC_BRANCH) ? 5'd0 : instr[11:7];
  assign rs1 = (opc_raw == OPC_LUI || opc_raw == OPC_AUIPC || opc_raw == OPC_JAL)
               ? 5'd0 : instr[19:15];
  assign rs2 = row.rs2_use ? instr[24:20] : 5'd0;
  assign imm = imm_lut(row.imm_sel, instr);

  assign lane_sel  = row.lane_sel;
  assign valid     = legal_lut(opc_raw, f3_raw);
  assign brch_en   = valid && row.brch_en;
  assign jump_en   = valid && row.jump_en;
  assign rs1_use   = row.rs1_use;
  assign rs2_use   = row.rs2_use;
  assign reg_write = (rd == 5'd0) ? 1'b0 :
                     (opc_raw == OPC_LOAD) ? (valid && row.reg_write_base) :
                     row.reg_write_base;

endmodule
