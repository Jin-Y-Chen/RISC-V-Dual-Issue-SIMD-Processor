#pragma once
#include "common/types.hpp"

namespace icache_gm {

struct Obs {
  instr_t instr0 = 0, instr1 = 0;
  bool    i0_valid = false, i1_valid = false;
};

Obs eval(word_t pc0, word_t pc1);

}  // namespace icache_gm

extern "C" {
void icache_dpi_eval(int pc0, int pc1, int* instr0, int* instr1, int* v0, int* v1);
}
