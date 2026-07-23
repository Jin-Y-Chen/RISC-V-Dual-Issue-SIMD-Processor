#pragma once
#include "common/types.hpp"
#include "common/cache_index.hpp"
#include <vector>

namespace state_buffer_gm {

constexpr int kIndexW = rv_gm::kPcIndexAw;  // 13
constexpr int kWays   = 16;
constexpr int kWayAw  = 4;
constexpr int kSetAw  = kIndexW - kWayAw;  // 9
constexpr int kSets   = 1 << kSetAw;
constexpr int kDataW  = 2;
constexpr uint8_t kDefaultState = 0x2;

struct Stim {
  word_t  i0_pc = 0, i1_pc = 0;
  bool    i0_brch_en = false, i1_brch_en = false;
  bool    i0_valid_wb = false, i1_valid_wb = false;
  word_t  i0_brch_pc_wb = 0, i1_brch_pc_wb = 0;
  uint8_t i0_brch_state_wb = 0, i1_brch_state_wb = 0;
};

struct Obs {
  uint8_t i0_brch_state = kDefaultState;
  uint8_t i1_brch_state = kDefaultState;
};

class StateBufferGolden {
 public:
  StateBufferGolden();
  void reset();
  Obs  eval(const Stim& s) const;
  void apply_negedge(const Stim& s);

 private:
  std::vector<uint64_t> bank_;  // sets * ways
  uint64_t& at(int set, int way) { return bank_[set * kWays + way]; }
  const uint64_t& at(int set, int way) const { return bank_[set * kWays + way]; }
};

}  // namespace state_buffer_gm

extern "C" {
void* sbuf_dpi_create();
void  sbuf_dpi_destroy(void* h);
void  sbuf_dpi_reset(void* h);
void  sbuf_dpi_eval(void* h, int i0_pc, int i1_pc, int i0_brch_en, int i1_brch_en,
                    int i0_valid_wb, int i1_valid_wb, int i0_pc_wb, int i1_pc_wb,
                    int i0_st_wb, int i1_st_wb, int* i0_st, int* i1_st);
void  sbuf_dpi_commit(void* h, int i0_valid_wb, int i1_valid_wb, int i0_pc_wb,
                      int i1_pc_wb, int i0_st_wb, int i1_st_wb);
}
