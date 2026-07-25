#pragma once
#include "common/types.hpp"
#include "pc_gm.hpp"
#include "pc_selector_gm.hpp"
#include "instruction_cache_gm.hpp"
#include "target_buffer_gm.hpp"

namespace fetch_core_gm {

struct Stim {
  bool   rst_n = true;
  bool   enable = false;
  bool   dispatch_stall = false;
  bool   spec0_stall = false, spec1_stall = false;
  bool   i0_pred_taken = false, i1_pred_taken = false;
  bool   i0_brch_recover = false, i1_brch_recover = false;
  word_t i0_pc_execute = 0, i1_pc_execute = 0;
  bool   i0_valid_wb = false, i1_valid_wb = false;
  word_t i0_pc_wb = 0, i1_pc_wb = 0;
  word_t i0_pc_target_wb = 0, i1_pc_target_wb = 0;
};

struct Obs {
  word_t  pc0 = 0, pc1 = 0;
  word_t  i0_pc_target = 0, i1_pc_target = 0;
  instr_t instr0 = 0, instr1 = 0;
  bool    spec0_en = false, spec1_en = false;
  bool    i0_valid = false, i1_valid = false;
  bool    i0_target_valid = false, i1_target_valid = false;
};

class FetchCoreGolden {
 public:
  explicit FetchCoreGolden(word_t reset_pc = rv_gm::kResetPc);
  void reset();
  Obs  eval(const Stim& s);
  void apply_posedge(const Stim& s);
  void apply_negedge(const Stim& s);

 private:
  pc_gm::PcGolden                 pc_;
  target_buffer_gm::TargetBufferGolden btb_;
};

}  // namespace fetch_core_gm

extern "C" {
void* fetch_dpi_create(int reset_pc);
void  fetch_dpi_destroy(void* h);
void  fetch_dpi_reset(void* h);
void  fetch_dpi_eval(
    void* h, int rst_n, int enable, int dispatch_stall, int spec0_stall, int spec1_stall,
    int i0_pred_taken, int i1_pred_taken, int i0_brch_recover, int i1_brch_recover,
    int i0_pc_execute, int i1_pc_execute, int i0_valid_wb, int i1_valid_wb,
    int i0_pc_wb, int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb,
    int* pc0, int* pc1, int* i0_tgt, int* i1_tgt, int* instr0, int* instr1,
    int* spec0, int* spec1, int* i0_valid, int* i1_valid, int* i0_tv, int* i1_tv);
void fetch_dpi_commit_posedge(
    void* h, int rst_n, int enable, int dispatch_stall, int spec0_stall, int spec1_stall,
    int i0_pred_taken, int i1_pred_taken, int i0_brch_recover, int i1_brch_recover,
    int i0_pc_execute, int i1_pc_execute, int i0_valid_wb, int i1_valid_wb,
    int i0_pc_wb, int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb);
void fetch_dpi_commit_negedge(void* h, int i0_valid_wb, int i1_valid_wb,
                              int i0_pc_wb, int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb);
}
