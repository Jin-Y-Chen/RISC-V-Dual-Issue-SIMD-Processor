#include "instruction_cache_gm.hpp"
#include "common/types.hpp"

namespace icache_gm {

constexpr word_t kDemoBase  = 0x00001000u;
constexpr int    kDemoCount = 72;

static const word_t kDemoWord[kDemoCount] = {
    0x00000537, 0x00A00293, 0x00000697, 0x01400313, 0x005283B3, 0x00752023,
    0x00A503B3, 0x00052483, 0x0094C633, 0x00752223, 0x0AA00593, 0x000005B7,
    0x05500593, 0x00000597, 0x01100593, 0x00052583, 0x06300593, 0x000005B7,
    0x00400713, 0x00072783, 0x00100813, 0x00000837, 0x00628033, 0x00652423,
    0x005003B3, 0x00852403, 0x006283B3, 0x00752623, 0x405303B3, 0x00C52403,
    0x006293B3, 0x00752823, 0x0062A3B3, 0x01052483, 0x0062C3B3, 0x00752A23,
    0x005353B3, 0x01452403, 0x405353B3, 0x00752C23, 0x0062E3B3, 0x01852483,
    0x0062F3B3, 0x00752E23, 0x00300293, 0x04028263, 0xFFF28293, 0xFE029EE3,
    0x00A00293, 0x00052403, 0x00500313, 0x00534663, 0x00000393, 0x02000263,
    0x00100393, 0x00500293, 0x00452483, 0x00A00313, 0x00535663, 0x00000413,
    0x00000463, 0x00200413, 0x00000293, 0x01C000EF, 0x06300493, 0x01400313,
    0x00652023, 0x006283B3, 0x00052403, 0x00000063, 0x02A00113, 0x00008067};

static int demo_idx(word_t pc) {
  const word_t key = rv_gm::align4(pc);
  if (key < kDemoBase) return -1;
  const int idx = static_cast<int>((key - kDemoBase) >> 2);
  if (idx < 0 || idx >= kDemoCount) return -1;
  return idx;
}

Obs eval(word_t pc0, word_t pc1) {
  Obs o{};
  int i0 = demo_idx(pc0), i1 = demo_idx(pc1);
  if (i0 >= 0) {
    o.instr0 = kDemoWord[i0];
    o.i0_valid = true;
  }
  if (i1 >= 0) {
    o.instr1 = kDemoWord[i1];
    o.i1_valid = true;
  }
  return o;
}

}  // namespace icache_gm

extern "C" void icache_dpi_eval(int pc0, int pc1, int* instr0, int* instr1,
                                int* v0, int* v1) {
  auto o = icache_gm::eval(static_cast<uint32_t>(pc0), static_cast<uint32_t>(pc1));
  *instr0 = static_cast<int>(o.instr0);
  *instr1 = static_cast<int>(o.instr1);
  *v0 = o.i0_valid;
  *v1 = o.i1_valid;
}
