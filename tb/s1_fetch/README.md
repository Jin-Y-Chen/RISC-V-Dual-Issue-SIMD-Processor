# S1 Fetch

| Tests (`tests/`) | Command |
|------------------|---------|
| `pc_tb` | `python sim/run.py pc_tb` |
| `pc_selector_tb` | `python sim/run.py pc_selector_tb` |
| `instruction_cache_tb` | `python sim/run.py instruction_cache_tb` |
| `target_buffer_tb` | `python sim/run.py target_buffer_tb` |
| `fetch_core_struct_tb` | `python sim/run.py fetch_core_struct_tb` |

| Path | Role |
|------|------|
| `infra/` | fetch driver / monitor / agent scaffolds |
| `../dpi/shims/s1_fetch/` | DPI wrappers |
| `../../model/s1_fetch/` | C++ golden models |
