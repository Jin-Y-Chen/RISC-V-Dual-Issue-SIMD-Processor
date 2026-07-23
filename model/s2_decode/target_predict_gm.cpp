#include "target_predict_gm.hpp"
#include "common/types.hpp"

namespace target_predict_gm {

Obs eval(const Stim& s) {
  Obs r{};
  const word_t decode_target = rv_gm::align4(s.pc + s.imm);
  const bool control_flow = s.brnch_en;
  const bool nested = s.spec_n && control_flow;
  const bool active = control_flow && !nested;
  const bool btb_miss = !s.target_valid;
  const bool btb_stale = s.target_valid && (decode_target != s.pc_target);

  r.pc_predict = s.pc;
  r.pred_taken = false;
  r.pred_valid_wb = false;
  r.nest_spec_stall = nested;

  if (active) {
    r.pred_taken = s.jump_en || ((s.target_state >> 1) & 1);
    if (btb_miss || btb_stale) {
      r.pc_predict = decode_target;
      r.pred_valid_wb = true;
    } else {
      r.pc_predict = s.pc_target;
      r.pred_valid_wb = false;
    }
  }
  return r;
}

}  // namespace target_predict_gm

extern "C" void tpred_dpi_eval(int target_valid, int brnch_en, int jump_en, int spec_n,
                               int pc, int target_state, int imm, int pc_target,
                               int* pc_predict, int* pred_taken, int* pred_valid_wb,
                               int* nest_spec_stall) {
  target_predict_gm::Stim s;
  s.target_valid = target_valid; s.brnch_en = brnch_en; s.jump_en = jump_en;
  s.spec_n = spec_n; s.pc = static_cast<uint32_t>(pc);
  s.target_state = static_cast<uint8_t>(target_state & 3);
  s.imm = static_cast<uint32_t>(imm);
  s.pc_target = static_cast<uint32_t>(pc_target);
  auto o = target_predict_gm::eval(s);
  *pc_predict = static_cast<int>(o.pc_predict);
  *pred_taken = o.pred_taken;
  *pred_valid_wb = o.pred_valid_wb;
  *nest_spec_stall = o.nest_spec_stall;
}
