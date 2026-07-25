// CPU-level DPI glue (optional). Stage golden models live under model/.
// Link this object when building a full-core C++ reference; unit TBs use
// model/s*/**_gm.cpp via sim/config dpi_cpp entries.

#include <cstdint>
#include <cstdio>

extern "C" {

// Placeholder: reset / step hooks for a future full-core C++ reference.
void cpu_dpi_reset() {
  // no-op stub
}

void cpu_dpi_step(int /*enable*/, int /*flush*/) {
  // no-op stub
}

int cpu_dpi_get_pc0() { return 0; }
int cpu_dpi_get_pc1() { return 0; }

}  // extern "C"
