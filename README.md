# RISC-V Dual-Issue Out-of-Order Processor (RV-DIS)

RV32I scalar core with static even/odd dual-issue lanes and out-of-order
execution (rename, ROB, reservation stations).

Design notes: [project_outline.txt](project_outline.txt). Spec: [arm_spu_spulite_project_spec.txt](arm_spu_spulite_project_spec.txt).

HDL is SystemVerilog under `rtl/`. Directed and UVM verification run through
`python sim/run.py` (XSim default; Questa/VCS/Xcelium adapters for UVM).

## Layout

```
project/
├── rtl/              synthesizable design
├── tb/               directed TBs, golden models, UVM (`tb/uvm/`)
├── sim/              Python control panel, filelists, results/
├── program/          ASM sources, hex images, assembler
├── docs/             ISA and architecture notes
└── verif/            redirect stub (sources moved to tb/uvm + sim/)
```

| Path | Contents |
|------|----------|
| `rtl/` | Pipeline RTL — [rtl/README.md](rtl/README.md) |
| `tb/` | Directed TBs + UVM — [tb/README.md](tb/README.md) |
| `sim/` | Simulation control panel — [sim/README.md](sim/README.md) |

## Quick start

Requires Python 3.10+ and Vivado XSim (`VIVADO=.../vivado.bat` if needed):

```powershell
python sim/run.py doctor
python sim/run.py --list
python sim/run.py pc_tb
python sim/run.py rename_uvm --test rename_smoke_test
```

Details: [sim/README.md](sim/README.md).
