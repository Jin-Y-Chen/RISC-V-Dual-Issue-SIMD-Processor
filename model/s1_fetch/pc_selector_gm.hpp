#pragma once
#include "common/types.hpp"

namespace pc_selector_gm {

struct Stim {
  bool    spec0_in = false, spec1_in = false;
  bool    i0_pred_taken = false, i1_pred_taken = false;
  bool    i0_brch_recover = false, i1_brch_recover = false;
  word_t  pc0_in = 0, pc1_in = 0;
  word_t  i0_pc_target = 0, i1_pc_target = 0;
  word_t  i0_pc_execute = 0, i1_pc_execute = 0;
};

struct Obs {
  bool   spec0_out = false, spec1_out = false;
  word_t pc0_out = 0, pc1_out = 0;
};

Obs eval(const Stim& s);

}  // namespace pc_selector_gm

extern "C" {
void pc_sel_dpi_eval(
    int spec0_in, int spec1_in, int i0_pred_taken, int i1_pred_taken,
    int i0_brch_recover, int i1_brch_recover,
    int pc0_in, int pc1_in, int i0_pc_target, int i1_pc_target,
    int i0_pc_execute, int i1_pc_execute,
    int* spec0_out, int* spec1_out, int* pc0_out, int* pc1_out);
}
