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

**Convention:** every unit TB must `` `include "common/tb_console.svh" `` — see [tb/README.md](tb/README.md).

| Top | TB path |
|-----|---------|
| `decoder_tb` | `tb/s2_decode/decoder_tb.sv` |
| `even_lane_tb` | `tb/even_lane/even_lane_tb.sv` |
| `odd_lane_tb` | `tb/odd_lane/odd_lane_tb.sv` |
| `ex_mem_tb` | `tb/sx_registers/ex_mem_tb.sv` |

Vivado **include path:** `sim/tb` (add each `*_tb.sv` under its folder as a sim source)

Project path: `scripts/sim_log_paths.cfg`
