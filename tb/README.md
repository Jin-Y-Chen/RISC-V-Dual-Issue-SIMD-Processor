# Testbenches

All non-RTL SystemVerilog lives here: directed testbenches, golden models, and
UVM environments. Run simulations through the Python control panel:

```powershell
python sim/run.py <top>
python sim/run.py rename_uvm --test rename_smoke_test
python sim/run.py --list
```

See [`sim/README.md`](../sim/README.md) for simulator options and result layout.

## Layout

```text
tb/
  include/              Shared headers / packages (tb_console.svh, loaders)
  uvm/
    common/             Reusable UVM base package
    rename/             Rename-stage UVM (agents, env, refmodel, tests, top)
  s1_fetch/             Directed TBs (+ gm/)
  s2_decode/            Directed TBs (+ gm/)
  s3_rename/            Directed rename TBs
  s3_execute/           Directed execute TBs (legacy stage name)
  s4_dispatch/          Directed dispatch TBs
  s4_memory/            Directed memory TBs (legacy stage name)
  s5_wback/             Directed writeback TBs (legacy stage name)
  top/                  Full-core directed TB
```

Golden models stay next to their directed stage under `gm/` (not duplicated into
UVM). The rename UVM environment carries its own reference model under
`tb/uvm/rename/env/rename_refmodel.sv`.

## Conventions

- **`tb_advance(clk)`** — tick tasks use `@(negedge clk)`; clocks use
  `always #(CLK_PERIOD/2)`.
- **Includes** — `` `include "../include/tb_console.svh" `` (or the relative path
  from the TB file).
- **`tb_summary`** — end directed TBs with `tb_summary(pass_cnt, fail_cnt)`.

## UVM rename suite

Sources: `tb/uvm/rename/`  
Harness: `tb/uvm/rename/top/rename_tb_top.sv`  
Filelist: `sim/filelists/uvm/rename.f`

```powershell
python sim/run.py rename_uvm
python sim/run.py rename_uvm --test rename_random_test --sim xsim
```

Tests: `rename_smoke_test`, `rename_random_test`, `rename_raw_hazard_test`,
`rename_branch_test`, `rename_flush_test`.

## Directed stage notes

| Area | Examples |
|------|----------|
| Fetch | `pc_tb`, `pc_selector_tb`, `instruction_cache_tb`, `target_buffer_tb`, `fetch_core_struct_tb` |
| Decode | `if_id_tb`, `decoder_tb`, `state_buffer_tb`, `register_file_tb`, `decode_core_struct_tb` |
| Rename | `rename_core_struct_tb`, `reorder_buffer_tb` |
| Dispatch | `rn_dp_tb`, `reservation_station_tb` |
| Execute / Mem / WB | `even_lane_tb`, `odd_lane_tb`, `ex_mem_tb`, `memory_cache_tb`, `ex_mem_wb_tb` |
| Top | `risc_dis_unit_tb` |

Design context: [`../project_outline.txt`](../project_outline.txt)
