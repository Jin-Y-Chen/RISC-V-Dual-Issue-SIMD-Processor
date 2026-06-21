# RTL source

SystemVerilog modules organized by pipeline stage. See [../project_outline.txt](../project_outline.txt) §5 for the stage map.

## Active / in progress

| Stage | Modules |
|-------|---------|
| Common | `common/rv_dis_pkg.sv` |
| Decode | `s2_decode/s2_decode_struct.sv`, `decode_mod/decoder.sv`, `decode_mod/register_file.sv`, `decode_mod/decode_pkg.sv` |
| IF/ID | `s2_decode/if_id.sv` (optional pipeline slice; not in decode structure) |
| Branch | `s2_decode/branch_mod/state_buffer.sv` |
| Fetch | `s1_fetch/s1_fetch_struc.sv`, `s1_fetch/core/pc.sv`, `s1_fetch/core/instruction_cache.sv`, `target/target_buffer.sv` |
| Dispatch | `s3_execution/id_ex_dispatch.sv`, `dispatch_funct/scoreboard.sv` |
| Execute | `s3_execution/s3_execute_struct.sv`, `core/forward_unit.sv`, `core/even_lane.sv`, `core/odd_lane.sv` |
| EX/MEM | `s4_memory/ex_mem.sv` |
| Memory | `s4_memory/s4_memory_struct.sv`, `core/memory_cache.sv` |
| MEM/WB | `s5_wback/ex_mem_wb.sv` (4 lane → 2 GPR write ports) |
| Top | `top/risc_dis_unit.sv` (fetch + ID through MEM/WB) |

## Deferred

- `rtl/issue_dispatch/` — superseded by scoreboard inside `id_ex_dispatch`
- `rtl/core/` — `spu_lite_cpu` top
- 128-bit SIMD vector RF and execution units

## Conventions

- One module per file; packages in `*_pkg.sv`
- Unit TBs in `sim/tb/<stage>/` with matching file lists under `sim/filelists/`
- Pipeline registers live under stage folders (`s4_memory`, `s5_wback`), not a separate `sx_registers/` tree
