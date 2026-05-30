# RTL source

Place synthesizable VHDL here. Stage folders match the 5-stage pipeline; `even_lane` / `odd_lane` implement spec §5–10.

**Even lane (active):** `scalar_alu.sv`  
**Odd lane (active):** `branch_unit.sv`, `address_gen.sv`  
**Deferred:** `vector_alu_128.sv`, `vector_lsu_128.sv`, `vector_regfile.sv`

**Pipeline registers (`rtl/sx_registers/`):** `ex_mem.sv` (even + odd), `ex_mem_even.sv`, `ex_mem_odd.sv` — stall holds, flush clears.

Suggested top entity: `rtl/core/spu_lite_cpu.vhd`

Naming convention (from prior MMU project): one entity per file, `_tb` suffix for testbenches in `sim/tb/` or local `verification/` subfolders.
