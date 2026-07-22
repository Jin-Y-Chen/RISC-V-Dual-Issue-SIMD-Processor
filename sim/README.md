# Simulation control panel

Single Python entrypoint for directed testbenches and UVM suites. Default
simulator is XSim (Vivado); Questa, VCS, and Xcelium adapters are available for
UVM.

Requires Python 3.10+ and the chosen simulator on `PATH`, or
`VIVADO=.../vivado.bat` for XSim.

```powershell
python sim/run.py doctor
python sim/run.py --list
python sim/run.py pc_tb
python sim/run.py rename_uvm --test rename_smoke_test
python sim/run.py clean
```

```bash
python sim/run.py pc_tb
python sim/run.py rename_uvm --sim questa --test rename_random_test
```

## Layout

```text
sim/
  run.py                 Public control panel
  lib/
    common.py            Target registry, list/doctor/clean, JSON config
    xsim.py              Default XSim adapter
    questa.py vcs.py xcelium.py
  filelists/
    uvm/rename.f         UVM rename compile list
  config/<target>.json   Optional plusargs / artifacts / extra_sources
  results/<target>/<sim>/compile_run.log
  work/<sim>/...         Simulator scratch (ignored)
  tcl/vivado_sim.tcl     Optional Vivado Tcl helper (tool-specific)
```

Directed sources still come from `.slang/project.f` (minimal DUT/GM/TB filter by
default; `--full` or `"full": true` in JSON uses the whole list). UVM suites use
explicit filelists under `sim/filelists/`.

## Options

| Flag / command | Purpose |
|----------------|---------|
| `--list [--kind directed\|uvm]` | Show tops / suites |
| `--sim xsim\|questa\|vcs\|xcelium` | Simulator (default `xsim`) |
| `--test <name>` | UVM test name |
| `--verbosity <lvl>` | UVM verbosity |
| `--full` | Directed: compile all RTL/GM from project.f |
| `--flist <path>` | Override file list |
| `--mem <path>` | `+imem_mem=` |
| `--plusarg k=v` | Extra plusarg |
| `doctor` | Tool / filelist diagnostics |
| `clean` | Remove `results/` and `work/` |

## Config JSON

`sim/config/<target>.json` (optional):

```json
{
  "extra_sources": ["rtl/path/file.sv"],
  "plusargs": ["imem_mem=${MEM_FILE}", "cache_dump=icache_bank.txt"],
  "artifacts": ["icache_bank.txt"],
  "full": false
}
```

Placeholders: `${ROOT}`, `${OUT}`, `${MEM_FILE}`.

## UVM suites

| Target | Top | Default test | Filelist |
|--------|-----|--------------|----------|
| `rename_uvm` | `rename_tb_top` | `rename_smoke_test` | `sim/filelists/uvm/rename.f` |

UVM SystemVerilog lives under `tb/uvm/`. See [`tb/README.md`](../tb/README.md).
