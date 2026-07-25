#pragma once
#include "common/types.hpp"

namespace pc_gm {

struct Stim {
  bool   rst_n = true;
  bool   enable = false;
  bool   dispatch_stall = false;
  bool   spec0_stall = false, spec1_stall = false;
  bool   spec0_in = false, spec1_in = false;
  word_t pc0_in = 0, pc1_in = 0;
};

struct Obs {
  word_t pc0_out = 0, pc1_out = 0;
  bool   spec0_out = false, spec1_out = false;
};

class PcGolden {
 public:
  explicit PcGolden(word_t reset_pc = rv_gm::kResetPc);
  void reset();
  Obs  eval() const;
  void apply_posedge(const Stim& s);

 private:
  word_t reset_pc_;
  word_t pc0_ = 0, pc1_ = 0;
  bool   spec0_ = false, spec1_ = false;
};

}  // namespace pc_gm

extern "C" {
void* pc_dpi_create(int reset_pc);
void  pc_dpi_destroy(void* h);
void  pc_dpi_reset(void* h);
void  pc_dpi_eval(void* h, int* pc0, int* pc1, int* spec0, int* spec1);
void  pc_dpi_commit(void* h, int rst_n, int enable, int dispatch_stall,
                    int spec0_stall, int spec1_stall, int spec0_in, int spec1_in,
                    int pc0_in, int pc1_in);
}
