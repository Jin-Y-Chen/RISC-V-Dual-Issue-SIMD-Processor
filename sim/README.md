# Simulation build outputs

Verilator compile trees and wave dumps only. Yosys logs live under `synth/reports/runs/`; drivers live in `scripts/`.

| Path | Purpose |
|------|---------|
| `sim/verilator/<top>/` | Verilator `-Mdir` + `obj_dir/` |
| `sim/waves/` | VCD/FST dumps (future) |
| `sim/obj_dir/` | Optional shared compile output |

Run TB sim: `.\scripts\run_yosys.ps1 -Top pc_tb -Sim` or `make sim TOP=pc_tb`.
