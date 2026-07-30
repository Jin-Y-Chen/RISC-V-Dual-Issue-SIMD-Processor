## Docs index

| Doc | Purpose |
|-----|---------|
| [README.md](../../README.md) | Repo overview + quick start |
| [rtl/README.md](../../rtl/README.md) | RTL stage / module map |
| [tb/README.md](../../tb/README.md) | Verification map |
| [tb/s3_rename/README.md](../../tb/s3_rename/README.md) | RAT + ROB directed TBs |
| [tb/s4_dispatch/README.md](../../tb/s4_dispatch/README.md) | Issue peer TBs |
| [model/README.md](../../model/README.md) | C++ DPI goldens |
| [sim/README.md](../../sim/README.md) | `sim/run.py` control panel |
| [project_outline.txt](../../project_outline.txt) | Detailed design outline |

Cross-module connectivity (origin / owner / consumers / purpose):
[../signal_map](../signal_map).

Topics covered in the outline and in spec §16:

- Dual-issue even/odd split with out-of-order execution (rename, ROB, RS)
- Scalar GPR / PRF (architectural x0–x31, rename p32–p63)
- RAT (`alias_table`): dual speculative maps + RRAT; path select / flush
- Issue peers: reservation station, bypass, selector, PRF (`issue_core_struct`)
- Hazards: RAW, control, dual-issue conflicts
- Register port plan: [register_file_ports.md](register_file_ports.md)
- Memory: scalar word loads and stores

Verification entry points: [../../tb/README.md](../../tb/README.md).
