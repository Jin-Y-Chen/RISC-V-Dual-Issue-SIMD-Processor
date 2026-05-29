**Project name:** RISC-V Dual-Issue SIMD Processor
**Full title:** RV-DIS — A RISC-V Dual-Issue In-Order Processor with 128-bit SIMD  
**Architecture:** RV32I scalar ISA + 128-bit SIMD; static even/odd dual-issue lanes (Cell SPU–inspired partitioning)

Dual-issue, in-order, 5-stage pipelined CPU for FPGA (e.g. Artix-7 / Basys 3). See [arm_spu_spulite_project_spec.txt](arm_spu_spulite_project_spec.txt) for full requirements.

**HDL:** VHDL (primary); Verilog/SystemVerilog may be added under `rtl/` if needed.

---

## Repository layout (mapped to spec)

| Path | Spec sections | Purpose |
|------|---------------|---------|
| `rtl/core/` | 3, 12, 14 | Top-level `spu_lite_cpu` and structural integration |
| `rtl/s1_instruction_fetch/` | 3 (IF) | PC, instruction memory, fetch width for dual-issue |
| `rtl/s2_instruction_decode_issue/` | 3 (ID), 9 | Decode + register read + issue pairing |
| `rtl/issue_dispatch/` | 4, 5, 9 | Even/odd classification, pairing rules, stall on violation |
| `rtl/s3_execution/even_lane/` | 5, 10 | Scalar ALU (ADD, SUB, AND, OR, XOR) |
| `rtl/s3_execution/odd_lane/` | 5, 10 | Scalar LSU, branch/jump |
| `rtl/s4_memory_access/` | 3 (MEM), 11 | MEM stage, memory interface |
| `rtl/s5_write_back/` | 3 (WB), 7 | Merge write-back from both pipelines |
| `rtl/pipeline_registers/` | 3, 14 | IF/ID, ID/EX, EX/MEM, MEM/WB (per-lane as needed) |
| `rtl/register_file/` | 7 | Scalar GPR (32×32) + vector VR (8×128), multi-port, shared by both lanes |
| `rtl/hazard/` | 8, 13, 17 | Forwarding, stalls, dual-issue dependency checks |
| `rtl/control/` | 8, 12 | Global control, flush, stall, dual-issue coordination |
| `rtl/memory/` | 11 | Instruction/data memory or unified memory block |
| `rtl/common/` | 6, 14 | Packages: opcodes, widths, ISA encode/decode helpers |
| `sim/tb/` | 15 | Testbenches (unit + full pipeline) |
| `tests/asm/` | 15 | Instruction-level programs |
| `tests/hazard/` | 15 | Data/control hazard scenarios |
| `tests/simd/` | 15 | 128-bit lane-width ops, vector load/store, SIMD hazard cases |
| `tests/dual_issue/` | 15 | Even+odd pairing and restriction cases |
| `tests/integration/` | 15 | End-to-end programs |
| `fpga/constraints/` | 14 | `.xdc` / pin constraints (Basys 3, etc.) |
| `tools/` | 15 | Assembler, hex loader, `program_loader.py` |
| `docs/` | 16 | Architecture, ISA, hazard/dual-issue write-up, diagrams |

---

## RTL hierarchy (target)

```
spu_lite_cpu (rtl/core/)
├── s1_instruction_fetch/
├── s2_instruction_decode_issue/
│   ├── issue_dispatch/          (also rtl/issue_dispatch/ for standalone TB)
│   └── register_file/           (scalar GPR + vector VR)
├── s3_execution/
│   ├── even_lane/               (scalar ALU + 128-bit SIMD)
│   └── odd_lane/                (scalar/vector memory + control)
├── s4_memory_access/
├── s5_write_back/
├── pipeline_registers/
├── hazard/                      (forwarding + dual-issue deps)
├── control/
└── memory/
```

---

## Pipeline stages

| Stage | Role |
|-------|------|
| **IF** | Fetch up to two instructions per cycle |
| **ID** | Decode, RF read, classify even/odd, issue 0–2 ops |
| **EX** | Parallel even (ALU) and odd (LSU/branch) execution |
| **MEM** | Loads/stores |
| **WB** | Write-back to unified register file |

**Even lane:** ADD, SUB, AND, OR, XOR; **128-bit SIMD:** VADD, VSUB, VAND, VOR, VXOR (16×8, 8×16, or 4×32 lanes).  
**Odd lane:** LOAD, STORE, **VLD128, VST128**, BRANCH, JUMP.

---

## 128-bit SIMD (overview)

| Item | Choice |
|------|--------|
| **Vector width** | 128 bits (16 bytes) |
| **Vector registers** | 8 × 128-bit (`v0`–`v7`), separate from scalar GPR |
| **Lane modes** | 16×8-bit, 8×16-bit, 4×32-bit packed integer ops |
| **Even lane** | Vector ALU (packed add/sub/and/or/xor) |
| **Odd lane** | Vector load/store (`VLD128` / `VST128`, 16-byte aligned) |
| **Dual issue example** | `vadd v1, v2, v3` (even) + `vld128 v4, (a0)` (odd) |

See [docs/isa/README.md](docs/isa/README.md) and [arm_spu_spulite_project_spec.txt](arm_spu_spulite_project_spec.txt) §6.1.

---

## Verification plan

1. Unit TBs per block under `sim/tb/` (mirror `rtl/**/verification/` if you split per-module).
2. `tests/hazard/` — forwarding and stall cases.
3. `tests/dual_issue/` — valid pairs, single-issue fallback, illegal pairs.
4. `tests/simd/` — lane-width vector ops, alignment, scalar/vector dual-issue pairs.
5. Full CPU TB + waveform review in simulator.

---

## Getting started

1. Add `rtl/common/spu_lite_pkg.vhd` (data widths, opcodes, pipeline constants).
2. Implement stages bottom-up with testbenches before `rtl/core/spu_lite_cpu.vhd`.
3. Point Vivado (or other flow) at `rtl/core` top and `fpga/constraints/`.
4. **Vivado simulation:** `.\sim\scripts\copy_logs.ps1` → `sim/logs/latest/` ([sim/README.md](sim/README.md)).
