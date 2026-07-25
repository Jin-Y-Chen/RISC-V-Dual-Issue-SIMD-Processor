#pragma once
#include "common/types.hpp"
#include <array>

namespace target_buffer_gm {

constexpr int kCap = 64;

struct Stim {
  bool   i0_valid_wb = false, i1_valid_wb = false;
  word_t i0_pc = 0, i1_pc = 0;
  word_t i0_pc_wb = 0, i1_pc_wb = 0;
  word_t i0_pc_target_wb = 0, i1_pc_target_wb = 0;
};

struct Obs {
  bool   i0_valid = false, i1_valid = false;
  word_t i0_pc_target = 0, i1_pc_target = 0;
};

class TargetBufferGolden {
 public:
  void reset();
  Obs  eval(const Stim& s) const;
  void apply_negedge(const Stim& s);

 private:
  struct Row {
    bool   valid = false;
    word_t pc = 0;
    word_t target = 0;
  };
  void put(word_t pc, word_t tgt);
  bool get(word_t pc, word_t& tgt) const;

  std::array<Row, kCap> rows_{};
  int n_rows_ = 0;
};

}  // namespace target_buffer_gm

extern "C" {
void* btb_dpi_create();
void  btb_dpi_destroy(void* h);
void  btb_dpi_reset(void* h);
void  btb_dpi_eval(void* h, int i0_pc, int i1_pc, int i0_valid_wb, int i1_valid_wb,
                   int i0_pc_wb, int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb,
                   int* i0_valid, int* i1_valid, int* i0_tgt, int* i1_tgt);
void  btb_dpi_commit(void* h, int i0_valid_wb, int i1_valid_wb, int i0_pc_wb,
                     int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb);
}
