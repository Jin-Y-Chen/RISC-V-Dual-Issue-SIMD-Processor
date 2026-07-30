#include "alias_table_gm.hpp"

#include <new>

namespace alias_gm {

void AliasGolden::reset() {
  for (int i = 0; i < kGpr; ++i) {
    rrat_[static_cast<size_t>(i)]    = static_cast<uint8_t>(i);
    map_br0_[static_cast<size_t>(i)] = static_cast<uint8_t>(i);
    map_br1_[static_cast<size_t>(i)] = static_cast<uint8_t>(i);
  }
  rrat_[0] = map_br0_[0] = map_br1_[0] = 0;
}

uint8_t AliasGolden::map_read(
    uint8_t gpr, bool spec_en,
    const std::array<uint8_t, kGpr>& map0,
    const std::array<uint8_t, kGpr>& map1) const {
  return spec_en ? map0[gpr] : map1[gpr];
}

uint8_t AliasGolden::src_lookup(
    bool use, uint8_t addr, bool spec_en,
    const std::array<uint8_t, kGpr>& map0,
    const std::array<uint8_t, kGpr>& map1) const {
  if (!use || is_x0(addr)) return 0;
  return map_read(addr, spec_en, map0, map1);
}

uint8_t AliasGolden::i1_src_lookup(
    bool use, uint8_t addr, const Stim& s,
    const std::array<uint8_t, kGpr>& map0,
    const std::array<uint8_t, kGpr>& map1) const {
  if (!use || is_x0(addr)) return 0;
  if (s.alloc_en[0] && !is_x0(s.alloc_rd[0]) &&
      (s.spec_en[0] == s.spec_en[1]) && (addr == s.alloc_rd[0]))
    return s.alloc_tag[0];
  return map_read(addr, s.spec_en[1], map0, map1);
}

Obs AliasGolden::eval(const Stim& s) const {
  Obs o;
  o.path_use[0] = s.spec_en[0];
  o.path_use[1] = s.spec_en[1];
  o.ps1[0] = src_lookup(s.rs1_use[0], s.rs1_addr[0], s.spec_en[0], map_br0_, map_br1_);
  o.ps2[0] = src_lookup(s.rs2_use[0], s.rs2_addr[0], s.spec_en[0], map_br0_, map_br1_);
  o.ps1[1] = i1_src_lookup(s.rs1_use[1], s.rs1_addr[1], s, map_br0_, map_br1_);
  o.ps2[1] = i1_src_lookup(s.rs2_use[1], s.rs2_addr[1], s, map_br0_, map_br1_);
  return o;
}

void AliasGolden::apply_negedge(const Stim& s) {
  if (s.flush) {
    map_br0_ = rrat_;
    map_br1_ = rrat_;
    return;
  }

  // NBA-equivalent: path/rrat/alloc all sample pre-update maps; apply path,
  // then RRAT, then alloc (alloc overrides path on the same entry).
  auto map0 = map_br0_;
  auto map1 = map_br1_;
  auto rrat = rrat_;

  if (s.rat_en[1]) {
    if (s.path_sel[1]) map1 = map0;
    else               map0 = map1;
  } else if (s.rat_en[0]) {
    if (s.path_sel[0]) map1 = map0;
    else               map0 = map1;
  }

  if (s.rrat_en[0] && !is_x0(s.rd_cmt[0]))
    rrat[s.rd_cmt[0]] = s.tag_cmt[0];
  if (s.rrat_en[1] && !is_x0(s.rd_cmt[1]))
    rrat[s.rd_cmt[1]] = s.tag_cmt[1];

  if (s.alloc_en[0] && !is_x0(s.alloc_rd[0])) {
    if (s.spec_en[0]) map0[s.alloc_rd[0]] = s.alloc_tag[0];
    else              map1[s.alloc_rd[0]] = s.alloc_tag[0];
  }
  if (s.alloc_en[1] && !is_x0(s.alloc_rd[1])) {
    if (s.spec_en[1]) map0[s.alloc_rd[1]] = s.alloc_tag[1];
    else              map1[s.alloc_rd[1]] = s.alloc_tag[1];
  }

  map_br0_ = map0;
  map_br1_ = map1;
  rrat_    = rrat;
}

}  // namespace alias_gm

