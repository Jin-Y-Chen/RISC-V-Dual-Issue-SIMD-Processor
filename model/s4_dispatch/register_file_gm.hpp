#pragma once
#include "common/types.hpp"
#include <array>

namespace register_file_gm {

struct Stim {
  bool    i0_rs1_use = false, i0_rs2_use = false, i1_rs1_use = false, i1_rs2_use = false;
  bool    i0_valid_wb = false, i1_valid_wb = false;
  uint8_t i0_rs1 = 0, i0_rs2 = 0, i1_rs1 = 0, i1_rs2 = 0;
  uint8_t i0_rd = 0, i1_rd = 0;
  word_t  i0_data_wb = 0, i1_data_wb = 0;
};

struct Obs {
  word_t i0_rs1_data = 0, i0_rs2_data = 0, i1_rs1_data = 0, i1_rs2_data = 0;
};

class RegFileGolden {
 public:
  void reset();
  Obs  eval(const Stim& s) const;
  void apply_negedge(const Stim& s);

 private:
  std::array<word_t, 32> regs_{};  // index 0 unused
  word_t read_port(const Stim& s, bool use, uint8_t addr) const;
};

}  // namespace register_file_gm

extern "C" {
void* rf_dpi_create();
void  rf_dpi_destroy(void* h);
void  rf_dpi_reset(void* h);
void  rf_dpi_eval(void* h, int i0_rs1_use, int i0_rs2_use, int i1_rs1_use, int i1_rs2_use,
                  int i0_valid_wb, int i1_valid_wb, int i0_rs1, int i0_rs2, int i1_rs1,
                  int i1_rs2, int i0_rd, int i1_rd, int i0_data, int i1_data,
                  int* d00, int* d01, int* d10, int* d11);
void  rf_dpi_commit(void* h, int i0_valid_wb, int i1_valid_wb, int i0_rd, int i1_rd,
                    int i0_data, int i1_data);
}
