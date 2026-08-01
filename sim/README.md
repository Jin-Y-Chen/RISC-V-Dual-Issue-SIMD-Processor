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
python sim/run.py alias_table_tb
python sim/run.py bypass_tb
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
    common.py            Target registry, list/doctor/clean, JSON config, aliases
    xsim.py              Default XSim adapter (grouped compile log)
    questa.py vcs.py xcelium.py
  filelists/
    uvm/rename.f         UVM rename compile list
  config/<stage>/<target>.json   Optional plusargs / artifacts / dpi_cpp
    common/  s1_fetch/  s2_decode/  s3_rename/  s4_dispatch/
    s5_execute/  s6_wback/
  results/<target>/<sim>/compile_run.log   (gitignored)
  work/<sim>/...         Simulator scratch (gitignored)
```

Directed sources still come from `.slang/project.f` (minimal DUT/GM/TB filter by
default; `--full` or `"full": true` in JSON uses the whole list). UVM suites use
explicit filelists under `sim/filelists/`.
The runner resolves `config/**/<target>.json` by target name (stage folder is
organizational only). `rename_core_struct` is verified via `rename_uvm` only
(no directed `rename_core_struct_tb` config).

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

`sim/config/<stage>/<target>.json` (optional):

```json
{
  "extra_sources": ["rtl/path/file.sv"],
  "plusargs": ["imem_mem=${MEM_FILE}", "cache_dump=icache_bank.txt"],
  "artifacts": ["icache_bank.txt"],
  "dpi_cpp": ["model/stage/foo_gm.cpp"],
  "full": false
}
```

Placeholders: `${ROOT}`, `${OUT}`, `${MEM_FILE}`.

### Rename / issue configs

| Target | `dpi_cpp` / extras |
|--------|-------------------|
| `alias_table_tb` | `model/s3_rename/alias_table_gm.cpp` + RAT pkg/DUT/shim |
| `reorder_buffer_tb` | `model/s3_rename/rob_gm.cpp` + ROB units/shim |
| `bypass_tb` | `bypass_unit` + `rs` pkg |
| `selector_tb` | `selector_unit` + `rs_issue` |
| `reservation_station_tb` | RS + `rs_wakeup` / `rs_alloc` |

## Target aliases

| Typed name | Runs |
|------------|------|
| `rat_tb` / `allis_table_tb` | `alias_table_tb` |
| `decode_tb` | `decoder_tb` |

## XSim compile log groups

`xvlog` sources are printed under UVM-style headers (compile order unchanged):

`pkg` · `dut` · `model` · `interface` · `agent` · `env` · `sequence` · `test` · `tb_top`

## UVM suites

| Target | Top | Default test | Filelist |
|--------|-----|--------------|----------|
| `rename_uvm` | `rename_tb_top` | `rename_smoke_test` | `sim/filelists/uvm/rename.f` |

UVM SystemVerilog lives under `tb/uvm/`. See [`tb/README.md`](../tb/README.md).
