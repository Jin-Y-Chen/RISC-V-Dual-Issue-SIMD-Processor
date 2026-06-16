# RTL source

SystemVerilog modules organized by pipeline stage. See [../project_outline.txt](../project_outline.txt) §5 for the stage map.

## Active / in progress

| Stage | Modules |
|-------|---------|
| Common | `common/rv_dis_pkg.sv` |
| Decode | `s2_decode/decode_pkg.sv`, `decoder.sv`, `register_file.sv` |
| IF/ID | `s2_decode/if_id.sv`, `state_buffer.sv` |
| Fetch | `s1_fetch/pc.sv`, `target_buffer.sv` |
| Dispatch | `s3_execution/id_ex_dispatch.sv`, `s3_execution/scoreboard.sv` |
| Forward | `s3_execution/forward_unit.sv` |
| Even EX | `s3_execution/even_funct/scalar_alu.sv`, `even_lane.sv` |
| Odd EX | `s3_execution/odd_funct/branch_unit.sv`, `memory_access.sv`, `odd_lane.sv` |
| EX/MEM | `s4_memory/ex_mem_even.sv`, `ex_mem_odd.sv` |
| MEM/WB | `s5_wback/ex_mem_wb.sv` (4 lane → 2 GPR write ports) |
| Top slice | `top/risc_dis_unit.sv` (ID→MEM/WB, no fetch) |
| Memory | `s4_memory/memory_cache.sv` (planned cache model) |

## Deferred

- `rtl/issue_dispatch/` — superseded by scoreboard inside `id_ex_dispatch`
- `rtl/core/` — `spu_lite_cpu` top
- 128-bit SIMD vector RF and execution units

## Conventions

- One module per file; packages in `*_pkg.sv`
- Unit TBs in `sim/tb/<stage>/` with matching file lists under `sim/filelists/`
- Pipeline registers live under stage folders (`s4_memory`, `s5_wback`), not a separate `sx_registers/` tree
