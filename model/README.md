# C++ golden models (DPI)

Architectural reference models linked into directed TBs via DPI-C.
SystemVerilog only sees thin shims under `tb/dpi/shims/<stage>/`.

## Layout

```text
model/
├── common/           types, ISA helpers, cache index
├── s1_fetch/         pc, pc_selector, icache, BTB, fetch_core
├── s2_decode/        decoder, if_id, state_buffer, target_predict
├── s3_rename/        alias_table (RAT), rob (ROB)
└── s4_dispatch/      register_file (legacy architectural RF)
```

## S3 rename goldens

| C++ | DPI prefix | SV shim | TB |
|-----|------------|---------|-----|
| `alias_table_gm.{hpp,cpp}` | `alias_dpi_*` | `tb/dpi/shims/s3_rename/alias_table_gm.sv` | `alias_table_tb` |
| `rob_gm.{hpp,cpp}` | `rob_dpi_*` | `tb/dpi/shims/s3_rename/reorder_buffer_gm.sv` | `reorder_buffer_tb` |

Timing convention (RAT / ROB):

1. Drive stim on **posedge**
2. Combo **eval** (`*_dpi_eval`) compared after `#0`
3. State **commit** on **negedge** (`*_dpi_commit` / reset on `!rst_n`)

Wire the C++ file in `sim/config/<stage>/<top>.json`:

```json
"dpi_cpp": ["model/s3_rename/alias_table_gm.cpp"]
```

Imports live in `tb/dpi/dpi_pkg.sv`.

## Build

`python sim/run.py <top>` compiles listed `dpi_cpp` with Vivado `xsc` into
`sim/results/<top>/xsim/<top>_dpi` and links it at `xelab`.
