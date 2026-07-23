#pragma once

#include <cstdint>

namespace rv_gm {

using word_t  = uint32_t;
using instr_t = uint32_t;

inline word_t align4(word_t addr) { return addr & ~word_t{3}; }

inline word_t sign_extend12(uint32_t imm12) {
  return static_cast<word_t>(
      (imm12 & 0x800u) ? (imm12 | 0xFFFFF000u) : (imm12 & 0xFFFu));
}

constexpr word_t kInstrNop   = 0x00000013u;
constexpr word_t kResetPc    = 0x00000000u;
constexpr int    kNumGpr     = 32;
constexpr int    kPcIndexAw  = 13;  // clog2(I_SIZE / 4)

}  // namespace rv_gm

using rv_gm::word_t;
using rv_gm::instr_t;
