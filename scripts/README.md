# Scripts

Entry point: `run_yosys.ps1` (Yosys + optional Verilator). Bash shortcuts: `run-sim`, `run-synth`, `run-all`. Helpers: `Makefile`, `log_layout.ps1`, `fix-sh-lf.ps1`, `run_*.sh`.

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

## Install (WSL) — do this once

Yosys and Verilator run in **Ubuntu on WSL**. From Windows, `run-sim` / `run_yosys.ps1` call into WSL (and may hop through PowerShell with `wslpath` so paths look like `C:\...`).

In an **Ubuntu** shell:

```bash
sudo apt update
sudo apt install -y yosys build-essential verilator
```

| Package | Why |
|---------|-----|
| `yosys` | Elaboration / synthesis (`run-synth`, `-Synth`) |
| `verilator` | TB compile + run (`run-sim`, `-Sim`) |
| `build-essential` | `make` + `g++` — required for `verilator --binary` |

Confirm everything is on PATH:

```bash
command -v yosys verilator make g++
yosys -V
verilator --version
```

Ubuntu apt ships Verilator **5.032**; that is fine. TBs use `#0` (not `#1step`) in `tick` tasks so they build without a newer Verilator.

### Run (repo root or this directory)

```bash
./scripts/run-sim -TOP pc_tb      # Yosys elab + Verilator self-test
./scripts/run-synth -TOP pc_tb    # Yosys elab only
./scripts/run-all                 # all unit TBs (Yosys)
make sim TOP=pc_tb                # same as run-sim (root Makefile forwards here)
```

From `scripts/`:

```bash
./run-sim -TOP pc_tb
make sim TOP=pc_tb
```

PowerShell (same repo root):

```powershell
.\scripts\run_yosys.ps1 -Top pc_tb -Sim
```

After a sim run, check `synth/reports/runs/latest/pc_tb/summary.txt` (`result:` = Yosys, `sim:` = Verilator) and `.../sim.log` for `[PASS]` lines.

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
./scripts/run-sim --help
./scripts/run-synth --help
./scripts/run-sim -TOP pc_tb
./scripts/run-synth -TOP pc_tb
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

---

## Before you run `-Sim` (troubleshooting)

### `env: bash\r: No such file or directory`

Shell scripts must use **LF** line endings. After clone on Windows, run once from PowerShell:

```powershell
.\scripts\fix-sh-lf.ps1
```

`.gitattributes` keeps `*.sh` and `scripts/run-sim` / `run-synth` / `run-all` on LF in git.

### `The argument ... run_yosys.ps1 ... does not exist` (from WSL)

You ran `./scripts/run-sim` from WSL; the wrapper calls Windows PowerShell, which needs `C:\...` paths. `scripts/common.sh` converts with `wslpath -w` — pull latest scripts if you still see this.

### `Verilator --binary needs make and g++`

Install the full build toolchain (not just `verilator`):

```bash
sudo apt install -y build-essential
```

### `parameter 'Top' is specified more than once`

Use one way to pick the TB: `./scripts/run-sim -TOP pc_tb` **or** `TOP=pc_tb ./scripts/run-sim`, not both with conflicting flags. The wrapper strips `-Top` before calling PowerShell.

### Where to look when something fails

| Symptom | Check |
|---------|--------|
| Yosys elab | `synth/reports/runs/latest/<top>/run.log` — search `ERROR:` |
| Verilator compile / run | `synth/reports/runs/latest/<top>/sim.log` (also `sim/verilator/<top>/compile.log`) |
| Pass/fail summary | `synth/reports/runs/latest/<top>/summary.txt` — `result:` (Yosys), `sim:` (Verilator) |
| Script usage | `./scripts/run-sim --help` or `.\scripts\run_yosys.ps1 -Help` |

With `-Sim`, **both** Yosys and Verilator must pass for exit code 0.

### Yosys vs Verilator

| Tool | What it proves |
|------|----------------|
| Yosys (`run-synth`) | RTL elaborates / synthesizes — **not** that the testbench passed |
| Verilator (`run-sim`) | TB self-checks ran — `[PASS]` and `*** SUMMARY ***` in `sim.log` |

Output folders: [../synth/README.md](../synth/README.md), [../sim/README.md](../sim/README.md).
