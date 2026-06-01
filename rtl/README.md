# RTL source

Place synthesizable VHDL here. Stage folders match the 5-stage pipeline; `even_lane` / `odd_lane` implement spec §5–10.

**Common:** `common/rv_dis_pkg.sv` — RV32I widths, opcodes, types (SIMD defs commented out)  
**Decode (active):** `s2_decode/rv_dis_decode_pkg.sv`, `s2_decode/decoder.sv` — scalar imm/fields/`lane_sel`  
**Even lane (active):** `scalar_alu.sv`  
**Odd lane (active):** `branch_unit.sv`, `memory_access.sv`  
**Deferred:** 128-bit SIMD (vector ALU/LSU/VR — not in current build)

**Pipeline registers (`rtl/sx_registers/`):** `ex_mem_even.sv`, `ex_mem_odd.sv` — independent per-lane EX/MEM; `stall_even`/`stall_odd`, `flush_even`/`flush_odd`.

Suggested top entity: `rtl/core/spu_lite_cpu.vhd`

Naming convention: one entity per file; unit TBs in `sim/tb/<unit>/` (see `sim/tb/README.md`).
