# RTL source

SystemVerilog modules organized by pipeline stage. See [../project_outline.txt](../project_outline.txt) §5 for the stage map.

## Active / in progress

| Stage | Modules |
|-------|---------|
| Common | `common/rv_dis_pkg.sv` |
| Decode | `s2_decode/decode_pkg.sv`, `decoder.sv`, `register_file.sv` |
| IF/ID | `s2_decode/if_id.sv`, `state_buffer.sv` |
| Fetch | `s1_fetch/pc.sv`, `target_buffer.sv` |
| ID/EX | `s3_execution/id_ex.sv` |
| Even EX | `s3_execution/even_lane/scalar_alu.sv`, `even_lane.sv` |
| Odd EX | `s3_execution/odd_lane/branch_unit.sv`, `memory_access.sv`, `odd_lane.sv` |
| EX/MEM | `s4_memory/ex_mem_even.sv`, `ex_mem_odd.sv` |
| MEM/WB | `s5_wback/mem_wb.sv` |
| Memory | `s4_memory/memory_cache.sv` (planned cache model) |

## Deferred

- `rtl/issue_dispatch/` — dispatch / pairing / stall
- `rtl/core/` — `spu_lite_cpu` top
- 128-bit SIMD vector RF and execution units

## Conventions

- One module per file; packages in `*_pkg.sv`
- Unit TBs in `sim/tb/<stage>/` with matching file lists under `sim/filelists/`
- Pipeline registers live under stage folders (`s4_memory`, `s5_wback`), not a separate `sx_registers/` tree
