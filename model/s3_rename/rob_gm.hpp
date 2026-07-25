#pragma once

// Architectural golden model for the dual-issue 32-entry ROB.
// Models queue behavior (head/tail/occ/complete/spec), not the RTL 16×2 bank.

#include <array>
#include <cstdint>

namespace rob_gm {

constexpr int kDepth   = 32;
constexpr int kPtrMask = 0x3F;  // 6-bit head/tail

struct Entry {
  bool     valid     = false;
  bool     complete  = false;
  bool     reg_write = false;
  bool     is_branch = false;
  bool     is_store  = false;
  bool     spec_en   = false;
  uint8_t  rd        = 0;
  bool     br_taken  = false;
};

struct Stim {
  bool     flush            = false;
  bool     alloc0_en        = false;
  bool     alloc1_en        = false;
  bool     i0_reg_write     = false;
  bool     i1_reg_write     = false;
  bool     i0_is_brnch      = false;
  bool     i1_is_brnch      = false;
  bool     i0_is_store      = false;
  bool     i1_is_store      = false;
  bool     i0_spec_en       = false;
  bool     i1_spec_en       = false;
  uint8_t  i0_rd_addr       = 0;
  uint8_t  i1_rd_addr       = 0;
  bool     wback0_en        = false;
  bool     wback1_en        = false;
  uint8_t  i0_rob_idx_wb    = 0;  // PRF tag low 6 bits (p32..p63 → flat in [4:0])
  uint8_t  i1_rob_idx_wb    = 0;
  bool     i0_brch_taken_wb = false;
  bool     i1_brch_taken_wb = false;
  bool     retire0_en       = false;
  bool     retire1_en       = false;
};

struct Obs {
  uint8_t  i0_rob_idx     = 0;
  uint8_t  i1_rob_idx     = 0;
  bool     stall          = false;
  bool     i0_can_retire  = false;
  bool     i1_can_retire  = false;
  bool     rrat0_en       = false;
  bool     rrat1_en       = false;
  uint8_t  i0_rd_addr_cmt = 0;
  uint8_t  i1_rd_addr_cmt = 0;
  uint8_t  i0_rob_idx_cmt = 0;
  uint8_t  i1_rob_idx_cmt = 0;
  bool     rat0_en        = false;
  bool     rat1_en        = false;
  bool     i0_path_sel    = false;
  bool     i1_path_sel    = false;
  bool     stb0_en        = false;
  bool     stb1_en        = false;
  uint8_t  head           = 0;
  uint8_t  tail           = 0;
  uint8_t  occ            = 0;
  bool     active_spec    = false;
};

inline uint8_t flat_of(uint8_t ptr) { return ptr & 0x1F; }
inline uint8_t prf_of(uint8_t flat) { return static_cast<uint8_t>(0x20 | (flat & 0x1F)); }
inline uint8_t flat_from_prf(uint8_t prf) { return prf & 0x1F; }

class RobGolden {
 public:
  void reset();
  void flush();

  // Combo prediction from registered state + current stim (retire enables).
  Obs eval(const Stim& s) const;

  // Negedge update: WB → commit clear → alloc → head/tail/spec latch.
  void apply_negedge(const Stim& s);

  // Convenience: eval then apply (not used by cycle-accurate TB).
  Obs cycle(const Stim& s);

  uint8_t head() const { return head_; }
  uint8_t tail() const { return tail_; }
  uint8_t occ() const { return static_cast<uint8_t>((tail_ - head_) & kPtrMask); }
  bool active_spec() const { return active_spec_; }

 private:
  void allocate(const Stim& s);
  void writeback(const Stim& s);
  void retire_commit(const Stim& s, bool& cmt0, bool& cmt1,
                     uint8_t& head_n, bool& spec_n) const;

  std::array<Entry, kDepth> q_{};
  uint8_t head_ = 0;
  uint8_t tail_ = 0;
  bool    active_spec_ = false;
};

}  // namespace rob_gm

#ifdef __cplusplus
extern "C" {
#endif

void* rob_dpi_create();
void  rob_dpi_destroy(void* h);
void  rob_dpi_reset(void* h);

// Predict combo outputs from current registered state + stim.
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
    int* head, int* tail, int* occ, int* active_spec);

// Commit registered-state update at negedge (same stim as eval).
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
    int retire0_en, int retire1_en);

#ifdef __cplusplus
}
#endif
