#include "if_id_gm.hpp"
#include <new>

namespace if_id_gm {

void IfIdGolden::reset() { out_ = Obs{}; }

void IfIdGolden::apply_posedge(const Stim& s) {
  if (!s.rst_n || s.flush) {
    reset();
    return;
  }
  if (!(s.enable && !s.stall)) return;
  out_.i0_instr_id = s.i0_instr_if;
  out_.i0_pc_id = s.i0_pc_if;
  out_.i0_pc_target_id = s.i0_pc_target_if;
  out_.i0_fetch_valid_id = s.i0_fetch_valid_if;
  out_.i0_target_valid_id = s.i0_target_valid_if;
  out_.spec0_en_id = s.spec0_en_if;
  out_.i1_instr_id = s.i1_instr_if;
  out_.i1_pc_id = s.i1_pc_if;
  out_.i1_pc_target_id = s.i1_pc_target_if;
  out_.i1_fetch_valid_id = s.i1_fetch_valid_if;
  out_.i1_target_valid_id = s.i1_target_valid_if;
  out_.spec1_en_id = s.spec1_en_if;
}

}  // namespace if_id_gm

extern "C" {

void* ifid_dpi_create() { return new (std::nothrow) if_id_gm::IfIdGolden(); }
void ifid_dpi_destroy(void* h) { delete static_cast<if_id_gm::IfIdGolden*>(h); }
void ifid_dpi_reset(void* h) {
  if (h) static_cast<if_id_gm::IfIdGolden*>(h)->reset();
}
void ifid_dpi_eval(void* h, int* i0_instr, int* i1_instr, int* i0_pc, int* i1_pc,
                   int* i0_tgt, int* i1_tgt, int* i0_fv, int* i1_fv, int* i0_tv,
                   int* i1_tv, int* s0, int* s1) {
  auto* g = static_cast<if_id_gm::IfIdGolden*>(h);
  if (!g) return;
  auto o = g->eval();
  *i0_instr = static_cast<int>(o.i0_instr_id);
  *i1_instr = static_cast<int>(o.i1_instr_id);
  *i0_pc = static_cast<int>(o.i0_pc_id);
  *i1_pc = static_cast<int>(o.i1_pc_id);
  *i0_tgt = static_cast<int>(o.i0_pc_target_id);
  *i1_tgt = static_cast<int>(o.i1_pc_target_id);
  *i0_fv = o.i0_fetch_valid_id; *i1_fv = o.i1_fetch_valid_id;
  *i0_tv = o.i0_target_valid_id; *i1_tv = o.i1_target_valid_id;
  *s0 = o.spec0_en_id; *s1 = o.spec1_en_id;
}
void ifid_dpi_commit(void* h, int rst_n, int enable, int flush, int stall, int i0_fv,
                     int i1_fv, int i0_tv, int i1_tv, int s0, int s1, int i0_instr,
                     int i1_instr, int i0_pc, int i1_pc, int i0_tgt, int i1_tgt) {
  auto* g = static_cast<if_id_gm::IfIdGolden*>(h);
  if (!g) return;
  if_id_gm::Stim s;
  s.rst_n = rst_n; s.enable = enable; s.flush = flush; s.stall = stall;
  s.i0_fetch_valid_if = i0_fv; s.i1_fetch_valid_if = i1_fv;
  s.i0_target_valid_if = i0_tv; s.i1_target_valid_if = i1_tv;
  s.spec0_en_if = s0; s.spec1_en_if = s1;
  s.i0_instr_if = static_cast<uint32_t>(i0_instr);
  s.i1_instr_if = static_cast<uint32_t>(i1_instr);
  s.i0_pc_if = static_cast<uint32_t>(i0_pc);
  s.i1_pc_if = static_cast<uint32_t>(i1_pc);
  s.i0_pc_target_if = static_cast<uint32_t>(i0_tgt);
  s.i1_pc_target_if = static_cast<uint32_t>(i1_tgt);
  g->apply_posedge(s);
}

}
