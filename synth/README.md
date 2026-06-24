# Synthesis outputs

Published netlists, Yosys run logs, and build scratch from `scripts/run_yosys.ps1`.

| Path | Contents |
|------|----------|
| `synth/latest/<top>/` | Per-TB netlist copy: `netlist.v`, `design.json`, `stat.txt`, `run.ys` |
| `synth/reports/runs/latest/<top>/` | Full run log bundle (`run.log`, `summary.txt`, optional `sim.log`) |
| `synth/reports/runs/temp/` | Archived previous runs |
| `synth/build/yosys/` | Yosys scratch during a run |
| `synth/netlist.v` | Full-chip netlist after `-SynthRtl` |
| `synth/netlist.json` | JSON dump for the full chip |
| `synth/reports/stat.txt` | Full-chip stat excerpt |

Generated files are gitignored except `.gitkeep` markers. Run log layout: [reports/runs/README.md](reports/runs/README.md).
