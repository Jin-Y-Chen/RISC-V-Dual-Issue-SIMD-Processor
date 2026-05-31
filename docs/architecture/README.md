# Architecture documentation

Deliverable per spec §16:

- 5-stage pipeline overview
- Dual-issue even/odd partitioning
- **128-bit SIMD datapath** (even lane) and vector LSU (odd lane)
- Scalar GPR (32×32) and vector VR (8×128) register files
- Hazard handling (data, control, dual-issue, scalar/vector)
- Register file port plan — [register_file_ports.md](register_file_ports.md)
- Memory interface (scalar + 16-byte vector accesses)