namespace {

alias_gm::Stim make_stim(
    int flush,
    int spec0, int spec1,
    int rs1_use0, int rs1_use1, int rs2_use0, int rs2_use1,
    int rs1_addr0, int rs1_addr1, int rs2_addr0, int rs2_addr1,
    int alloc_en0, int alloc_en1,
    int alloc_rd0, int alloc_rd1,
    int alloc_tag0, int alloc_tag1,
    int rrat_en0, int rrat_en1,
    int rd_cmt0, int rd_cmt1,
    int tag_cmt0, int tag_cmt1,
    int rat_en0, int rat_en1,
    int path_sel0, int path_sel1) {
  alias_gm::Stim s;
  s.flush          = flush != 0;
  s.spec_en[0]     = spec0 != 0;
  s.spec_en[1]     = spec1 != 0;
  s.rs1_use[0]     = rs1_use0 != 0;
  s.rs1_use[1]     = rs1_use1 != 0;
  s.rs2_use[0]     = rs2_use0 != 0;
  s.rs2_use[1]     = rs2_use1 != 0;
  s.rs1_addr[0]    = static_cast<uint8_t>(rs1_addr0 & 0x1F);
  s.rs1_addr[1]    = static_cast<uint8_t>(rs1_addr1 & 0x1F);
  s.rs2_addr[0]    = static_cast<uint8_t>(rs2_addr0 & 0x1F);
  s.rs2_addr[1]    = static_cast<uint8_t>(rs2_addr1 & 0x1F);
  s.alloc_en[0]    = alloc_en0 != 0;
  s.alloc_en[1]    = alloc_en1 != 0;
  s.alloc_rd[0]    = static_cast<uint8_t>(alloc_rd0 & 0x1F);
  s.alloc_rd[1]    = static_cast<uint8_t>(alloc_rd1 & 0x1F);
  s.alloc_tag[0]   = static_cast<uint8_t>(alloc_tag0 & 0x3F);
  s.alloc_tag[1]   = static_cast<uint8_t>(alloc_tag1 & 0x3F);
  s.rrat_en[0]     = rrat_en0 != 0;
  s.rrat_en[1]     = rrat_en1 != 0;
  s.rd_cmt[0]      = static_cast<uint8_t>(rd_cmt0 & 0x1F);
  s.rd_cmt[1]      = static_cast<uint8_t>(rd_cmt1 & 0x1F);
  s.tag_cmt[0]     = static_cast<uint8_t>(tag_cmt0 & 0x3F);
  s.tag_cmt[1]     = static_cast<uint8_t>(tag_cmt1 & 0x3F);
  s.rat_en[0]      = rat_en0 != 0;
  s.rat_en[1]      = rat_en1 != 0;
  s.path_sel[0]    = path_sel0 != 0;
  s.path_sel[1]    = path_sel1 != 0;
  return s;
}

}  // namespace

extern "C" {

void* alias_dpi_create() {
  auto* gm = new (std::nothrow) alias_gm::AliasGolden();
  if (gm) gm->reset();
  return gm;
}

void alias_dpi_destroy(void* h) {
  delete static_cast<alias_gm::AliasGolden*>(h);
}

void alias_dpi_reset(void* h) {
  if (h) static_cast<alias_gm::AliasGolden*>(h)->reset();
}

void alias_dpi_eval(
    void* h,
    int flush,
    int spec0, int spec1,
    int rs1_use0, int rs1_use1, int rs2_use0, int rs2_use1,
    int rs1_addr0, int rs1_addr1, int rs2_addr0, int rs2_addr1,
    int alloc_en0, int alloc_en1,
    int alloc_rd0, int alloc_rd1,
    int alloc_tag0, int alloc_tag1,
    int rrat_en0, int rrat_en1,
    int rd_cmt0, int rd_cmt1,
    int tag_cmt0, int tag_cmt1,
    int rat_en0, int rat_en1,
    int path_sel0, int path_sel1,
    int* path_use0, int* path_use1,
    int* ps1_0, int* ps1_1,
    int* ps2_0, int* ps2_1) {
  auto* gm = static_cast<alias_gm::AliasGolden*>(h);
  if (!gm) return;
  const alias_gm::Stim s = make_stim(
      flush, spec0, spec1,
      rs1_use0, rs1_use1, rs2_use0, rs2_use1,
      rs1_addr0, rs1_addr1, rs2_addr0, rs2_addr1,
      alloc_en0, alloc_en1, alloc_rd0, alloc_rd1, alloc_tag0, alloc_tag1,
      rrat_en0, rrat_en1, rd_cmt0, rd_cmt1, tag_cmt0, tag_cmt1,
      rat_en0, rat_en1, path_sel0, path_sel1);
  const alias_gm::Obs o = gm->eval(s);
  if (path_use0) *path_use0 = o.path_use[0];
  if (path_use1) *path_use1 = o.path_use[1];
  if (ps1_0) *ps1_0 = o.ps1[0];
  if (ps1_1) *ps1_1 = o.ps1[1];
  if (ps2_0) *ps2_0 = o.ps2[0];
  if (ps2_1) *ps2_1 = o.ps2[1];
}

void alias_dpi_commit(
    void* h,
    int flush,
    int spec0, int spec1,
    int rs1_use0, int rs1_use1, int rs2_use0, int rs2_use1,
    int rs1_addr0, int rs1_addr1, int rs2_addr0, int rs2_addr1,
    int alloc_en0, int alloc_en1,
    int alloc_rd0, int alloc_rd1,
    int alloc_tag0, int alloc_tag1,
    int rrat_en0, int rrat_en1,
    int rd_cmt0, int rd_cmt1,
    int tag_cmt0, int tag_cmt1,
    int rat_en0, int rat_en1,
    int path_sel0, int path_sel1) {
  auto* gm = static_cast<alias_gm::AliasGolden*>(h);
  if (!gm) return;
  const alias_gm::Stim s = make_stim(
      flush, spec0, spec1,
      rs1_use0, rs1_use1, rs2_use0, rs2_use1,
      rs1_addr0, rs1_addr1, rs2_addr0, rs2_addr1,
      alloc_en0, alloc_en1, alloc_rd0, alloc_rd1, alloc_tag0, alloc_tag1,
      rrat_en0, rrat_en1, rd_cmt0, rd_cmt1, tag_cmt0, tag_cmt1,
      rat_en0, rat_en1, path_sel0, path_sel1);
  gm->apply_negedge(s);
}

}  // extern "C"
