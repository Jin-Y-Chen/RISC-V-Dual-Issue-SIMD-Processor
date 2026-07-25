# RTL

SystemVerilog by pipeline stage. Design notes: [../project_outline.txt](../project_outline.txt).

## Pipeline stages

| Stage | Directory | Role |
|-------|-----------|------|
| S1 Fetch | `s1_fetch/` | PC, I$, BTB, fetch struct |
| S2 Decode | `s2_decode/` | IF/ID, dual decoder, BHT, target predict |
| S3 Rename | `s3_rename/` | ID/RN, RAT (`allis_table`), ROB, retire |
| S4 Dispatch | `s4_dispatch/` | RN/DP, reservation station, PRF, issue + `dp_ex` |
| S5 Execute | `s5_execution/` | Even/odd lanes (ALU, branch, mem addr) |
| S6 Memory | `s6_memory/` | EX/MEM, L1 D$, BHT state LUT |
| S7 Writeback | `s7_wback/` | EX/MEM/WB merge, retire helpers |

## Modules

| Area | Files |
|------|-------|
| Packages | `import/rv_dis_pkg.sv`, `import/cache_pkg.sv`, stage `funct_pkg/` |
| Fetch | `s1_fetch/fetch_core_struct.sv`, `core_mod/{pc,pc_selector,instruction_cache,target_buffer}.sv` |
| Decode | `s2_decode/decode_core_struct.sv`, `if_id.sv`, `core_mod/{decoder,state_buffer,target_predict}.sv` |
| Rename | `s3_rename/rename_core_struct.sv`, `id_rn.sv`, `core_mod/{allis_table,reorder_buffer}.sv` |
| Issue | `s4_dispatch/issue_core_struct.sv`, `rn_dp.sv`, `core_mod/{reservation_station,p_register_file}.sv` |
| Execute | `s5_execution/execute_core_struct.sv` (`s4_execute_struct`), even/odd lane units |
| Memory | `s6_memory/memory_core_struct.sv` (`s5_memory_struct`), `ex_mem.sv`, `core/memory_cache.sv` |
| Writeback | `s7_wback/ex_mem_wb.sv`, `core/retire.sv` |
| Top | `top/risc_dis_unit.sv` — OoO path: rename → RS/PRF → lanes → mem → WB |

## Conventions

- One module per `.sv` file; shared types in `import/` and stage packages
- Directed TBs in `tb/<stage>/tests/`; run via `python sim/run.py <top>`
