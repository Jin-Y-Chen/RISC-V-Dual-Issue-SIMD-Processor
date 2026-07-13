# RISC-V Dual-Issue SIMD Processor (RV-DIS)

RV32I scalar (active) + 128-bit SIMD (planned). Static even/odd dual-issue lanes.

Design notes: [project_outline.txt](project_outline.txt). Spec: [arm_spu_spulite_project_spec.txt](arm_spu_spulite_project_spec.txt).

HDL is SystemVerilog under `rtl/`. Verification uses Yosys (WSL) via `scripts/lib/run_yosys.ps1`.

## Layout

```
project/
├── rtl/              synthesizable design (Yosys input)
├── tb/               testbenches
├── sim/              simulation build outputs (logs/, waves/)
├── synth/            netlists, reports, Yosys run logs
├── scripts/          lib/, sim/, maint/ — see scripts/README.md
├── program/          ASM sources, hex images, assembler
├── docs/             ISA and architecture notes
└── Makefile          forwards to scripts/Makefile
```

| Path | Contents |
|------|----------|
| `rtl/` | Pipeline RTL — [rtl/README.md](rtl/README.md) |
| `tb/` | Unit testbenches — [tb/README.md](tb/README.md) |
| `sim/` | Simulation logs and waveform artifacts per top |
| `synth/latest/` | Published netlists per top |
| `synth/reports/runs/` | Yosys run logs (`latest/`, `temp/`) |
| `scripts/` | Drivers — [scripts/README.md](scripts/README.md) (`run-sim`, `run-synth`, `run-all`, `make`) |

## Quick start

**One-time (WSL):**

```bash
sudo apt update && sudo apt install -y yosys build-essential
```

**Run (repo root):**

```bash
./scripts/run-synth -TOP pc_tb    # Yosys check
./scripts/run-sim -TOP pc_tb      # functional TB test
make sim TOP=pc_tb                # same as run-sim
```

```powershell
.\scripts\run_yosys.ps1 -Top pc_tb -Sim
make synth TOP=pc_tb
```

Setup and troubleshooting: [scripts/README.md](scripts/README.md). Sim output: [sim/README.md](sim/README.md). Synth output: [synth/README.md](synth/README.md).
