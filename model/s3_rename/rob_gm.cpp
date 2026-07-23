#include "rob_gm.hpp"

#include <new>

namespace rob_gm {

void RobGolden::reset() {
  q_.fill(Entry{});
  head_ = 0;
  tail_ = 0;
  active_spec_ = false;
}

void RobGolden::flush() { reset(); }

void RobGolden::writeback(const Stim& s) {
  auto do_wb = [&](bool en, uint8_t prf, bool br_taken) {
    if (!en) return;
    const uint8_t flat = flat_from_prf(prf);
    if (!q_[flat].valid) return;
    q_[flat].complete = true;
    q_[flat].br_taken = br_taken;
  };
  do_wb(s.wback0_en, s.i0_rob_idx_wb, s.i0_brch_taken_wb);
  do_wb(s.wback1_en, s.i1_rob_idx_wb, s.i1_brch_taken_wb);
}

void RobGolden::allocate(const Stim& s) {
  const uint8_t base = flat_of(tail_);
  const uint8_t a0   = base;
  const uint8_t a1   = static_cast<uint8_t>((base + (s.alloc0_en ? 1 : 0)) & 0x1F);

  auto fill = [&](uint8_t flat, bool reg_w, bool br, bool st, bool spec, uint8_t rd) {
    Entry e;
    e.valid     = true;
    e.complete  = false;
    e.reg_write = reg_w;
    e.is_branch = br;
    e.is_store  = st;
    e.spec_en   = spec;
    e.rd        = rd & 0x1F;
    e.br_taken  = false;
    q_[flat] = e;
  };

  if (s.alloc0_en) {
    fill(a0, s.i0_reg_write, s.i0_is_brnch, s.i0_is_store, s.i0_spec_en, s.i0_rd_addr);
  }
  if (s.alloc1_en) {
    fill(a1, s.i1_reg_write, s.i1_is_brnch, s.i1_is_store, s.i1_spec_en, s.i1_rd_addr);
  }

  const int n = (s.alloc0_en ? 1 : 0) + (s.alloc1_en ? 1 : 0);
  if (n != 0)
    tail_ = static_cast<uint8_t>((tail_ + n) & kPtrMask);
}

void RobGolden::retire_commit(const Stim& s, bool& cmt0, bool& cmt1,
                              uint8_t& head_n, bool& spec_n) const {
  const uint8_t h0 = flat_of(head_);
  const uint8_t h1 = static_cast<uint8_t>((h0 + 1) & 0x1F);

  const Entry& e0 = q_[h0];
  const Entry& e1 = q_[h1];

  const bool v0 = e0.valid;
  const bool v1 = e1.valid;

  const bool ready0 = v0 && e0.complete;
  const bool ready1 = ready0 && v1 && e1.complete;

  const bool on_path0 = !v0 || (e0.spec_en == active_spec_);
  const bool br0_ready = ready0 && on_path0 && e0.is_branch;
  const bool spec_after0 = br0_ready ? e0.br_taken : active_spec_;

  const bool on_path1 = !v1 || (e1.spec_en == spec_after0);
  const bool br1_ready = ready1 && on_path1 && e1.is_branch;
  const bool spec_after1 = br1_ready ? e1.br_taken : spec_after0;

  cmt0 = s.retire0_en && ready0 && on_path0;
  cmt1 = s.retire1_en && ready1 && on_path1;

  head_n = head_;
  spec_n = active_spec_;
  if (cmt1 && cmt0) {
    head_n = static_cast<uint8_t>((head_ + 2) & kPtrMask);
    spec_n = spec_after1;
  } else if (cmt0) {
    head_n = static_cast<uint8_t>((head_ + 1) & kPtrMask);
    spec_n = spec_after0;
  }
}

Obs RobGolden::eval(const Stim& s) const {
  Obs o{};
  const uint8_t base = flat_of(tail_);
  const uint8_t a0   = base;
  const uint8_t a1   = static_cast<uint8_t>((base + (s.alloc0_en ? 1 : 0)) & 0x1F);
  o.i0_rob_idx = prf_of(a0);
  o.i1_rob_idx = prf_of(a1);

  o.head        = head_;
  o.tail        = tail_;
  o.occ         = occ();
  o.active_spec = active_spec_;
  o.stall       = o.occ > (kDepth - 2);

  const uint8_t h0 = flat_of(head_);
  const uint8_t h1 = static_cast<uint8_t>((h0 + 1) & 0x1F);
  const Entry& e0 = q_[h0];
  const Entry& e1 = q_[h1];

  const bool v0 = e0.valid;
  const bool v1 = e1.valid;
  const bool ready0 = v0 && e0.complete;
  const bool ready1 = ready0 && v1 && e1.complete;

  const bool on_path0 = !v0 || (e0.spec_en == active_spec_);
  const bool br0_ready = ready0 && on_path0 && e0.is_branch;
  const bool spec_after0 = br0_ready ? e0.br_taken : active_spec_;
  const bool on_path1 = !v1 || (e1.spec_en == spec_after0);

  o.i0_can_retire = ready0;
  o.i1_can_retire = ready1;

  const bool cmt0 = s.retire0_en && ready0 && on_path0;
  const bool cmt1 = s.retire1_en && ready1 && on_path1;

  o.rrat0_en       = cmt0 && e0.reg_write;
  o.rrat1_en       = cmt1 && e1.reg_write;
  o.i0_rd_addr_cmt = cmt0 ? e0.rd : 0;
  o.i1_rd_addr_cmt = cmt1 ? e1.rd : 0;
  o.i0_rob_idx_cmt = prf_of(h0);
  o.i1_rob_idx_cmt = prf_of(h1);
  o.stb0_en        = cmt0 && e0.is_store;
  o.stb1_en        = cmt1 && e1.is_store;
  o.rat0_en        = cmt0 && e0.is_branch;
  o.rat1_en        = cmt1 && e1.is_branch;
  o.i0_path_sel    = cmt0 ? e0.br_taken : false;
  o.i1_path_sel    = cmt1 ? e1.br_taken : false;

  return o;
}

void RobGolden::apply_negedge(const Stim& s) {
  if (s.flush) {
    flush();
    return;
  }

  // Match DUT: combo cmt from registered state; WB must not affect same-cycle retire.
  bool cmt0 = false, cmt1 = false;
  uint8_t head_n = head_;
  bool spec_n = active_spec_;
  retire_commit(s, cmt0, cmt1, head_n, spec_n);

  const uint8_t h0 = flat_of(head_);
  const uint8_t h1 = static_cast<uint8_t>((h0 + 1) & 0x1F);

  writeback(s);

  if (cmt0) q_[h0].valid = false;
  if (cmt1) q_[h1].valid = false;

  allocate(s);

  head_ = head_n;
  active_spec_ = spec_n;
}

Obs RobGolden::cycle(const Stim& s) {
  Obs o = eval(s);
  apply_negedge(s);
  return o;
}

}  // namespace rob_gm

