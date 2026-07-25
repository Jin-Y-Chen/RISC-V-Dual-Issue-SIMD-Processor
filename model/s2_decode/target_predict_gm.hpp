#pragma once
#include "common/types.hpp"

namespace target_predict_gm {

struct Stim {
  bool    target_valid = false, brnch_en = false, jump_en = false, spec_n = false;
  word_t  pc = 0, imm = 0, pc_target = 0;
  uint8_t target_state = 0;
};

struct Obs {
  word_t pc_predict = 0;
  bool   pred_taken = false, pred_valid_wb = false, nest_spec_stall = false;
};

Obs eval(const Stim& s);

}  // namespace target_predict_gm

extern "C" {
void tpred_dpi_eval(int target_valid, int brnch_en, int jump_en, int spec_n, int pc,
                    int target_state, int imm, int pc_target, int* pc_predict,
                    int* pred_taken, int* pred_valid_wb, int* nest_spec_stall);
}
