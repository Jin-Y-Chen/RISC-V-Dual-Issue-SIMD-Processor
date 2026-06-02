# Simulation

## Save log

After Vivado **Run Behavioral Simulation** + `run 1000ns`:

```powershell
.\sim\scripts\copy_logs.ps1
```

```
sim/logs/
├── _latest/
│   ├── tb.log        full PASS/FAIL transcript
│   └── summary.txt   label, time, result (one line)
└── <top>_<time>/     archived copy of the same two files
```

## Testbenches

**Includes:** `` `include "../common/tb_console.svh" `` from each `sim/tb/<unit>/*_tb.sv` — see [tb/README.md](tb/README.md).

| Top | TB path | File list |
|-----|---------|-----------|
| `decoder_tb` | `tb/s2_decode/decoder_tb.sv` | `filelists/decoder_tb.f` |
| `register_file_tb` | `tb/s2_decode/register_file_tb.sv` | `filelists/register_file_tb.f` |
| `even_lane_tb` | `tb/s3_execute/even_lane_tb.sv` | `filelists/even_lane_tb.f` |
| `odd_lane_tb` | `tb/s3_execute/odd_lane_tb.sv` | `filelists/odd_lane_tb.f` |
| `ex_mem_tb` | `tb/sx_registers/ex_mem_tb.sv` | `filelists/ex_mem_tb.f` |

Vivado: [vivado/README.md](vivado/README.md) — or `read_verilog -f sim/filelists/decoder_tb.f` from repo root.

Project path: `scripts/sim_log_paths.cfg`
