# Architecture docs

Main outline: [../../project_outline.txt](../../project_outline.txt).

Topics covered there and in spec §16:

- Dual-issue even/odd split with out-of-order execution (rename, ROB, RS)
- Scalar GPR / PRF (architectural x0–x31, rename p32–p63)
- Hazards: RAW, control, dual-issue conflicts
- Register port plan: [register_file_ports.md](register_file_ports.md)
- Memory: scalar word loads and stores
