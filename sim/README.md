# Simulation outputs

**Verilator** compiles SystemVerilog testbenches to a C++ simulator and runs them natively. Here it is the cycle-accurate half of `-Sim`: after Yosys elaborates the DUT, Verilator builds `tb/<top>` and executes self-checks (`[PASS]`, `*** SUMMARY ***`). Output is executable simulation, not a netlist.

**Run:** `./scripts/run-sim -TOP pc_tb` from repo root (WSL). Full setup: [../scripts/README.md](../scripts/README.md).

| Path | Contents |
|------|----------|
| `sim/verilator/<top>/` | Verilator `-Mdir`: `compile.log`, `sim.log`, `obj_dir/V<top>` binary |
| `sim/verilator/<top>/obj_dir/` | Generated C++ and the compiled simulator |
| `sim/waves/` | VCD/FST dumps (future) |
| `sim/obj_dir/` | Optional shared compile output |

TB text output is copied to `synth/reports/runs/latest/<top>/sim.log`. Each `-Sim` run rebuilds `sim/verilator/<top>/` from scratch.

Generated files are gitignored except `.gitkeep` markers.

## Requirements

Install once in WSL: `sudo apt install -y build-essential verilator` (plus `yosys` for the elab step before sim). `verilator --binary` needs **make** and **g++** from `build-essential`.

The driver uses `--timing --relative-includes`. Do not pass `-I tb` by hand — Verilator treats a directory argument as a module name. TB includes like `` `include "../common/tb_console.svh" `` resolve relative to each `tb/<stage>/*_tb.sv` file.

TB `tick` tasks use `#0` after `@(posedge clk)` so NBA updates are visible; this works with apt Verilator 5.032 (no `#1step` / 5.044 requirement).

If compile fails: `sim/verilator/<top>/compile.log` or `synth/reports/runs/latest/<top>/sim.log`.
