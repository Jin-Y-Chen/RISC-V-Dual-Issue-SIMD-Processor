#pragma once

#include "types.hpp"

namespace rv_gm {

inline uint16_t pc_set(word_t pc, int way_aw, int set_aw) {
  if (set_aw == 0) return 0;
  const uint32_t shifted = pc >> (way_aw + 2);
  const uint32_t mask    = (1u << set_aw) - 1u;
  return static_cast<uint16_t>(shifted & mask);
}

inline uint16_t pc_way(word_t pc, int way_aw) {
  if (way_aw == 0) return 0;
  const uint32_t shifted = pc >> 2;
  const uint32_t mask    = (1u << way_aw) - 1u;
  return static_cast<uint16_t>(shifted & mask);
}

inline word_t cache_way_read(uint64_t way_entry, word_t default_data, int data_w) {
  const uint32_t mask =
      (data_w >= 32) ? 0xFFFFFFFFu : (data_w <= 0) ? 0u : ((1u << data_w) - 1u);
  if ((way_entry >> data_w) & 1ull)
    return static_cast<word_t>(way_entry & mask);
  return default_data;
}

inline uint64_t cache_set_write(bool valid, word_t data, int data_w) {
  const uint32_t mask =
      (data_w >= 32) ? 0xFFFFFFFFu : (data_w <= 0) ? 0u : ((1u << data_w) - 1u);
  uint64_t e = data & mask;
  if (valid) e |= (1ull << data_w);
  return e;
}

}  // namespace rv_gm
