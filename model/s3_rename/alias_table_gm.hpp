#pragma once

// Architectural golden model for alias_table (RAT + RRAT, dual path).

#include <array>
#include <cstdint>

namespace alias_gm {

constexpr int kGpr = 32;

struct Stim {
  bool    flush          = false;
  bool    spec_en[2]     = {};
  bool    rs1_use[2]     = {};
  bool    rs2_use[2]     = {};
  uint8_t rs1_addr[2]    = {};
  uint8_t rs2_addr[2]    = {};
  bool    alloc_en[2]    = {};
  uint8_t alloc_rd[2]    = {};
  uint8_t alloc_tag[2]   = {};
  bool    rrat_en[2]     = {};
  uint8_t rd_cmt[2]      = {};
  uint8_t tag_cmt[2]     = {};
  bool    rat_en[2]      = {};
  bool    path_sel[2]    = {};
};

struct Obs {
  bool    path_use[2] = {};
  uint8_t ps1[2]      = {};
  uint8_t ps2[2]      = {};
};

class AliasGolden {
 public:
  void reset();
  Obs  eval(const Stim& s) const;
  void apply_negedge(const Stim& s);

 private:
  static bool is_x0(uint8_t gpr) { return gpr == 0; }

  uint8_t map_read(uint8_t gpr, bool spec_en,
                   const std::array<uint8_t, kGpr>& map0,
                   const std::array<uint8_t, kGpr>& map1) const;
  uint8_t src_lookup(bool use, uint8_t addr, bool spec_en,
                     const std::array<uint8_t, kGpr>& map0,
                     const std::array<uint8_t, kGpr>& map1) const;
  uint8_t i1_src_lookup(bool use, uint8_t addr, const Stim& s,
                        const std::array<uint8_t, kGpr>& map0,
                        const std::array<uint8_t, kGpr>& map1) const;

  std::array<uint8_t, kGpr> rrat_{};
  std::array<uint8_t, kGpr> map_br0_{};  // path1 (spec_en=1)
  std::array<uint8_t, kGpr> map_br1_{};  // path0 (spec_en=0)
};

}  // namespace alias_gm

#ifdef __cplusplus
extern "C" {
#endif

void* alias_dpi_create();
void  alias_dpi_destroy(void* h);
void  alias_dpi_reset(void* h);

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
    int* ps2_0, int* ps2_1);

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
    int path_sel0, int path_sel1);

#ifdef __cplusplus
}
#endif
