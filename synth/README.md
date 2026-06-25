# Synthesis outputs

**Yosys** is an RTL synthesis tool: it reads SystemVerilog, builds hierarchy, and produces a structural or gate-level **netlist** (not runnable simulation). In this repo it is used for elaboration checks (`proc`/`opt`), per-module synthesis (`-Synth`), and full-chip synthesis (`-SynthRtl`). A clean run means no `ERROR:` lines in the log — not that a testbench passed.

Drivers and install: [../scripts/README.md](../scripts/README.md). Run log layout: [reports/runs/README.md](reports/runs/README.md).

| Path | Contents |
|------|----------|
| `synth/latest/<top>/` | Per-TB netlist copy: `netlist.v`, `design.json`, `stat.txt`, `run.ys` |
| `synth/reports/runs/latest/<top>/` | Full run bundle: `run.log`, `summary.txt`, optional `sim.log` |
| `synth/reports/runs/temp/` | Archived previous runs |
| `synth/build/yosys/` | Yosys scratch (`.ys`, `.log`) during a run |
| `synth/netlist.v` | Full-chip netlist after `-SynthRtl` |
| `synth/netlist.json` | JSON dump for the full chip |
| `synth/reports/stat.txt` | Full-chip stat excerpt |

Generated files are gitignored except `.gitkeep` markers.
