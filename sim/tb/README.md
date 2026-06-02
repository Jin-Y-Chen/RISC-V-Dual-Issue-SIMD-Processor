# Testbenches (`sim/tb/`)

## Layout

```
sim/tb/
├── common/
│   ├── tb_console.svh
│   └── tb_template.sv
├── s2_decode/
│   ├── decoder_tb.sv
│   └── register_file_tb.sv
├── s3_execute/
│   ├── even_lane_tb.sv
│   └── odd_lane_tb.sv
└── sx_registers/
    └── ex_mem_tb.sv
```

## Includes

Each testbench (in a subfolder) uses a **relative** path:

```systemverilog
`include "../common/tb_console.svh"
```

This works in Vivado without adding `sim/tb` to include paths.

Optional: add include path `<repo>/sim/tb` and use `` `include "common/tb_console.svh" ``.

## Stimulus pattern

All four unit TBs (`decoder_tb`, `even_lane_tb`, `odd_lane_tb`, `ex_mem_tb`) use the same multi-line log format from `common/tb_console.svh`:

1. **`run_insn`** — drive DUT inputs, advance time (`#1` combinational or `tick()` clocked).
2. **`check_expect`** — `tb_report_open` → `tb_field_*` per signal → `tb_report_close` (`signal = value (exp: …)`, aligned `(exp:)`, dashed separator).
3. **`run_idle`** — deassert `valid` (combinational TBs).

`ex_mem_tb` uses `run_insn_even` / `run_insn_odd` and `check_expect_even` / `check_expect_odd` (two DUTs, clocked).

## Vivado

See [../vivado/README.md](../vivado/README.md) and file lists in [../filelists/](../filelists/).

| Top | TB path | File list |
|-----|---------|-----------|
| `decoder_tb` | `s2_decode/decoder_tb.sv` | `sim/filelists/decoder_tb.f` |
| `register_file_tb` | `s2_decode/register_file_tb.sv` | `sim/filelists/register_file_tb.f` |
| `even_lane_tb` | `s3_execute/even_lane_tb.sv` | `sim/filelists/even_lane_tb.f` |
| `odd_lane_tb` | `s3_execute/odd_lane_tb.sv` | `sim/filelists/odd_lane_tb.f` |
| `ex_mem_tb` | `sx_registers/ex_mem_tb.sv` | `sim/filelists/ex_mem_tb.f` |
