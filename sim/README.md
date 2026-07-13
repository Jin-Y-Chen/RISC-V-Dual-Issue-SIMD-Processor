# Vivado batch simulation

From repo root (Git Bash). Requires Vivado `xvlog`/`xelab`/`xsim` (or `VIVADO=.../vivado.bat`).

```bash
./sim/run.sh pc_tb
./sim/run.sh instruction_cache_tb
./sim/run.sh --list
```

By default only compiles `rtl/import` + matching DUT/GM + `<top>.sv` (fast). Use `--full` for the whole project list. Vivado work/`xsim.dir` use a system temp dir (not under `out/`).

## Layout

```
.slang/project.f              RTL + TB sources + incdirs (Slang + Vivado)
sim/
  run.sh                      ./sim/run.sh <top> [options]
  lib/vivado.sh               xvlog/xelab/xsim helpers
  tcl/vivado_sim.tcl          fallback if direct tools unavailable
  config/<top>.env            optional PLUSARGS / ARTIFACTS / EXTRA_SRCS
  out/<top>/compile_run.log   (+ ARTIFACTS from config)
```

## Options

| Flag | Purpose |
|------|---------|
| `--list` | Show tops in `.slang/project.f` |
| `--full` | Compile all RTL/GM (slow) |
| `--flist <path>` | Override file list |
| `--mem <path>` | `+imem_mem=` |
| `--plusarg k=v` | Extra xsim plusarg |
