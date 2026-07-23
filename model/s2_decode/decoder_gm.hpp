#pragma once
#include "common/types.hpp"
#include "common/rv_isa.hpp"

namespace decoder_gm {

struct Obs {
  bool    lane_sel = false, brch_en = false, jump_en = false;
  uint8_t opcode = 0, funct3 = 0, funct7 = 0;
  uint8_t rd = 0, rs1 = 0, rs2 = 0;
  word_t  imm = 0;
  bool    valid = false, rs1_use = false, rs2_use = false;
  bool    store_en = false, reg_write = false;
};

Obs eval(instr_t instr);

}  // namespace decoder_gm

extern "C" {
void decoder_dpi_eval(
    int instr, int* lane_sel, int* brch_en, int* jump_en, int* opcode, int* funct3,
    int* funct7, int* rd, int* rs1, int* rs2, int* imm, int* valid, int* rs1_use,
    int* rs2_use, int* store_en, int* reg_write);
}
