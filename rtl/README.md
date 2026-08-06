# RTL

SystemVerilog by pipeline stage. Design notes: [../project_outline.txt](../project_outline.txt).

## Pipeline stages

| Stage | Directory | Role |
|-------|-----------|------|
| S1 Fetch | `s1_fetch/` | PC, I$, BTB, fetch struct |
| S2 Decode | `s2_decode/` | IF/ID, dual decoder, BHT, target predict |
| S3 Rename | `s3_rename/` | ID/RN, RAT (`alias_table`), ROB, retire |
| S4 Dispatch | `s4_dispatch/` | RN/DP, RS (bank+select) / PRF, `dp_ex` at top |
| S5 Execute | `s5_execution/` | Even/odd lanes (ALU, branch, mem addr) |
| S6 Memory | `s6_memory/` | EX/MEM, L1 D$, BHT state LUT |
| S7 Writeback | `s7_wback/` | EX/MEM/WB merge, retire helpers |

## Modules

| Area | Files |
|------|-------|
| Packages | `import/rv_dis_pkg.sv`, `import/cache_pkg.sv`, stage `funct_pkg/` |
| Fetch | `s1_fetch/fetch_core_struct.sv`, `core_mod/{pc,pc_selector,instruction_cache,target_buffer}.sv` |
| Decode | `s2_decode/decode_core_struct.sv`, `if_id.sv`, `core_mod/{decoder,state_buffer,target_predict}.sv` |
| Rename | `s3_rename/rename_core_struct.sv`, `id_rn.sv`, `core_mod/{alias_table,reorder_buffer}.sv`, `rob_units/`, `funct_pkg/{rat,rob}.sv` |
| Dispatch | `s4_dispatch/dispatch_core.sv`, `rn_dp.sv`, `core_mod/{reservation_station,physical_register}.sv`, `funct_pkg/rs.sv` |
| Execute | `s5_execution/execute_core_struct.sv`, even/odd lane units |
| Memory | `s6_memory/memory_core_struct.sv`, `ex_mem.sv`, `core/memory_cache.sv` |
| Writeback | `s7_wback/ex_mem_wb.sv`, `core/retire.sv` |
| Top | `top/risc_dis_unit.sv` — OoO: rename → issue → lanes → mem → WB |

### Dispatch hierarchy (`dispatch_core`)

```text
dispatch_core
  ├── reservation_station   # bank + select (ready / pick / issue mux)
  └── physical_register     # physical register file
```

Select helpers live in `funct_pkg/rs.sv`. Bank is internal to the RS (not ported).
`dp_ex` lives at the chip top (`risc_dis_unit`), not inside dispatch.

### Rename hierarchy (`rename_core_struct`)

```text
rename_core_struct
  ├── alias_table      # RAT + RRAT (dual speculative maps)
  └── reorder_buffer   # tail_alloc + head_retire
```

## Conventions

- One module per `.sv` file; shared types in `import/` and stage `funct_pkg/`
- Directed TBs in `tb/<stage>/tests/`; run via `python sim/run.py <top>`
- Verification docs: [../tb/README.md](../tb/README.md)
