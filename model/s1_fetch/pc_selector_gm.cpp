#include "pc_selector_gm.hpp"
#include "common/types.hpp"

namespace pc_selector_gm {

Obs eval(const Stim& s) {
  using rv_gm::align4;
  Obs o{};
  const bool recover_any = s.i0_brch_recover || s.i1_brch_recover;
  o.spec0_out = (s.i0_pred_taken || s.spec0_in) && !recover_any;
  o.spec1_out = (s.i1_pred_taken || s.spec1_in) && !recover_any;
  o.pc0_out = align4(s.pc0_in);
  o.pc1_out = align4(s.pc1_in);
  if (s.i0_brch_recover) {
    o.pc0_out = align4(s.i0_pc_execute) + 4;
    o.pc1_out = align4(s.i0_pc_execute) + 8;
  } else if (s.i1_brch_recover) {
    o.pc0_out = align4(s.i1_pc_execute) + 4;
    o.pc1_out = align4(s.i1_pc_execute) + 8;
  } else if (s.i0_pred_taken && s.i1_pred_taken) {
    o.pc0_out = align4(s.i0_pc_target);
    o.pc1_out = align4(s.i0_pc_target) + 4;
  } else if (s.i0_pred_taken) {
    o.pc0_out = align4(s.i0_pc_target);
  } else if (s.i1_pred_taken) {
    o.pc1_out = align4(s.i1_pc_target);
  }
  return o;
}

}  // namespace pc_selector_gm

extern "C" void pc_sel_dpi_eval(
    int spec0_in, int spec1_in, int i0_pred_taken, int i1_pred_taken,
    int i0_brch_recover, int i1_brch_recover,
    int pc0_in, int pc1_in, int i0_pc_target, int i1_pc_target,
    int i0_pc_execute, int i1_pc_execute,
    int* spec0_out, int* spec1_out, int* pc0_out, int* pc1_out) {
  pc_selector_gm::Stim s;
  s.spec0_in = spec0_in; s.spec1_in = spec1_in;
  s.i0_pred_taken = i0_pred_taken; s.i1_pred_taken = i1_pred_taken;
  s.i0_brch_recover = i0_brch_recover; s.i1_brch_recover = i1_brch_recover;
  s.pc0_in = static_cast<uint32_t>(pc0_in);
  s.pc1_in = static_cast<uint32_t>(pc1_in);
  s.i0_pc_target = static_cast<uint32_t>(i0_pc_target);
  s.i1_pc_target = static_cast<uint32_t>(i1_pc_target);
  s.i0_pc_execute = static_cast<uint32_t>(i0_pc_execute);
  s.i1_pc_execute = static_cast<uint32_t>(i1_pc_execute);
  auto o = pc_selector_gm::eval(s);
  *spec0_out = o.spec0_out; *spec1_out = o.spec1_out;
  *pc0_out = static_cast<int>(o.pc0_out);
  *pc1_out = static_cast<int>(o.pc1_out);
}
