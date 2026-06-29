# RTL

SystemVerilog by pipeline stage. Stage map: [../project_outline.txt](../project_outline.txt).

## Pipeline stages

| Stage | Directory | Role |
|-------|-----------|------|
| S1 Fetch | `s1_fetch/` | PC, instruction cache, branch target buffer |
| S2 Decode | `s2_decode/` | IF/ID, dual decoder, GPR |
| S3 Execute / Dispatch | `s3_execution/` | Instruction queue, scoreboard, ID/EX, lanes, forward unit |
| S4 Memory | `s4_memory/` | EX/MEM (`ex_mem`), L1 data cache |
| S5 Writeback | `s5_wback/` or `s6_wback/` | EX/MEM/WB merge (`ex_mem_wb`), retire |

## Modules

| Area | Files |
|------|-------|
| Packages | `package/rv_dis_pkg.sv`, `package/cache_pkg.sv` |
| Fetch | `s1_fetch/fetch_core_struct.sv`, `pc.sv`, `core/instruction_cache.sv`, `target_buffer.sv` |
| Decode | `s2_decode/decode_core_struct.sv`, `if_id.sv`, `core/decoder.sv`, `register_file.sv`, `state_buffer.sv` |
| Dispatch / EX | `s3_execution/id_ex_dispatch.sv`, `dispatch_funct/instruction_queue.sv`, `scoreboard.sv`, `id_ex.sv`, `execute_core_struct.sv`, `core/even_lane.sv`, `odd_lane.sv`, `forward_unit.sv` |
| Memory | `s4_memory/ex_mem.sv`, `core/memory_cache.sv` |
| Writeback | `s6_wback/ex_mem_wb.sv` |
| Top | `top/risc_dis_unit.sv` |

`*_struct.sv` / `*_core_struct.sv` files hold bundled port types per stage.

## Not implemented

- 128-bit SIMD vector RF and execution
- Register rename, reorder buffer, OoO RS issue (`core/forward_funct/reserved_buffer.sv` stub)
- `s2_decode/core/target_predict.sv` — stub, not wired in top

## Conventions

- One module per `.sv` file; shared types in `package/`
- TBs in `tb/<stage>/`; file lists live in `run_yosys.ps1` `Get-TbSources`
