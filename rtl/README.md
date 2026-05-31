# RTL source

Place synthesizable VHDL here. Stage folders match the 5-stage pipeline; `even_lane` / `odd_lane` implement spec §5–10.

**Even lane (active):** `scalar_alu.sv`  
**Odd lane (active):** `branch_unit.sv`, `memory_access.sv`  
**Deferred:** `vector_alu_128.sv`, `vector_lsu_128.sv`, `vector_regfile.sv`

**Pipeline registers (`rtl/sx_registers/`):** `ex_mem_even.sv`, `ex_mem_odd.sv` — independent per-lane EX/MEM; `stall_even`/`stall_odd`, `flush_even`/`flush_odd`.

Suggested top entity: `rtl/core/spu_lite_cpu.vhd`

Naming convention (from prior MMU project): one entity per file, `_tb` suffix for testbenches in `sim/tb/` or local `verification/` subfolders.
