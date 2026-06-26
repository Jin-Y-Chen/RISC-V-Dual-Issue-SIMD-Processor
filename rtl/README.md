# RTL

SystemVerilog by pipeline stage. Stage map: [../project_outline.txt](../project_outline.txt).

## Pipeline stages

| Stage | Directory | Role |
|-------|-----------|------|
| S1 Fetch | `s1_fetch/` | PC, instruction cache, branch target buffer |
| S2 Decode | `s2_decode/` | IF/ID, dual decoder, GPR |
| S3 Dispatch | `s3_dispatch/` | Combinational bundle pass-through (`id_dp`) |
| S4 Execute | `s4_execution/` | ID/EX register (`dp_ex`), lanes, forward unit |
| S5 Memory | `s5_memory/` | EX/MEM (`ex_mem`), L1 data cache |
| S6 Writeback | `s6_wback/` | EX/MEM/WB merge (`ex_mem_wb`), retire |

## Modules

| Area | Files |
|------|-------|
| Packages | `package/rv_dis_pkg.sv`, `package/cache_pkg.sv` |
| Fetch | `s1_fetch/fetch_core_struct.sv`, `core/pc.sv`, `instruction_cache.sv`, `target_buffer.sv` |
| Decode | `s2_decode/decode_core_struct.sv`, `if_id.sv`, `core/decoder.sv`, `register_file.sv`, `state_buffer.sv` |
| Dispatch | `s3_dispatch/id_dp.sv` |
| Execute | `s4_execution/dp_ex.sv`, `execute_core_struct.sv`, `core/even_lane.sv`, `odd_lane.sv`, `forward_unit.sv`, `even_funct/scalar_alu.sv`, `odd_funct/branch_unit.sv`, `memory_access.sv` |
| Memory | `s5_memory/ex_mem.sv`, `memory_core_struct.sv`, `core/memory_cache.sv`, `core/state_lookup.sv` |
| Writeback | `s6_wback/ex_mem_wb.sv`, `core/retire.sv` |
| Top | `top/risc_dis_unit.sv` |

`*_struct.sv` / `*_core_struct.sv` files hold bundled port types per stage.

## Not implemented

- 128-bit SIMD vector RF and execution
- `s3_dispatch/core/register_rename.sv`, `reorder_buffer.sv` — stubs
- `s2_decode/core/target_predict.sv` — stub, not wired in top

## Conventions

- One module per `.sv` file; shared types in `package/`
- TBs in `tb/<stage>/`; file lists live in `run_yosys.ps1` `Get-TbSources`
