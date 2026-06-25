# Scripts

Entry point: `run_yosys.ps1` (Yosys + optional Verilator). Helpers: `log_layout.ps1` (dot-sourced), `run_synth.sh` / `run_sim.sh` / `run_all.sh` (bash wrappers).

Related: [../sim/README.md](../sim/README.md), [../synth/README.md](../synth/README.md), [../tb/README.md](../tb/README.md).

---

## What `run_yosys.ps1` actually does

This flow uses Yosys for **RTL check**, not cycle-accurate testbench simulation.

| Mode | Yosys commands | Pass means |
|------|----------------|------------|
| Default (elab) | `read`, `hierarchy -check`, `proc`, `opt`, `stat` | SV parses, hierarchy resolves, no `ERROR:` |
| `-Synth` | above + `synth` on DUT | DUT module synthesizes |
| `-SynthRtl` | reads all `rtl/**/*.sv`, `synth` on chip top | Full design synthesizes |

It does **not** run testbench self-tests unless you pass **`-Sim`** (Verilator in WSL). Without `-Sim`, `run.log` is Yosys output only — no `[PASS]` / `SUMMARY` lines.

---

## Install (WSL)

Both tools run in **WSL** (Ubuntu). Yosys was originally developed for Linux; this repo calls both through WSL from PowerShell on `/mnt/c/...`.

From an Ubuntu shell:

```bash
sudo apt update
sudo apt install -y yosys verilator
yosys -V
verilator --version
```

| Tool | Role | Output folder |
|------|------|---------------|
| **Yosys** | Elaboration / synthesis | [../synth/README.md](../synth/README.md) |
| **Verilator** | TB compile + self-test (`-Sim` only) | [../sim/README.md](../sim/README.md) |

Yosys alone covers `-Top` / `-All` / `-Synth` / `-SynthRtl`. Install Verilator only if you use **`-Sim`**.

### Verify from repo root (PowerShell)

```powershell
wsl bash -lc "command -v yosys && command -v verilator"
.\scripts\run_yosys.ps1 -Top pc_tb          # Yosys elab → synth/reports/runs/latest/
.\scripts\run_yosys.ps1 -Top pc_tb -Sim     # + Verilator → sim/verilator/<top>/
```

Check `synth/reports/runs/latest/<top>/summary.txt` for `result:` (Yosys) and `sim:` (Verilator).

---

## Common commands

```powershell
.\scripts\run_yosys.ps1 -Top pc_tb
.\scripts\run_yosys.ps1 -Top pc_tb -Sim
.\scripts\run_yosys.ps1 -Top decoder_tb -Synth
.\scripts\run_yosys.ps1 -All
.\scripts\run_yosys.ps1 -SynthRtl
.\scripts\run_yosys.ps1 -Clean
```

```bash
./scripts/run_sim.sh --help
./scripts/run_synth.sh --help
TOP=pc_tb ./scripts/run_synth.sh
TOP=pc_tb ./scripts/run_sim.sh
make synth TOP=pc_tb
```

PowerShell: `.\scripts\run_yosys.ps1 -Help`

---

## What happens on each run

1. Previous `synth/reports/runs/latest/*` → `synth/reports/runs/temp/<timestamp>/`
2. Scratch cleared in `synth/build/yosys/`
3. Yosys runs via WSL; results copied to `synth/reports/runs/latest/<top>/`
4. Netlist mirrored to `synth/latest/<top>/`
5. With `-Sim`, Verilator builds under `sim/verilator/<top>/obj_dir/`

---

## Flags

| Flag | Use |
|------|-----|
| `-Top <name>` | One TB |
| `-All` | All 15 TBs |
| `-Synth` | Add `synth` step |
| `-Sim` | Verilator TB self-test → `sim.log` |
| `-SynthRtl` | Full-chip synthesis |
| `-Clean` | Clear Yosys scratch |
| `-DeleteOddLogs` | Remove archived `odd_lane_tb*` under runs/temp |
