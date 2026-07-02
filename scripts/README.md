# Scripts

Drivers for Yosys elaboration/synthesis and optional Verilator TB self-tests.

## Layout

```
scripts/
  run-sim, run-synth, run-all   # bash entry points (repo root)
  Makefile                      # make sim / synth / all
  lib/
    run_yosys.ps1               # main driver (WSL Yosys + Verilator)
    log_layout.ps1              # log paths and archive helpers
    common.sh                   # bash → PowerShell bridge
  sim/
    gen_waveform.sh               # re-render SVG from existing trace.vcd
    vcd_to_svg.py                 # VCD → SVG (also called by run-sim)
  maint/
    fix-sh-lf.ps1               # normalize LF after Windows clone
```

Related: [../sim/README.md](../sim/README.md), [../synth/README.md](../synth/README.md), [../tb/README.md](../tb/README.md).

---

## Quick start

Install once in **Ubuntu WSL**:

```bash
sudo apt update
sudo apt install -y yosys build-essential verilator
command -v yosys verilator make g++
```

From repo root:

```bash
./scripts/run-sim -TOP pc_tb       # Yosys elab + Verilator self-test
./scripts/run-synth -TOP pc_tb     # Yosys elab only
./scripts/run-all                  # all 15 unit TBs
make sim TOP=pc_tb                 # same as run-sim
```

PowerShell:

```powershell
.\scripts\lib\run_yosys.ps1 -Top pc_tb -Sim
.\scripts\lib\run_yosys.ps1 -Help
```

With `-Sim`, Verilator also writes `sim/verilator/<top>/trace.vcd` and `waveform.svg` on pass.
Re-render only: `./scripts/sim/gen_waveform.sh <top>`

---

## What `lib/run_yosys.ps1` does

| Mode | Yosys | Pass means |
|------|-------|------------|
| Default | `read`, `hierarchy -check`, `proc`, `opt`, `stat` | SV parses, hierarchy OK, no `ERROR:` |
| `-Synth` | above + `synth` on DUT | DUT synthesizes |
| `-SynthRtl` | all `rtl/**/*.sv`, synth chip top | Full design synthesizes |

Without `-Sim`, only Yosys runs — no TB self-checks, no `[PASS]` / `SUMMARY` in logs.

Verilator object files go to **WSL** `$HOME/.cache/risc-dis-verilator/<top>/obj_dir`. Logs stay in repo: `sim/verilator/<top>/`.

---

## Flags

| Flag | Use |
|------|-----|
| `-Top <name>` | One TB |
| `-All` | All 15 unit TBs |
| `-Synth` | Add synthesis step |
| `-Sim` | Verilator TB self-test → `sim.log` + `waveform.svg` |
| `-SynthRtl` | Full-chip synthesis |
| `-Clean` | Clear Yosys scratch |
| `-DeleteOddLogs` | Drop archived `odd_lane_tb*` logs |

---

## Troubleshooting

**`env: bash\r: No such file or directory`** — run once: `.\scripts\maint\fix-sh-lf.ps1`

**`run_yosys.ps1 ... does not exist` from WSL** — `lib/common.sh` uses `wslpath -w` for `C:\...` paths.

**`Verilator --binary needs make and g++`** — `sudo apt install -y build-essential`

**`parameter 'Top' is specified more than once`** — use `./scripts/run-sim -TOP pc_tb` *or* `TOP=pc_tb ./scripts/run-sim`, not both.

| Symptom | Check |
|---------|--------|
| Yosys fail | `synth/reports/runs/latest/<top>/run.log` |
| Verilator fail | `sim.log`, `sim/verilator/<top>/compile.log` |
| Summary | `summary.txt` — `result:` (Yosys), `sim:` (Verilator) |

With `-Sim`, **both** Yosys and Verilator must pass for exit code 0.
