# Architecture docs

Main outline: [../../project_outline.txt](../../project_outline.txt).

Topics covered there and in spec §16:

- 5-stage pipeline, dual-issue even/odd split
- Scalar GPR (32×32); vector VR (8×128) planned
- Hazards: RAW, control, dual-issue conflicts
- Register port plan: [register_file_ports.md](register_file_ports.md)
- Memory: scalar words + 16-byte vector accesses (planned)
