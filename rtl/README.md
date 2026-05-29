# RTL source

Place synthesizable VHDL here. Stage folders match the 5-stage pipeline; `even_lane` / `odd_lane` implement spec §5–10.

**Even lane:** `scalar_alu.vhd`, `simd_alu_128.vhd` (16×8 / 8×16 / 4×32 lane modes).  
**Odd lane:** scalar LSU + `vector_lsu_128.vhd` (VLD128 / VST128).  
**Register file:** `scalar_regfile.vhd`, `vector_regfile.vhd` (8×128-bit).

Suggested top entity: `rtl/core/spu_lite_cpu.vhd`

Naming convention (from prior MMU project): one entity per file, `_tb` suffix for testbenches in `sim/tb/` or local `verification/` subfolders.
