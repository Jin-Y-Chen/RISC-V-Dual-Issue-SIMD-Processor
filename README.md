# RISC-V Dual-Issue SIMD Processor (RV-DIS)

**Full title:** RV-DIS — A RISC-V Dual-Issue In-Order Processor with 128-bit SIMD  
**ISA:** RV32I scalar (active) + 128-bit SIMD extension (planned)  
**Style:** Static even/odd dual-issue lanes (Cell SPU–inspired partitioning)  
**Target:** FPGA (Artix-7 / Basys 3)

Dual-issue, in-order, 5-stage pipelined CPU. Detailed design notes: [project_outline.txt](project_outline.txt). Full requirements: [arm_spu_spulite_project_spec.txt](arm_spu_spulite_project_spec.txt).

**HDL:** SystemVerilog bring-up under `rtl/` (VHDL top integration planned in `rtl/core/`).

---

## Repository layout

| Path | Purpose |
|------|---------|
| `rtl/common/` | `rv_dis_pkg.sv` — widths, types, shared constants |
| `rtl/s1_fetch/` | PC, branch target buffer (WIP) |
| `rtl/s2_decode/` | Decode, `register_file`, IF/ID buffers |
| `rtl/s3_execution/` | `id_ex`, even/odd execution lanes |
| `rtl/s4_memory/` | Per-lane EX/MEM, memory/cache (WIP) |
| `rtl/s5_wback/` | MEM/WB pipeline register |
| `rtl/issue_dispatch/` | Pairing / stall policy (placeholder) |
| `rtl/core/` | CPU top integration (placeholder) |
| `sim/tb/` | Unit testbenches + `common/tb_console.svh` |
| `sim/filelists/` | Vivado `read_verilog -f` lists |
| `tests/` | ASM and system test programs (planned) |
| `docs/` | ISA, architecture notes |
| `fpga/constraints/` | Pin constraints (planned) |

---

## Pipeline (target)

| Stage | Role |
|-------|------|
| **IF** | Fetch up to two 32-bit instructions per cycle |
| **ID** | Decode, GPR read, lane classify, issue 0–2 ops |
| **EX** | Parallel even (ALU) and odd (LSU / branch) |
| **MEM** | Loads / stores |
| **WB** | Dual write-back to unified scalar GPR |

**Even lane:** ADD, SUB, AND, OR, XOR (+ future SIMD ALU)  
**Odd lane:** LOAD, STORE, BRANCH, JUMP (+ future VLD128/VST128)

---

## Verification

Vivado behavioral sim from repo root:

```tcl
read_verilog -f sim/filelists/<top>.f
```

| Top | File list |
|-----|-----------|
| `register_file_tb` | `sim/filelists/register_file_tb.f` |
| `dispatch_hazard_tb` | `sim/filelists/dispatch_hazard_tb.f` |

See [sim/README.md](sim/README.md) and [sim/tb/README.md](sim/tb/README.md) for all TBs, logging, and `register_file_tb` chained-state methodology.

Run and archive TB logs:

```powershell
.\sim\scripts\run_vivado_sim.ps1 -Top pc_tb
```

---

## Getting started

1. Read [project_outline.txt](project_outline.txt) for ISA policy, RF ports, and milestone checklist.
2. Run unit TBs bottom-up (`register_file_tb`, `decoder_tb`, lane TBs) before core integration.
3. Point Vivado at `sim/filelists/*.f` and add FPGA constraints when ready.
