#include "state_buffer_gm.hpp"
#include <algorithm>
#include <new>

namespace state_buffer_gm {

StateBufferGolden::StateBufferGolden() : bank_(kSets * kWays, 0) {}

void StateBufferGolden::reset() { std::fill(bank_.begin(), bank_.end(), 0); }

Obs StateBufferGolden::eval(const Stim& s) const {
  using rv_gm::pc_set;
  using rv_gm::pc_way;
  using rv_gm::cache_way_read;
  using rv_gm::cache_set_write;

  const int i0s = pc_set(s.i0_pc, kWayAw, kSetAw);
  const int i0w = pc_way(s.i0_pc, kWayAw);
  const int i1s = pc_set(s.i1_pc, kWayAw, kSetAw);
  const int i1w = pc_way(s.i1_pc, kWayAw);
  const int w0s = pc_set(s.i0_brch_pc_wb, kWayAw, kSetAw);
  const int w0w = pc_way(s.i0_brch_pc_wb, kWayAw);
  const int w1s = pc_set(s.i1_brch_pc_wb, kWayAw, kSetAw);
  const int w1w = pc_way(s.i1_brch_pc_wb, kWayAw);
  const uint64_t wb0 = cache_set_write(true, s.i0_brch_state_wb, kDataW);
  const uint64_t wb1 = cache_set_write(true, s.i1_brch_state_wb, kDataW);

  uint64_t e0 = at(i0s, i0w);
  if (s.i0_valid_wb && w0s == i0s && w0w == i0w) e0 = wb0;
  else if (s.i1_valid_wb && w1s == i0s && w1w == i0w) e0 = wb1;

  uint64_t e1 = at(i1s, i1w);
  if (s.i0_valid_wb && w0s == i1s && w0w == i1w) e1 = wb0;
  else if (s.i1_valid_wb && w1s == i1s && w1w == i1w) e1 = wb1;

  const word_t raw0 = cache_way_read(e0, kDefaultState, kDataW);
  const word_t raw1 = cache_way_read(e1, kDefaultState, kDataW);

  Obs o;
  o.i0_brch_state = s.i0_brch_en ? static_cast<uint8_t>(raw0 & 3) : kDefaultState;
  o.i1_brch_state = s.i1_brch_en ? static_cast<uint8_t>(raw1 & 3) : kDefaultState;
  return o;
}

void StateBufferGolden::apply_negedge(const Stim& s) {
  using rv_gm::pc_set;
  using rv_gm::pc_way;
  using rv_gm::cache_set_write;
  if (s.i0_valid_wb) {
    at(pc_set(s.i0_brch_pc_wb, kWayAw, kSetAw), pc_way(s.i0_brch_pc_wb, kWayAw)) =
        cache_set_write(true, s.i0_brch_state_wb, kDataW);
  }
  if (s.i1_valid_wb) {
    at(pc_set(s.i1_brch_pc_wb, kWayAw, kSetAw), pc_way(s.i1_brch_pc_wb, kWayAw)) =
        cache_set_write(true, s.i1_brch_state_wb, kDataW);
  }
}

}  // namespace state_buffer_gm

extern "C" {

void* sbuf_dpi_create() {
  return new (std::nothrow) state_buffer_gm::StateBufferGolden();
}
void sbuf_dpi_destroy(void* h) {
  delete static_cast<state_buffer_gm::StateBufferGolden*>(h);
}
void sbuf_dpi_reset(void* h) {
  if (h) static_cast<state_buffer_gm::StateBufferGolden*>(h)->reset();
}
void sbuf_dpi_eval(void* h, int i0_pc, int i1_pc, int i0_brch_en, int i1_brch_en,
                   int i0_valid_wb, int i1_valid_wb, int i0_pc_wb, int i1_pc_wb,
                   int i0_st_wb, int i1_st_wb, int* i0_st, int* i1_st) {
  auto* g = static_cast<state_buffer_gm::StateBufferGolden*>(h);
  if (!g) return;
  state_buffer_gm::Stim s;
  s.i0_pc = static_cast<uint32_t>(i0_pc);
  s.i1_pc = static_cast<uint32_t>(i1_pc);
  s.i0_brch_en = i0_brch_en; s.i1_brch_en = i1_brch_en;
  s.i0_valid_wb = i0_valid_wb; s.i1_valid_wb = i1_valid_wb;
  s.i0_brch_pc_wb = static_cast<uint32_t>(i0_pc_wb);
  s.i1_brch_pc_wb = static_cast<uint32_t>(i1_pc_wb);
  s.i0_brch_state_wb = static_cast<uint8_t>(i0_st_wb & 3);
  s.i1_brch_state_wb = static_cast<uint8_t>(i1_st_wb & 3);
  auto o = g->eval(s);
  *i0_st = o.i0_brch_state;
  *i1_st = o.i1_brch_state;
}
void sbuf_dpi_commit(void* h, int i0_valid_wb, int i1_valid_wb, int i0_pc_wb,
                     int i1_pc_wb, int i0_st_wb, int i1_st_wb) {
  auto* g = static_cast<state_buffer_gm::StateBufferGolden*>(h);
  if (!g) return;
  state_buffer_gm::Stim s;
  s.i0_valid_wb = i0_valid_wb; s.i1_valid_wb = i1_valid_wb;
  s.i0_brch_pc_wb = static_cast<uint32_t>(i0_pc_wb);
  s.i1_brch_pc_wb = static_cast<uint32_t>(i1_pc_wb);
  s.i0_brch_state_wb = static_cast<uint8_t>(i0_st_wb & 3);
  s.i1_brch_state_wb = static_cast<uint8_t>(i1_st_wb & 3);
  g->apply_negedge(s);
}

}