namespace {

rob_gm::Stim make_stim(
    int flush,
    int alloc0_en, int alloc1_en,
    int i0_reg_write, int i1_reg_write,
    int i0_is_brnch, int i1_is_brnch,
    int i0_is_store, int i1_is_store,
    int i0_spec_en, int i1_spec_en,
    int i0_rd_addr, int i1_rd_addr,
    int wback0_en, int wback1_en,
    int i0_rob_idx_wb, int i1_rob_idx_wb,
    int i0_brch_taken_wb, int i1_brch_taken_wb,
    int retire0_en, int retire1_en) {
  rob_gm::Stim s;
  s.flush            = flush != 0;
  s.alloc0_en        = alloc0_en != 0;
  s.alloc1_en        = alloc1_en != 0;
  s.i0_reg_write     = i0_reg_write != 0;
  s.i1_reg_write     = i1_reg_write != 0;
  s.i0_is_brnch      = i0_is_brnch != 0;
  s.i1_is_brnch      = i1_is_brnch != 0;
  s.i0_is_store      = i0_is_store != 0;
  s.i1_is_store      = i1_is_store != 0;
  s.i0_spec_en       = i0_spec_en != 0;
  s.i1_spec_en       = i1_spec_en != 0;
  s.i0_rd_addr       = static_cast<uint8_t>(i0_rd_addr & 0x1F);
  s.i1_rd_addr       = static_cast<uint8_t>(i1_rd_addr & 0x1F);
  s.wback0_en        = wback0_en != 0;
  s.wback1_en        = wback1_en != 0;
  s.i0_rob_idx_wb    = static_cast<uint8_t>(i0_rob_idx_wb & 0x3F);
  s.i1_rob_idx_wb    = static_cast<uint8_t>(i1_rob_idx_wb & 0x3F);
  s.i0_brch_taken_wb = i0_brch_taken_wb != 0;
  s.i1_brch_taken_wb = i1_brch_taken_wb != 0;
  s.retire0_en       = retire0_en != 0;
  s.retire1_en       = retire1_en != 0;
  return s;
}

void pack_obs(const rob_gm::Obs& o,
              int* i0_rob_idx, int* i1_rob_idx,
              int* stall,
              int* i0_can_retire, int* i1_can_retire,
              int* rrat0_en, int* rrat1_en,
              int* i0_rd_addr_cmt, int* i1_rd_addr_cmt,
              int* i0_rob_idx_cmt, int* i1_rob_idx_cmt,
              int* rat0_en, int* rat1_en,
              int* i0_path_sel, int* i1_path_sel,
              int* stb0_en, int* stb1_en,
              int* head, int* tail, int* occ, int* active_spec) {
  *i0_rob_idx     = o.i0_rob_idx;
  *i1_rob_idx     = o.i1_rob_idx;
  *stall          = o.stall;
  *i0_can_retire  = o.i0_can_retire;
  *i1_can_retire  = o.i1_can_retire;
  *rrat0_en       = o.rrat0_en;
  *rrat1_en       = o.rrat1_en;
  *i0_rd_addr_cmt = o.i0_rd_addr_cmt;
  *i1_rd_addr_cmt = o.i1_rd_addr_cmt;
  *i0_rob_idx_cmt = o.i0_rob_idx_cmt;
  *i1_rob_idx_cmt = o.i1_rob_idx_cmt;
  *rat0_en        = o.rat0_en;
  *rat1_en        = o.rat1_en;
  *i0_path_sel    = o.i0_path_sel;
  *i1_path_sel    = o.i1_path_sel;
  *stb0_en        = o.stb0_en;
  *stb1_en        = o.stb1_en;
  *head           = o.head;
  *tail           = o.tail;
  *occ            = o.occ;
  *active_spec    = o.active_spec;
}

}  // namespace

