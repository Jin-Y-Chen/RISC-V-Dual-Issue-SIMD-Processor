# Testbenches (`sim/tb/`)

## Required for every testbench

1. **Vivado include path:** `sim/tb` (so `` `include "tb_console.svh" `` resolves).
2. **Inside the module** (after `import spu_lite_pkg::*;` if used):

```systemverilog
`include "tb_console.svh"
```

3. Use shared logging tasks (do not roll your own `$display` pass/fail format):

| Task | Use |
|------|-----|
| `tb_pass_detail(name, detail)` | Pass with op/operands/result |
| `tb_fail_detail(name, detail)` | Fail with context |
| `tb_banner(msg)` | Test start |
| `tb_summary(pass_cnt, fail_cnt)` | Final count + `*** SUMMARY: ... ***` |

Copy **`tb_template.sv`** when adding a new TB.

## Existing testbenches

| File | Top |
|------|-----|
| `even_lane_tb.sv` | `even_lane_tb` |
| `odd_lane_tb.sv` | `odd_lane_tb` |
| `ex_mem_tb.sv` | `ex_mem_tb` |
