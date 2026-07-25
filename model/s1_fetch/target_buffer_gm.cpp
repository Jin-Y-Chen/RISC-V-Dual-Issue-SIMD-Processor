#include "target_buffer_gm.hpp"
#include "common/types.hpp"
#include <new>

namespace target_buffer_gm {

void TargetBufferGolden::reset() {
  rows_.fill(Row{});
  n_rows_ = 0;
}

bool TargetBufferGolden::get(word_t pc, word_t& tgt) const {
  const word_t key = rv_gm::align4(pc);
  for (int i = 0; i < n_rows_; ++i) {
    if (rows_[i].valid && rows_[i].pc == key) {
      tgt = rows_[i].target;
      return true;
    }
  }
  tgt = 0;
  return false;
}

void TargetBufferGolden::put(word_t pc, word_t tgt) {
  const word_t key = rv_gm::align4(pc);
  const word_t val = rv_gm::align4(tgt);
  for (int i = 0; i < n_rows_; ++i) {
    if (rows_[i].valid && rows_[i].pc == key) {
      rows_[i].target = val;
      return;
    }
  }
  if (n_rows_ < kCap) {
    rows_[n_rows_].valid = true;
    rows_[n_rows_].pc = key;
    rows_[n_rows_].target = val;
    ++n_rows_;
  }
}

Obs TargetBufferGolden::eval(const Stim& s) const {
  Obs o{};
  auto port = [&](word_t pc, bool& hit, word_t& tgt) {
    const word_t key = rv_gm::align4(pc);
    if (s.i0_valid_wb && rv_gm::align4(s.i0_pc_wb) == key) {
      hit = true;
      tgt = rv_gm::align4(s.i0_pc_target_wb);
      return;
    }
    if (s.i1_valid_wb && rv_gm::align4(s.i1_pc_wb) == key) {
      hit = true;
      tgt = rv_gm::align4(s.i1_pc_target_wb);
      return;
    }
    hit = get(pc, tgt);
  };
  port(s.i0_pc, o.i0_valid, o.i0_pc_target);
  port(s.i1_pc, o.i1_valid, o.i1_pc_target);
  return o;
}

void TargetBufferGolden::apply_negedge(const Stim& s) {
  if (s.i0_valid_wb) put(s.i0_pc_wb, s.i0_pc_target_wb);
  if (s.i1_valid_wb) put(s.i1_pc_wb, s.i1_pc_target_wb);
}

}  // namespace target_buffer_gm

extern "C" {

void* btb_dpi_create() {
  return new (std::nothrow) target_buffer_gm::TargetBufferGolden();
}
void btb_dpi_destroy(void* h) {
  delete static_cast<target_buffer_gm::TargetBufferGolden*>(h);
}
void btb_dpi_reset(void* h) {
  if (h) static_cast<target_buffer_gm::TargetBufferGolden*>(h)->reset();
}
void btb_dpi_eval(void* h, int i0_pc, int i1_pc, int i0_valid_wb, int i1_valid_wb,
                  int i0_pc_wb, int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb,
                  int* i0_valid, int* i1_valid, int* i0_tgt, int* i1_tgt) {
  auto* g = static_cast<target_buffer_gm::TargetBufferGolden*>(h);
  if (!g) return;
  target_buffer_gm::Stim s;
  s.i0_pc = static_cast<uint32_t>(i0_pc);
  s.i1_pc = static_cast<uint32_t>(i1_pc);
  s.i0_valid_wb = i0_valid_wb; s.i1_valid_wb = i1_valid_wb;
  s.i0_pc_wb = static_cast<uint32_t>(i0_pc_wb);
  s.i1_pc_wb = static_cast<uint32_t>(i1_pc_wb);
  s.i0_pc_target_wb = static_cast<uint32_t>(i0_tgt_wb);
  s.i1_pc_target_wb = static_cast<uint32_t>(i1_tgt_wb);
  auto o = g->eval(s);
  *i0_valid = o.i0_valid; *i1_valid = o.i1_valid;
  *i0_tgt = static_cast<int>(o.i0_pc_target);
  *i1_tgt = static_cast<int>(o.i1_pc_target);
}
void btb_dpi_commit(void* h, int i0_valid_wb, int i1_valid_wb, int i0_pc_wb,
                    int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb) {
  auto* g = static_cast<target_buffer_gm::TargetBufferGolden*>(h);
  if (!g) return;
  target_buffer_gm::Stim s;
  s.i0_valid_wb = i0_valid_wb; s.i1_valid_wb = i1_valid_wb;
  s.i0_pc_wb = static_cast<uint32_t>(i0_pc_wb);
  s.i1_pc_wb = static_cast<uint32_t>(i1_pc_wb);
  s.i0_pc_target_wb = static_cast<uint32_t>(i0_tgt_wb);
  s.i1_pc_target_wb = static_cast<uint32_t>(i1_tgt_wb);
  g->apply_negedge(s);
}

}
