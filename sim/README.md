# Simulation

## Save log

After Vivado **Run Behavioral Simulation** + `run 1000ns`:

```powershell
.\sim\scripts\copy_logs.ps1
```

```
sim/logs/
├── latest/
│   ├── tb.log        full PASS/FAIL transcript
│   └── summary.txt   label, time, result (one line)
└── <top>_<time>/     archived copy of the same two files
```

## Testbenches

**Convention:** every `sim/tb/*_tb.sv` must `` `include "tb_console.svh" `` — see [tb/README.md](tb/README.md), copy [tb/tb_template.sv](tb/tb_template.sv) for new TBs.

| Top | Sources |
|-----|---------|
| `even_lane_tb` | `spu_lite_pkg.sv`, `scalar_alu.sv`, `even_lane.sv`, `even_lane_tb.sv` |
| `odd_lane_tb` | `spu_lite_pkg.sv`, `branch_unit.sv`, `address_gen.sv`, `odd_lane.sv`, `odd_lane_tb.sv` |
| `ex_mem_tb` | `spu_lite_pkg.sv`, `ex_mem.sv`, `ex_mem_even.sv`, `ex_mem_odd.sv`, `ex_mem_tb.sv` |

Vivado **include path:** `sim/tb`

Project path: `scripts/sim_log_paths.cfg`
