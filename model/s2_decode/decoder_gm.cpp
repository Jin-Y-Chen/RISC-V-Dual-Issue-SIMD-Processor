#include "decoder_gm.hpp"

namespace decoder_gm {

static bool legal_reg_alu(uint8_t f3, uint8_t f7) {
  return f7 == 0x00 || (f7 == 0x20 && (f3 == rv_gm::kF3AddSub || f3 == rv_gm::kF3SrlSra));
}
static bool legal_imm_alu(uint8_t f3, uint8_t f7) {
  if (f3 == rv_gm::kF3Sll) return f7 == 0x00;
  if (f3 == rv_gm::kF3SrlSra) return f7 == 0x00 || f7 == 0x20;
  return true;
}
static bool legal_branch(uint8_t f3) {
  return f3 == rv_gm::kF3Beq || f3 == rv_gm::kF3Bne || f3 == rv_gm::kF3Blt ||
         f3 == rv_gm::kF3Bge;
}

Obs eval(instr_t insn) {
  using namespace rv_gm;
  Obs r{};
  const uint8_t opc = rv_gm::opc(insn);
  const uint8_t f3v = f3(insn);
  const uint8_t f7v = f7(insn);
  const uint8_t rdv = rd(insn);
  r.opcode = opc;
  r.funct3 = f3v;
  r.rd = rdv;
  r.rs1 = rs1(insn);
  r.imm = sign_extend12((insn >> 20) & 0xFFFu);

  if (opc == kOpcOp) {
    r.valid = legal_reg_alu(f3v, f7v);
    r.funct7 = f7v;
    r.rs1_use = r.rs2_use = true;
    r.rs2 = rs2(insn);
    r.imm = 0;
    r.reg_write = r.valid && rdv != 0;
  } else if (opc == kOpcOpImm) {
    r.valid = legal_imm_alu(f3v, f7v);
    r.rs1_use = true;
    r.imm = sign_extend12((insn >> 20) & 0xFFFu);
    if (f3v == kF3Sll || f3v == kF3SrlSra) r.funct7 = f7v;
    r.reg_write = r.valid && rdv != 0;
  } else if (opc == kOpcLoad) {
    r.valid = (f3v == kF3Lw);
    r.rs1_use = true;
    r.lane_sel = true;
    r.imm = sign_extend12((insn >> 20) & 0xFFFu);
    r.reg_write = r.valid && rdv != 0;
  } else if (opc == kOpcStore) {
    r.valid = (f3v == kF3Sw);
    r.rd = 0;
    r.rs1_use = r.rs2_use = true;
    r.rs2 = rs2(insn);
    r.lane_sel = true;
    r.store_en = r.valid;
    r.imm = static_cast<word_t>(
        (static_cast<int32_t>(insn) >> 20 & ~0x1F) | ((insn >> 7) & 0x1F));
    // S-imm: {insn[31:25], insn[11:7]} sign-extended
    const uint32_t simm = ((insn >> 25) << 5) | ((insn >> 7) & 0x1Fu);
    r.imm = static_cast<word_t>(
        (simm & 0x800u) ? (simm | 0xFFFFF000u) : simm);
  } else if (opc == kOpcBranch) {
    r.valid = legal_branch(f3v);
    r.rd = 0;
    r.rs1_use = r.rs2_use = true;
    r.rs2 = rs2(insn);
    r.lane_sel = true;
    r.brch_en = r.valid;
    // {19{insn[31]}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0}
    const uint32_t s = (insn >> 31) & 1u;
    r.imm = (s ? 0xFFF80000u : 0u) | (s << 12) | (((insn >> 7) & 1u) << 11) |
            (((insn >> 25) & 0x3Fu) << 5) | (((insn >> 8) & 0xFu) << 1);
  } else if (opc == kOpcJal) {
    r.valid = true;
    r.funct3 = 0;
    r.rs1 = 0;
    r.lane_sel = true;
    r.brch_en = r.jump_en = true;
    r.reg_write = rdv != 0;
    // {11{insn[31]}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0}
    const uint32_t s = (insn >> 31) & 1u;
    r.imm = (s ? 0xFFF00000u : 0u) | (s << 20) | (((insn >> 12) & 0xFFu) << 12) |
            (((insn >> 20) & 1u) << 11) | (((insn >> 21) & 0x3FFu) << 1);
  } else if (opc == kOpcJalr) {
    r.valid = (f3v == 0);
    r.rs1_use = true;
    r.lane_sel = true;
    r.brch_en = r.jump_en = r.valid;
    r.reg_write = r.valid && rdv != 0;
    r.imm = sign_extend12((insn >> 20) & 0xFFFu);
  } else if (opc == kOpcLui || opc == kOpcAuipc) {
    r.valid = true;
    r.funct3 = 0;
    r.rs1 = 0;
    r.lane_sel = true;
    r.reg_write = rdv != 0;
    r.imm = insn & 0xFFFFF000u;
  }
  return r;
}

}  // namespace decoder_gm

extern "C" void decoder_dpi_eval(
    int instr, int* lane_sel, int* brch_en, int* jump_en, int* opcode, int* funct3,
    int* funct7, int* rd, int* rs1, int* rs2, int* imm, int* valid, int* rs1_use,
    int* rs2_use, int* store_en, int* reg_write) {
  auto o = decoder_gm::eval(static_cast<uint32_t>(instr));
  *lane_sel = o.lane_sel; *brch_en = o.brch_en; *jump_en = o.jump_en;
  *opcode = o.opcode; *funct3 = o.funct3; *funct7 = o.funct7;
  *rd = o.rd; *rs1 = o.rs1; *rs2 = o.rs2;
  *imm = static_cast<int>(o.imm);
  *valid = o.valid; *rs1_use = o.rs1_use; *rs2_use = o.rs2_use;
  *store_en = o.store_en; *reg_write = o.reg_write;
}
