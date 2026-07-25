# Testbenches

Run from repo root:

```powershell
python sim/run.py <top>          # e.g. pc_tb, rob_tb
python sim/run.py rename_uvm
python sim/run.py --list
```

C++ goldens live in [`../model/`](../model/). SV only has thin DPI shims under `dpi/shims/`.

## Layout

```text
tb/
├── README.md
├── tb_pkg.sv                 # shared stim/obs types, ROB DPI helpers
├── tb_top.sv                 # full-core harness (DUT + env + sequences)
│
├── common/                   # shared by all stages
│   ├── interfaces/           # cpu_if, commit_if, memory_if, irq_if
│   ├── transactions/         # txn helper packages
│   ├── config/               # env config stubs
│   └── utils/                # tb_console.svh, imem hex loader
│
├── env/                      # full-core verification
│   ├── cpu_env.sv / cpu_agent.sv / cpu_test.sv
│   ├── memory_driver.sv / memory_monitor.sv
│   ├── sequences/            # directed + random stimulus
│   └── risc_dis_unit_tb.sv   # smoke elaborate of top DUT
│
├── uvm/                      # rename_core_struct UVM suite only
│
├── dpi/
│   ├── dpi_pkg.sv            # all DPI-C imports
│   ├── cpu_dpi.cpp           # optional full-core DPI stub
│   └── shims/<stage>/        # DUT-port-compatible DPI wrappers
│
├── s1_fetch/                 # tests/ + infra/
├── s2_decode/
├── s3_rename/                # directed rob_* DPI TBs (+ infra); no rename_* directed TB
├── s4_dispatch/
├── s5_execute/
└── s6_wback/
```

Each stage folder is only:

```text
sN_*/
├── tests/     # directed *_tb.sv
└── infra/     # drivers, monitors, scoreboards, scaffolds
```

## Conventions

| Kind | Where |
|------|--------|
| Directed unit test | `sN_*/tests/*_tb.sv` |
| Stage helpers | `sN_*/infra/` |
| DPI shim | `dpi/shims/<stage>/` |
| Console macros | `` `include "../../common/utils/tb_console.svh" `` from `tests/` |

End directed TBs with `tb_summary(pass_cnt, fail_cnt)`.

## Rename stage

| What | How |
|------|-----|
| `rename_core_struct` | **UVM only** — `tb/uvm/rename/`, run `python sim/run.py rename_uvm` |
| `reorder_buffer` / ROB units | Directed DPI TBs — `tb/s3_rename/tests/{rob,reorder_buffer}_tb.sv` |

Do not add a directed `rename_core_struct_tb` or extra `rename_*` infra; that coverage lives in the UVM suite.

## UVM rename

- Sources: `tb/uvm/rename/`
- Filelist: `sim/filelists/uvm/rename.f`
- Top: `rename_tb_top` (suite name `rename_uvm`)
