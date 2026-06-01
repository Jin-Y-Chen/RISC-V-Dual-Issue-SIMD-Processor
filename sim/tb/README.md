# Testbenches (`sim/tb/`)

## Layout

```
sim/tb/
├── README.md
├── common/
│   ├── tb_console.svh   shared PASS/FAIL logging (required)
│   └── tb_template.sv   copy when adding a new TB
├── s2_decode/
│   └── decoder_tb.sv
├── even_lane/
│   └── even_lane_tb.sv
├── odd_lane/
│   └── odd_lane_tb.sv
└── sx_registers/
    └── ex_mem_tb.sv
```

Folders mirror RTL: `rtl/s2_decode`, `rtl/s3_execution/*`, `rtl/sx_registers`.

## Vivado setup

1. **Include path:** `sim/tb` (resolves `` `include "common/tb_console.svh" ``).
2. **Simulation top:** module name (e.g. `decoder_tb`, `even_lane_tb`).
3. In each `*_tb.sv` (after `import rv_dis_pkg::*` if used):

```systemverilog
`include "common/tb_console.svh"
```

## Logging tasks

| Task | Use |
|------|-----|
| `tb_pass_detail(name, detail)` | Pass with op/operands/result |
| `tb_fail_detail(name, detail)` | Fail with context |
| `tb_banner(msg)` | Test start |
| `tb_summary(pass_cnt, fail_cnt)` | Final count + `*** SUMMARY: ... ***` |

Copy `common/tb_template.sv` to `sim/tb/<unit>/<module>_tb.sv` for new tests.

## Testbenches

| Top | Path | RTL sources |
|-----|------|-------------|
| `decoder_tb` | `s2_decode/decoder_tb.sv` | `rv_dis_pkg.sv`, `rv_dis_decode_pkg.sv`, `decoder.sv` |
| `even_lane_tb` | `even_lane/even_lane_tb.sv` | `rv_dis_pkg.sv`, `rv_dis_decode_pkg.sv`, `scalar_alu.sv`, `even_lane.sv` |
| `odd_lane_tb` | `odd_lane/odd_lane_tb.sv` | `rv_dis_pkg.sv`, `branch_unit.sv`, `memory_access.sv`, `odd_lane.sv` |
| `ex_mem_tb` | `sx_registers/ex_mem_tb.sv` | `rv_dis_pkg.sv`, `ex_mem_even.sv`, `ex_mem_odd.sv` |