extern "C" {

void* rob_dpi_create() {
  return new (std::nothrow) rob_gm::RobGolden();
}

void rob_dpi_destroy(void* h) {
  delete static_cast<rob_gm::RobGolden*>(h);
}

void rob_dpi_reset(void* h) {
  if (h) static_cast<rob_gm::RobGolden*>(h)->reset();
}

void rob_dpi_eval(
    void* h,
    int flush,
    int alloc0_en, int alloc1_en,
    int i0_reg_write, int i1_reg_write,
    int i0_is_brnch, int i1_is_brnch,
    int i0_is_store, int i1_is_store,
    int i0_spec_en, int i1_spec_en,
    int i0_rd_addr, int i1_rd_addr,
    int wback0_en, int wback1_en,
    int i0_rob_idx_wb, int i1_rob_idx_wb,
    int i0_brch_taken_wb, int i1_brch_taken_wb,
    int retire0_en, int retire1_en,
    int* i0_rob_idx, int* i1_rob_idx,
    int* stall,
    int* i0_can_retire, int* i1_can_retire,
    int* rrat0_en, int* rrat1_en,
    int* i0_rd_addr_cmt, int* i1_rd_addr_cmt,
    int* i0_rob_idx_cmt, int* i1_rob_idx_cmt,
    int* rat0_en, int* rat1_en,
    int* i0_path_sel, int* i1_path_sel,
    int* stb0_en, int* stb1_en,
    int* head, int* tail, int* occ, int* active_spec) {
  auto* gm = static_cast<rob_gm::RobGolden*>(h);
  if (!gm) return;
  const rob_gm::Stim s = make_stim(
      flush, alloc0_en, alloc1_en, i0_reg_write, i1_reg_write,
      i0_is_brnch, i1_is_brnch, i0_is_store, i1_is_store,
      i0_spec_en, i1_spec_en, i0_rd_addr, i1_rd_addr,
      wback0_en, wback1_en, i0_rob_idx_wb, i1_rob_idx_wb,
      i0_brch_taken_wb, i1_brch_taken_wb, retire0_en, retire1_en);
  pack_obs(gm->eval(s),
           i0_rob_idx, i1_rob_idx, stall, i0_can_retire, i1_can_retire,
           rrat0_en, rrat1_en, i0_rd_addr_cmt, i1_rd_addr_cmt,
           i0_rob_idx_cmt, i1_rob_idx_cmt, rat0_en, rat1_en,
           i0_path_sel, i1_path_sel, stb0_en, stb1_en,
           head, tail, occ, active_spec);
}

void rob_dpi_commit(
    void* h,
    int flush,
    int alloc0_en, int alloc1_en,
    int i0_reg_write, int i1_reg_write,
    int i0_is_brnch, int i1_is_brnch,
    int i0_is_store, int i1_is_store,
    int i0_spec_en, int i1_spec_en,
    int i0_rd_addr, int i1_rd_addr,
    int wback0_en, int wback1_en,
    int i0_rob_idx_wb, int i1_rob_idx_wb,
    int i0_brch_taken_wb, int i1_brch_taken_wb,
    int retire0_en, int retire1_en) {
  auto* gm = static_cast<rob_gm::RobGolden*>(h);
  if (!gm) return;
  const rob_gm::Stim s = make_stim(
      flush, alloc0_en, alloc1_en, i0_reg_write, i1_reg_write,
      i0_is_brnch, i1_is_brnch, i0_is_store, i1_is_store,
      i0_spec_en, i1_spec_en, i0_rd_addr, i1_rd_addr,
      wback0_en, wback1_en, i0_rob_idx_wb, i1_rob_idx_wb,
      i0_brch_taken_wb, i1_brch_taken_wb, retire0_en, retire1_en);
  gm->apply_negedge(s);
}

}  // extern "C"
