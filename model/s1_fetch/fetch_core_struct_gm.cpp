#include "fetch_core_struct_gm.hpp"
#include <new>

namespace fetch_core_gm {

FetchCoreGolden::FetchCoreGolden(word_t reset_pc) : pc_(reset_pc) { reset(); }

void FetchCoreGolden::reset() {
  pc_.reset();
  btb_.reset();
}

Obs FetchCoreGolden::eval(const Stim& s) {
  Obs o{};
  auto pc_o = pc_.eval();
  o.pc0 = pc_o.pc0_out;
  o.pc1 = pc_o.pc1_out;

  target_buffer_gm::Stim btb_s;
  btb_s.i0_pc = o.pc0;
  btb_s.i1_pc = o.pc1;
  btb_s.i0_valid_wb = s.i0_valid_wb;
  btb_s.i1_valid_wb = s.i1_valid_wb;
  btb_s.i0_pc_wb = s.i0_pc_wb;
  btb_s.i1_pc_wb = s.i1_pc_wb;
  btb_s.i0_pc_target_wb = s.i0_pc_target_wb;
  btb_s.i1_pc_target_wb = s.i1_pc_target_wb;
  auto btb_o = btb_.eval(btb_s);
  o.i0_pc_target = btb_o.i0_pc_target;
  o.i1_pc_target = btb_o.i1_pc_target;
  o.i0_target_valid = s.rst_n && btb_o.i0_valid;
  o.i1_target_valid = s.rst_n && btb_o.i1_valid;

  pc_selector_gm::Stim sel;
  sel.spec0_in = pc_o.spec0_out;
  sel.spec1_in = pc_o.spec1_out;
  sel.i0_pred_taken = s.i0_pred_taken;
  sel.i1_pred_taken = s.i1_pred_taken;
  sel.i0_brch_recover = s.i0_brch_recover;
  sel.i1_brch_recover = s.i1_brch_recover;
  sel.pc0_in = o.pc0;
  sel.pc1_in = o.pc1;
  // Same contract as RTL: steer with decode predict target (pc_target_wb), not BTB lookup
  sel.i0_pc_target = s.i0_pc_target_wb;
  sel.i1_pc_target = s.i1_pc_target_wb;
  sel.i0_pc_execute = s.i0_pc_execute;
  sel.i1_pc_execute = s.i1_pc_execute;
  auto sel_o = pc_selector_gm::eval(sel);
  o.spec0_en = sel_o.spec0_out;
  o.spec1_en = sel_o.spec1_out;

  auto ic = icache_gm::eval(o.pc0, o.pc1);
  o.instr0 = s.rst_n ? ic.instr0 : 0;
  o.instr1 = s.rst_n ? ic.instr1 : 0;
  o.i0_valid = s.rst_n && ic.i0_valid;
  o.i1_valid = s.rst_n && ic.i1_valid;
  return o;
}

void FetchCoreGolden::apply_posedge(const Stim& s) {
  pc_selector_gm::Stim sel;
  auto pc_o = pc_.eval();
  sel.spec0_in = pc_o.spec0_out;
  sel.spec1_in = pc_o.spec1_out;
  sel.i0_pred_taken = s.i0_pred_taken;
  sel.i1_pred_taken = s.i1_pred_taken;
  sel.i0_brch_recover = s.i0_brch_recover;
  sel.i1_brch_recover = s.i1_brch_recover;
  sel.pc0_in = pc_o.pc0_out;
  sel.pc1_in = pc_o.pc1_out;
  sel.i0_pc_target = s.i0_pc_target_wb;
  sel.i1_pc_target = s.i1_pc_target_wb;
  sel.i0_pc_execute = s.i0_pc_execute;
  sel.i1_pc_execute = s.i1_pc_execute;
  auto sel_o = pc_selector_gm::eval(sel);

  pc_gm::Stim ps;
  ps.rst_n = s.rst_n;
  ps.enable = s.enable;
  ps.dispatch_stall = s.dispatch_stall;
  ps.spec0_stall = s.spec0_stall;
  ps.spec1_stall = s.spec1_stall;
  ps.spec0_in = sel_o.spec0_out;
  ps.spec1_in = sel_o.spec1_out;
  ps.pc0_in = sel_o.pc0_out;
  ps.pc1_in = sel_o.pc1_out;
  pc_.apply_posedge(ps);
}

void FetchCoreGolden::apply_negedge(const Stim& s) {
  if (!s.rst_n) {
    btb_.reset();
    return;
  }
  target_buffer_gm::Stim btb_s;
  btb_s.i0_valid_wb = s.i0_valid_wb;
  btb_s.i1_valid_wb = s.i1_valid_wb;
  btb_s.i0_pc_wb = s.i0_pc_wb;
  btb_s.i1_pc_wb = s.i1_pc_wb;
  btb_s.i0_pc_target_wb = s.i0_pc_target_wb;
  btb_s.i1_pc_target_wb = s.i1_pc_target_wb;
  btb_.apply_negedge(btb_s);
}

}  // namespace fetch_core_gm

