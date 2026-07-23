#include "register_file_gm.hpp"
#include <new>

namespace register_file_gm {

void RegFileGolden::reset() { regs_.fill(0); }

word_t RegFileGolden::read_port(const Stim& s, bool use, uint8_t addr) const {
  if (!use) return 0;
  const word_t stored = (addr == 0) ? 0 : regs_[addr];
  const bool i0_wr = s.i0_valid_wb && s.i0_rd != 0;
  const bool i1_wr = s.i1_valid_wb && s.i1_rd != 0;
  const bool i0_byp = i0_wr && (s.i0_rd == addr);
  const bool i1_byp = i1_wr && (s.i1_rd == addr);
  if (i0_byp && i1_byp) return s.i1_data_wb;
  if (i1_byp) return s.i1_data_wb;
  if (i0_byp) return s.i0_data_wb;
  return stored;
}

Obs RegFileGolden::eval(const Stim& s) const {
  Obs o;
  o.i0_rs1_data = read_port(s, s.i0_rs1_use, s.i0_rs1);
  o.i0_rs2_data = read_port(s, s.i0_rs2_use, s.i0_rs2);
  o.i1_rs1_data = read_port(s, s.i1_rs1_use, s.i1_rs1);
  o.i1_rs2_data = read_port(s, s.i1_rs2_use, s.i1_rs2);
  return o;
}

void RegFileGolden::apply_negedge(const Stim& s) {
  const bool i0_wr = s.i0_valid_wb && s.i0_rd != 0;
  const bool i1_wr = s.i1_valid_wb && s.i1_rd != 0;
  const bool same = i0_wr && i1_wr && (s.i0_rd == s.i1_rd);
  if (i0_wr && !same) regs_[s.i0_rd] = s.i0_data_wb;
  if (i1_wr) regs_[s.i1_rd] = s.i1_data_wb;
}

}  // namespace register_file_gm

extern "C" {

void* rf_dpi_create() { return new (std::nothrow) register_file_gm::RegFileGolden(); }
void rf_dpi_destroy(void* h) { delete static_cast<register_file_gm::RegFileGolden*>(h); }
void rf_dpi_reset(void* h) {
  if (h) static_cast<register_file_gm::RegFileGolden*>(h)->reset();
}
void rf_dpi_eval(void* h, int i0_rs1_use, int i0_rs2_use, int i1_rs1_use, int i1_rs2_use,
                 int i0_valid_wb, int i1_valid_wb, int i0_rs1, int i0_rs2, int i1_rs1,
                 int i1_rs2, int i0_rd, int i1_rd, int i0_data, int i1_data, int* d00,
                 int* d01, int* d10, int* d11) {
  auto* g = static_cast<register_file_gm::RegFileGolden*>(h);
  if (!g) return;
  register_file_gm::Stim s;
  s.i0_rs1_use = i0_rs1_use; s.i0_rs2_use = i0_rs2_use;
  s.i1_rs1_use = i1_rs1_use; s.i1_rs2_use = i1_rs2_use;
  s.i0_valid_wb = i0_valid_wb; s.i1_valid_wb = i1_valid_wb;
  s.i0_rs1 = static_cast<uint8_t>(i0_rs1 & 31);
  s.i0_rs2 = static_cast<uint8_t>(i0_rs2 & 31);
  s.i1_rs1 = static_cast<uint8_t>(i1_rs1 & 31);
  s.i1_rs2 = static_cast<uint8_t>(i1_rs2 & 31);
  s.i0_rd = static_cast<uint8_t>(i0_rd & 31);
  s.i1_rd = static_cast<uint8_t>(i1_rd & 31);
  s.i0_data_wb = static_cast<uint32_t>(i0_data);
  s.i1_data_wb = static_cast<uint32_t>(i1_data);
  auto o = g->eval(s);
  *d00 = static_cast<int>(o.i0_rs1_data);
  *d01 = static_cast<int>(o.i0_rs2_data);
  *d10 = static_cast<int>(o.i1_rs1_data);
  *d11 = static_cast<int>(o.i1_rs2_data);
}
void rf_dpi_commit(void* h, int i0_valid_wb, int i1_valid_wb, int i0_rd, int i1_rd,
                   int i0_data, int i1_data) {
  auto* g = static_cast<register_file_gm::RegFileGolden*>(h);
  if (!g) return;
  register_file_gm::Stim s;
  s.i0_valid_wb = i0_valid_wb; s.i1_valid_wb = i1_valid_wb;
  s.i0_rd = static_cast<uint8_t>(i0_rd & 31);
  s.i1_rd = static_cast<uint8_t>(i1_rd & 31);
  s.i0_data_wb = static_cast<uint32_t>(i0_data);
  s.i1_data_wb = static_cast<uint32_t>(i1_data);
  g->apply_negedge(s);
}

}
