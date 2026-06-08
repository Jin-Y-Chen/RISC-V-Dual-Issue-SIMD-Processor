# Simulation

Run simulation + archive logs in one command:

```powershell
.\sim\scripts\run_vivado_sim.ps1 -Top pc_tb
```

Run all testbenches:

```powershell
.\sim\scripts\run_vivado_sim.ps1 -All
```

Run all testbenches and delete old odd-lane log folders first:

```powershell
.\sim\scripts\run_vivado_sim.ps1 -All -DeleteOddLogs
```

Outputs:
- `sim/logs/current/<tb_top>/tb.log`
- `sim/logs/current/<tb_top>/summary.txt`
- previous run moved to `sim/logs/temp/`

`tb.log` contains the full simulation output from `xsim`, including complete PASS/FAIL blocks and all detailed field lines printed by the testbench.

At the start of each command run:
1) `sim/logs/temp/` contents are deleted,
2) all existing `sim/logs/current/` contents are moved to `sim/logs/temp/`,
3) new simulation logs are written to `sim/logs/current/`.

The script removes simulator working artifacts (`xsim.dir`, root `xsim.log/.jou/.pb/.wdb`) after log extraction, so only post-simulation TB logs remain in `sim/logs/`.

Options:
- `-Top <tb_top>`: testbench top (`pc_tb`, `if_id_tb`, `decoder_tb`, `register_file_tb`, `dispatch_hazard_tb`, `even_lane_tb`, `odd_lane_tb`, `ex_mem_tb`)
- `-All`: run all testbench tops in sequence
- `-DeleteOddLogs`: remove `sim/logs/odd_lane_tb_*` folders before running
- `-VivadoRoot <path>`: Vivado install root (default `C:\FPGA\2025.2\Vivado`)


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