namespace {
fetch_core_gm::Stim make_fetch_stim(
    int rst_n, int enable, int dispatch_stall, int spec0_stall, int spec1_stall,
    int i0_pred_taken, int i1_pred_taken, int i0_brch_recover, int i1_brch_recover,
    int i0_pc_execute, int i1_pc_execute, int i0_valid_wb, int i1_valid_wb,
    int i0_pc_wb, int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb) {
  fetch_core_gm::Stim s;
  s.rst_n = rst_n; s.enable = enable; s.dispatch_stall = dispatch_stall;
  s.spec0_stall = spec0_stall; s.spec1_stall = spec1_stall;
  s.i0_pred_taken = i0_pred_taken; s.i1_pred_taken = i1_pred_taken;
  s.i0_brch_recover = i0_brch_recover; s.i1_brch_recover = i1_brch_recover;
  s.i0_pc_execute = static_cast<uint32_t>(i0_pc_execute);
  s.i1_pc_execute = static_cast<uint32_t>(i1_pc_execute);
  s.i0_valid_wb = i0_valid_wb; s.i1_valid_wb = i1_valid_wb;
  s.i0_pc_wb = static_cast<uint32_t>(i0_pc_wb);
  s.i1_pc_wb = static_cast<uint32_t>(i1_pc_wb);
  s.i0_pc_target_wb = static_cast<uint32_t>(i0_tgt_wb);
  s.i1_pc_target_wb = static_cast<uint32_t>(i1_tgt_wb);
  return s;
}
}  // namespace

extern "C" {

void* fetch_dpi_create(int reset_pc) {
  return new (std::nothrow) fetch_core_gm::FetchCoreGolden(static_cast<uint32_t>(reset_pc));
}
void fetch_dpi_destroy(void* h) {
  delete static_cast<fetch_core_gm::FetchCoreGolden*>(h);
}
void fetch_dpi_reset(void* h) {
  if (h) static_cast<fetch_core_gm::FetchCoreGolden*>(h)->reset();
}
void fetch_dpi_eval(
    void* h, int rst_n, int enable, int dispatch_stall, int spec0_stall, int spec1_stall,
    int i0_pred_taken, int i1_pred_taken, int i0_brch_recover, int i1_brch_recover,
    int i0_pc_execute, int i1_pc_execute, int i0_valid_wb, int i1_valid_wb,
    int i0_pc_wb, int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb,
    int* pc0, int* pc1, int* i0_tgt, int* i1_tgt, int* instr0, int* instr1,
    int* spec0, int* spec1, int* i0_valid, int* i1_valid, int* i0_tv, int* i1_tv) {
  auto* g = static_cast<fetch_core_gm::FetchCoreGolden*>(h);
  if (!g) return;
  auto s = make_fetch_stim(rst_n, enable, dispatch_stall, spec0_stall, spec1_stall,
                           i0_pred_taken, i1_pred_taken, i0_brch_recover, i1_brch_recover,
                           i0_pc_execute, i1_pc_execute, i0_valid_wb, i1_valid_wb,
                           i0_pc_wb, i1_pc_wb, i0_tgt_wb, i1_tgt_wb);
  auto o = g->eval(s);
  *pc0 = static_cast<int>(o.pc0); *pc1 = static_cast<int>(o.pc1);
  *i0_tgt = static_cast<int>(o.i0_pc_target); *i1_tgt = static_cast<int>(o.i1_pc_target);
  *instr0 = static_cast<int>(o.instr0); *instr1 = static_cast<int>(o.instr1);
  *spec0 = o.spec0_en; *spec1 = o.spec1_en;
  *i0_valid = o.i0_valid; *i1_valid = o.i1_valid;
  *i0_tv = o.i0_target_valid; *i1_tv = o.i1_target_valid;
}
void fetch_dpi_commit_posedge(
    void* h, int rst_n, int enable, int dispatch_stall, int spec0_stall, int spec1_stall,
    int i0_pred_taken, int i1_pred_taken, int i0_brch_recover, int i1_brch_recover,
    int i0_pc_execute, int i1_pc_execute, int i0_valid_wb, int i1_valid_wb,
    int i0_pc_wb, int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb) {
  auto* g = static_cast<fetch_core_gm::FetchCoreGolden*>(h);
  if (!g) return;
  g->apply_posedge(make_fetch_stim(
      rst_n, enable, dispatch_stall, spec0_stall, spec1_stall, i0_pred_taken, i1_pred_taken,
      i0_brch_recover, i1_brch_recover, i0_pc_execute, i1_pc_execute, i0_valid_wb, i1_valid_wb,
      i0_pc_wb, i1_pc_wb, i0_tgt_wb, i1_tgt_wb));
}
void fetch_dpi_commit_negedge(void* h, int i0_valid_wb, int i1_valid_wb, int i0_pc_wb,
                              int i1_pc_wb, int i0_tgt_wb, int i1_tgt_wb) {
  auto* g = static_cast<fetch_core_gm::FetchCoreGolden*>(h);
  if (!g) return;
  fetch_core_gm::Stim s;
  s.rst_n = true;
  s.i0_valid_wb = i0_valid_wb; s.i1_valid_wb = i1_valid_wb;
  s.i0_pc_wb = static_cast<uint32_t>(i0_pc_wb);
  s.i1_pc_wb = static_cast<uint32_t>(i1_pc_wb);
  s.i0_pc_target_wb = static_cast<uint32_t>(i0_tgt_wb);
  s.i1_pc_target_wb = static_cast<uint32_t>(i1_tgt_wb);
  g->apply_negedge(s);
}

}
