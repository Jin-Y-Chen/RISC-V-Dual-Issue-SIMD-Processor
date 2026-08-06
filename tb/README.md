# Testbenches

Run from repo root:

```powershell
python sim/run.py <top>          # e.g. pc_tb, alias_table_tb, reservation_station_tb
python sim/run.py rename_uvm
python sim/run.py --list
```

C++ goldens: [`../model/`](../model/) — see [model/README.md](../model/README.md).  
SV DPI shims: `dpi/shims/<stage>/`.

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
│   └── utils/                # tb_console.svh (PASS/FAIL dumps, clk_edge)
│
├── env/                      # full-core verification
│   ├── cpu_env.sv / cpu_agent.sv / cpu_test.sv
│   ├── memory_driver.sv / memory_monitor.sv
│   ├── sequences/
│   └── risc_dis_unit_tb.sv
│
├── uvm/                      # rename_core_struct UVM suite only
│
├── dpi/
│   ├── dpi_pkg.sv            # all DPI-C imports
│   ├── cpu_dpi.cpp           # optional full-core DPI stub
│   └── shims/<stage>/        # DUT-port-compatible DPI wrappers
│
├── s1_fetch/                 # see s1_fetch/README.md
├── s2_decode/
├── s3_rename/                # see s3_rename/README.md  (RAT + ROB)
├── s4_dispatch/              # see s4_dispatch/README.md (bypass/select/RS)
├── s5_execute/
└── s6_wback/
```

Stage folders:

```text
sN_*/
├── README.md  # stage test map (where present)
├── tests/     # directed *_tb.sv
└── infra/     # optional drivers / monitors / scaffolds
```

## Conventions

| Kind | Where |
|------|--------|
| Directed unit test | `sN_*/tests/*_tb.sv` |
| Stage helpers | `sN_*/infra/` |
| DPI shim | `dpi/shims/<stage>/` |
| C++ golden | `model/<stage>/` |
| Sim config | `sim/config/<stage>/<top>.json` |
| Console macros | `` `include "../../common/utils/tb_console.svh" `` from `tests/` |

End directed TBs with `tb_summary(pass_cnt, fail_cnt)`.

Compile-log source groups (XSim): `pkg` → `dut` → `model` → `interface` → `agent` → `env` → `sequence` → `test` → `tb_top`.

Clock in check dumps: `tb_field_in_clk` prints `rising (posedge)` / `falling (negedge)`.

## Stage map

| Stage | Directed tops | Notes |
|-------|---------------|-------|
| S1 Fetch | `pc_tb`, `pc_selector_tb`, `instruction_cache_tb`, `target_buffer_tb`, `fetch_core_struct_tb` | [s1_fetch/README.md](s1_fetch/README.md) |
| S2 Decode | `decoder_tb`, `if_id_tb`, `state_buffer_tb`, `target_predict_tb`, `decode_core_struct_tb` | |
| S3 Rename | `alias_table_tb`, `reorder_buffer_tb` | [s3_rename/README.md](s3_rename/README.md); full rename via UVM |
| S4 Dispatch | `reservation_station_tb`, `dispatch_core_tb`, `rn_dp_tb` | [s4_dispatch/README.md](s4_dispatch/README.md) |
| S5 Execute | `dp_ex_tb`, `even_lane_tb`, `odd_lane_tb`, `memory_cache_tb`, `ex_mem_tb` | |
| S6 Wback | `ex_mem_wb_tb` | |

### Aliases (`sim/lib/common.py`)

| Alias | Canonical top |
|-------|---------------|
| `rat_tb` / `allis_table_tb` | `alias_table_tb` |
| `decode_tb` | `decoder_tb` |

## Rename stage

| What | How |
|------|-----|
| `rename_core_struct` | **UVM only** — `python sim/run.py rename_uvm` |
| `alias_table` (RAT/RRAT) | `python sim/run.py alias_table_tb` |
| `reorder_buffer` | `python sim/run.py reorder_buffer_tb` |

Do not add a directed `rename_core_struct_tb`.

## UVM rename

- Sources: `tb/uvm/rename/`
- Filelist: `sim/filelists/uvm/rename.f`
- Top: `rename_tb_top` (suite name `rename_uvm`)
