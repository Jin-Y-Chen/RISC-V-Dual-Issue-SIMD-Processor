# Simulation

## Layout

```
sim/
├── tb/                      testbenches (+ tb_console.svh, include path)
├── scripts/
│   ├── copy_logs.ps1        copy results after each Vivado run
│   └── sim_log_paths.cfg    Vivado project_dir (edit if needed)
└── logs/
    ├── latest/              newest run
    └── <top>_<time>/        archive
```

Each run folder contains:

| File | Content |
|------|---------|
| `simulate.log` | `[PASS]` / `[FAIL]` and `*** SUMMARY: ... ***` |
| `waveform.wdb` | XSim waveform database (if you logged signals) |
| `summary.txt` | `label`, `time`, `result`, `waveform` |

## Testbenches

| Top | File | Tests |
|-----|------|-------|
| `even_lane_tb` | `tb/even_lane_tb.sv` | Even-lane scalar ALU |
| `ex_mem_tb` | `tb/ex_mem_tb.sv` | EX/MEM registers |

Vivado: **Include paths** = `sim/tb`, **Simulation top** = table above.

**Sources for `even_lane_tb`:**

```
rtl/common/spu_lite_pkg.sv
rtl/s3_execution/even_lane/scalar_alu.sv
rtl/s3_execution/even_lane/even_lane.sv
sim/tb/even_lane_tb.sv
```

## Save results

1. **Run Behavioral Simulation** → `run 1000ns`
2. (Optional) Add signals to waveform and run again so XSim writes a `.wdb`
3. From repo root:

```powershell
cd C:\Users\Jin\Documents\Github\RISC-V-Dual-Issue-SIMD-Processor
.\sim\scripts\copy_logs.ps1
```

Override project path: `.\sim\scripts\copy_logs.ps1 -VivadoProjectDir "C:\path\to\project"`

Open waveforms in Vivado: **File → Simulation Waveform → Open** → `sim/logs/latest/waveform.wdb`
