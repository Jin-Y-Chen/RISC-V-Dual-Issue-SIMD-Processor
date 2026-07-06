# Functional Simulation and Waveform

## Overview

Simulators such as Icarus, ModelSim, and VCS use **event-driven** simulation: they queue every `#` delay and signal change, use delta cycles for zero-time settling, and interpret the HDL at runtime—flexible, but slower and often licensed.

An alternative is **cycle-accurate simulation**. This project uses [Verilator](https://verilator.org/), which compiles synchronous RTL and the testbench to C++, links a native executable, and advances one clock at a time, evaluating combinational logic then committing register updates — matching post-synthesis hardware. Our testbenches only need functional checks at `@(posedge clk)`, not gate delays or SDF, so compiled simulation is faster and free.

## Verilator testbench simulation

Run **raw SystemVerilog/Verilog** from `rtl/` and `tb/<top>` directly into Verilator.

**Flow:** `rtl/*.sv + tb/<top>.sv` → `verilator --binary` → `V<top>` → `sim.log`

### How to install

```bash
sudo apt install -y build-essential verilator
command -v verilator make g++
```

| Tool | Role |
|------|------|
| **Verilator** | Compiles RTL + testbench to a native `V<top>` executable |
| **make** + **g++** | Build the generated C++ simulator (`verilator --binary`) |

Build cache: WSL `$HOME/.cache/risc-dis-verilator/<top>/obj_dir` (not in repo).

### How to run

```bash
./scripts/run-sim -TOP pc_tb
./scripts/run-sim -TOP pc_tb --no-trace   # logs only (faster, no VCD)
./scripts/sim/run_functional_sim.sh pc_tb # same as run-sim (no flags = logs only)
```

`run-sim` writes logs plus GTKWave artifacts by default. Use `--no-trace` for logs only.

### What are the results

```
sim/verilator/<top>/
  compile.log
  sim.log
sim/GTKWave/<top>/          # default run-sim (omit with --no-trace)
  trace.vcd
  waveform.svg
```

| File | Produced by | Purpose |
|------|-------------|---------|
| `sim.log` | testbench `$display` | Self-checking results — `[PASS]` / `[FAIL]` per case, inputs/check sections, `*** SUMMARY ***` |
| `compile.log` | Verilator + make | Compile transcript; read when build fails |
| `trace.vcd` | `run-sim` (default) | VCD dump for GTKWave |
| `waveform.svg` | `run-sim` (default) | Static DUT waveform preview |

Example: `sim.log` shows each test case the TB drives, expected vs actual values, and a final pass/fail count.

## GTKWave simulated waveform

Included by default in `./scripts/run-sim`. Use `--no-trace` to skip VCD/SVG, or call `run_functional_sim.sh` directly for finer control.

Verilator `--trace` + `+define+TRACE_VCD` enables `$dumpfile` / `$dumpvars` in `tb/common/tb_console.svh`. **GTKWave** opens the dump; `vcd_to_svg.py` can render a static preview.

### How to install

```bash
sudo apt install -y gtkwave python3
command -v gtkwave python3
```

| Tool | Role |
|------|------|
| **Verilator** `--trace` | Embeds VCD dump support in the compiled simulator |
| `+define+TRACE_VCD` | Enables `$dumpfile` / `$dumpvars` in `tb/common/tb_console.svh` |
| **GTKWave** | Interactive waveform window (zoom, cursors, signal search) |
| **python3** + `scripts/sim/vcd_to_svg.py` | Static `waveform.svg` plot on pass |

### How to run

```bash
./scripts/run-sim -TOP pc_tb                            # sim + trace.vcd + waveform.svg
./scripts/run-sim -TOP pc_tb --no-trace                 # logs only
./scripts/sim/open_waveform.sh pc_tb                   # GTKWave on existing trace
./scripts/sim/gen_waveform.sh pc_tb                    # re-render waveform.svg only
./scripts/sim/run_functional_sim.sh pc_tb --trace       # low-level driver (no svg unless --svg)
```

Scroll horizontally in the IDE or browser to pan the full time window.

In GTKWave: expand the scope tree, select signals, click **Append**; zoom and place cursors on clock edges.

### What are the results

```
sim/GTKWave/<top>/
  trace.vcd
  waveform.svg
```

| File | Produced by | Purpose |
|------|-------------|---------|
| `trace.vcd` | Verilator sim (`--trace`) | Time/value dump for GTKWave functional debug |
| `waveform.svg` | `vcd_to_svg.py` | Single wide DUT waveform plot (scroll horizontally) |

Example: `trace.vcd` shows which signals changed and when; use it to debug failures that `sim.log` reports.

Generated artifacts under `sim/verilator/` and `sim/GTKWave/` are gitignored except `.gitkeep` markers.

Driver docs: [../scripts/README.md](../scripts/README.md).
