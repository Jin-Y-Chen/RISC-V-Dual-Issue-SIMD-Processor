# S1 Fetch Testbenches

Run from the repository root with Python 3.10+ and Vivado/XSim available.

| Test | Functional coverage | Command |
|---|---|---|
| PC | Reset, sequential advance, speculation mode, stall/enable hold | `python sim/run.py pc_tb` |
| PC selector | Prediction, recovery priority, speculative stall | `python sim/run.py pc_selector_tb` |
| Instruction cache | Dual reads, preload, miss behavior, image dump | `python sim/run.py instruction_cache_tb` |
| Target buffer | Lookup miss/hit, dual training, same-cycle forwarding | `python sim/run.py target_buffer_tb` |
| Fetch structure | Integrated PC, selector, I-cache, and target buffer | `python sim/run.py fetch_core_struct_tb` |

Golden models in [`gm/`](gm/) are compiled automatically.

## Common commands

```powershell
python sim/run.py doctor
python sim/run.py --list
python sim/run.py clean
```

The instruction-cache test defaults to
`program/bin/demo_instructions.mem`. To use another image:

```powershell
python sim/run.py instruction_cache_tb --mem path/to/program.mem
```

Each run prints pass/fail counts. Logs and artifacts are written to:

```text
sim/results/<testbench>/<simulator>/
```
