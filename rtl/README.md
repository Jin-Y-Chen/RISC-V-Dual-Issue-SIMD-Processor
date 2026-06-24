# RTL

SystemVerilog by pipeline stage. Stage map: [../project_outline.txt](../project_outline.txt).

## Modules

| Area | Files |
|------|-------|
| Packages | `package/rv_dis_pkg.sv`, `package/cache_pkg.sv` |
| Fetch | `s1_fetch/core/pc.sv`, `instruction_cache.sv`, `branch/target_buffer.sv` |
| Decode | `s2_decode/core/decoder.sv` (includes `decode_pkg`), `register_file.sv`, `if_id.sv`, `branch/state_buffer.sv` |
| Execute | `s3_execution/id_ex_dispatch.sv`, `dispatch_funct/scoreboard.sv`, `core/even_lane.sv`, `odd_lane.sv`, `forward_unit.sv`, `even_funct/scalar_alu.sv`, `odd_funct/branch_unit.sv`, `memory_access.sv` |
| Memory | `s4_memory/ex_mem.sv`, `core/memory_cache.sv`, `branch/state_LUT.sv` |
| Writeback | `s5_wback/ex_mem_wb.sv` |
| Top | `top/risc_dis_unit.sv` |

`*_struct.sv` files hold bundled port types per stage.

## Not implemented

- 128-bit SIMD vector RF and execution
- `rtl/s2_decode/branch/target_predict.sv` — stub, not wired in top

## Conventions

- One module per `.sv` file; shared types in `package/`
- TBs in `tb/<stage>/`; file lists live in `run_yosys.ps1` `Get-TbSources`
