# RISC-V Dual-Issue SIMD Processor (RV-DIS)

RV32I scalar (active) + 128-bit SIMD (planned). Static even/odd dual-issue lanes.

Design notes: [project_outline.txt](project_outline.txt). Spec: [arm_spu_spulite_project_spec.txt](arm_spu_spulite_project_spec.txt).

HDL is SystemVerilog under `rtl/`. Verification uses Yosys (WSL) and Verilator (optional `-Sim`) via `scripts/run_yosys.ps1`.

## Layout

```
project/
├── rtl/              synthesizable design (Yosys input)
├── tb/               testbenches (Verilator input)
├── sim/              Verilator build outputs (verilator/, waves/, obj_dir/)
├── synth/            netlists, reports, Yosys run logs
├── scripts/          run_yosys.ps1, run_*.sh
├── tests/            ASM programs + assembler
├── docs/             ISA and architecture notes
└── Makefile
```

| Path | Contents |
|------|----------|
| `rtl/` | Pipeline RTL — [rtl/README.md](rtl/README.md) |
| `tb/` | Unit testbenches — [tb/README.md](tb/README.md) |
| `sim/verilator/` | Verilator compile scratch per top |
| `synth/latest/` | Published netlists per top |
| `synth/reports/runs/` | Yosys run logs (`latest/`, `temp/`) |
| `scripts/` | Drivers — [scripts/README.md](scripts/README.md) |

## Quick start

```powershell
# WSL: sudo apt install yosys verilator
.\scripts\run_yosys.ps1 -Top pc_tb
.\scripts\run_yosys.ps1 -Top pc_tb -Sim
make synth TOP=pc_tb
```

Details: [scripts/README.md](scripts/README.md), [synth/README.md](synth/README.md).
