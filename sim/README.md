# Simulation

Logs after **Run Behavioral Simulation**:

```powershell
.\sim\scripts\copy_logs.ps1
```

Writes `sim/logs/_latest/tb.log` and archives under `sim/logs/<top>_<timestamp>/`. Generated logs are gitignored (see repo `.gitignore`).

Design context: [../project_outline.txt](../project_outline.txt) (Verification section).

---

## Verification (Vivado behavioral sim)

### Testbenches

| Top | Coverage |
|-----|----------|
| `register_file_tb` | Dual-issue GPR |
| `dispatch_hazard_tb` | Dispatch/issue golden model |
| `decoder_tb` | Decode fields, `lane_sel`, immediates |
| `even_lane_tb` | Even execution lane |
| `odd_lane_tb` | Odd execution lane |
| `ex_mem_tb` | Per-lane EX/MEM registers |

Per-TB sources, directories, and methodology: [tb/README.md](tb/README.md) (`common/`, `s2_decode/`, `s3_execute/`).

