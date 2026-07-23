#pragma once
#include "common/types.hpp"

namespace if_id_gm {

struct Stim {
  bool    rst_n = true, enable = false, flush = false, stall = false;
  bool    i0_fetch_valid = false, i1_fetch_valid = false;
  bool    i0_target_valid_if = false, i1_target_valid_if = false;
  bool    spec0_en_if = false, spec1_en_if = false;
  instr_t i0_instr_if = 0, i1_instr_if = 0;
  word_t  i0_pc_if = 0, i1_pc_if = 0;
  word_t  i0_pc_target_if = 0, i1_pc_target_if = 0;
};

struct Obs {
  instr_t i0_instr_id = rv_gm::kInstrNop, i1_instr_id = rv_gm::kInstrNop;
  word_t  i0_pc_id = 0, i1_pc_id = 0;
  word_t  i0_pc_target_id = 0, i1_pc_target_id = 0;
  bool    i0_target_valid_id = false, i1_target_valid_id = false;
  bool    spec0_en_id = false, spec1_en_id = false;
};

class IfIdGolden {
 public:
  void reset();
  Obs  eval() const { return out_; }
  void apply_posedge(const Stim& s);

 private:
  Obs out_{};
};

}  // namespace if_id_gm

extern "C" {
void* ifid_dpi_create();
void  ifid_dpi_destroy(void* h);
void  ifid_dpi_reset(void* h);
void  ifid_dpi_eval(void* h, int* i0_instr, int* i1_instr, int* i0_pc, int* i1_pc,
                    int* i0_tgt, int* i1_tgt, int* i0_tv, int* i1_tv, int* s0, int* s1);
void  ifid_dpi_commit(void* h, int rst_n, int enable, int flush, int stall,
                      int i0_fv, int i1_fv, int i0_tv, int i1_tv, int s0, int s1,
                      int i0_instr, int i1_instr, int i0_pc, int i1_pc, int i0_tgt,
                      int i1_tgt);
}
