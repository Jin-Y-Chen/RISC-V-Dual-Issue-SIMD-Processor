# Simulation outputs

**Verilator** compiles SystemVerilog testbenches to a C++ simulator and runs them natively. Here it is the cycle-accurate half of `-Sim`: after Yosys elaborates the DUT, Verilator builds `tb/<top>` and executes self-checks (`[PASS]`, `*** SUMMARY ***`). Output is executable simulation, not a netlist.

Drivers and install: [../scripts/README.md](../scripts/README.md). Testbenches: [../tb/README.md](../tb/README.md).

| Path | Contents |
|------|----------|
| `sim/verilator/<top>/` | Verilator `-Mdir`: `compile.log`, `sim.log`, `obj_dir/V<top>` binary |
| `sim/verilator/<top>/obj_dir/` | Generated C++ and the compiled simulator |
| `sim/waves/` | VCD/FST dumps (future) |
| `sim/obj_dir/` | Optional shared compile output |

Human-readable TB results are copied to `synth/reports/runs/latest/<top>/sim.log`. Each `-Sim` run rebuilds `sim/verilator/<top>/` from scratch.

Generated files are gitignored except `.gitkeep` markers.
