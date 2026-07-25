#include "pc_gm.hpp"
#include <new>

namespace pc_gm {

PcGolden::PcGolden(word_t reset_pc) : reset_pc_(reset_pc) { reset(); }

void PcGolden::reset() {
  pc0_ = reset_pc_;
  pc1_ = reset_pc_ + 4;
  spec0_ = spec1_ = false;
}

Obs PcGolden::eval() const {
  Obs o;
  o.pc0_out = pc0_;
  o.pc1_out = pc1_;
  o.spec0_out = spec0_;
  o.spec1_out = spec1_;
  return o;
}

void PcGolden::apply_posedge(const Stim& s) {
  if (!s.rst_n) {
    reset();
    return;
  }
  const bool mode = s.spec0_in ^ s.spec1_in;
  const bool hold = !s.enable || s.dispatch_stall || s.spec0_stall || s.spec1_stall;
  if (hold) return;
  const word_t a0 = s.pc0_in & ~word_t{3};
  const word_t a1 = s.pc1_in & ~word_t{3};
  if (mode) {
    pc0_ = a0 + 4;
    pc1_ = a1 + 4;
  } else {
    pc0_ = a0 + 8;
    pc1_ = a1 + 8;
  }
  spec0_ = s.spec0_in;
  spec1_ = s.spec1_in;
}

}  // namespace pc_gm

extern "C" {

void* pc_dpi_create(int reset_pc) {
  return new (std::nothrow) pc_gm::PcGolden(static_cast<uint32_t>(reset_pc));
}
void pc_dpi_destroy(void* h) { delete static_cast<pc_gm::PcGolden*>(h); }
void pc_dpi_reset(void* h) {
  if (h) static_cast<pc_gm::PcGolden*>(h)->reset();
}
void pc_dpi_eval(void* h, int* pc0, int* pc1, int* spec0, int* spec1) {
  auto* g = static_cast<pc_gm::PcGolden*>(h);
  if (!g) return;
  auto o = g->eval();
  *pc0 = static_cast<int>(o.pc0_out);
  *pc1 = static_cast<int>(o.pc1_out);
  *spec0 = o.spec0_out;
  *spec1 = o.spec1_out;
}
void pc_dpi_commit(void* h, int rst_n, int enable, int dispatch_stall,
                   int spec0_stall, int spec1_stall, int spec0_in, int spec1_in,
                   int pc0_in, int pc1_in) {
  auto* g = static_cast<pc_gm::PcGolden*>(h);
  if (!g) return;
  pc_gm::Stim s;
  s.rst_n = rst_n; s.enable = enable; s.dispatch_stall = dispatch_stall;
  s.spec0_stall = spec0_stall; s.spec1_stall = spec1_stall;
  s.spec0_in = spec0_in; s.spec1_in = spec1_in;
  s.pc0_in = static_cast<uint32_t>(pc0_in);
  s.pc1_in = static_cast<uint32_t>(pc1_in);
  g->apply_posedge(s);
}

}
