# Testbenches

Vivado flow, file lists, and log capture: [../README.md](../README.md).  
Design context: [../../project_outline.txt](../../project_outline.txt).

## Directory layout

```
sim/tb/
├── common/
│   └── tb_console.svh       shared PASS/FAIL logging (all *_tb.sv)
├── s2_decode/
│   ├── decoder_tb.sv        decode DUT vs hand-written expected fields
│   ├── register_file_tb.sv  dual-issue scalar GPR (4 read / 2 write)
│   └── dispatch_hazard_tb.sv  golden dispatch/issue policy (no RTL DUT)
└── s3_execute/
    ├── even_lane_tb.sv      even scalar ALU
    ├── odd_lane_tb.sv       odd branch / jump / scalar LSU
    └── ex_mem_tb.sv         per-lane EX/MEM pipeline registers
```

## `sim/tb/common/`

`tb_console.svh` — shared logging for all `*_tb.sv` (`tb_report_open`, `tb_field_*`, `tb_summary`); include as `` `include "../common/tb_console.svh" ``.

---

## `sim/tb/s2_decode/`

### `decoder_tb.sv`

- **DUT:** `rtl/s2_decode/decoder.sv`
- **Checks:** opcode, `funct3`/`funct7`, `rd`/`rs1`/`rs2`, sign-ext imm, `lane_sel`, `rs1_use`/`rs2_use`, `reg_write`, `pc_out`
- **Style:** Hand-written expected decode (independent of `decode_pkg` helpers in RTL)
- **File list:** add `sim/filelists/decoder_tb.f` when running in Vivado

### `register_file_tb.sv`

- **DUT:** `rtl/s2_decode/register_file.sv`
- **Checks:** x0 read-as-zero / write-ignore; dual WB; same-rd `wpc` merge; same-cycle bypass; four read ports
- **Chained GPR state:** one program after reset; later cases read values committed by earlier WB cycles
- **WB commit tests:** log `even`/`odd` `wen`, `rd`, `wdata`, `wpc` (bypass when ID reads overlap WB same cycle)
- **Dependent insn reads:** `tick` + `clear_writes`, then ID read with `wen=0` (storage in `regs[]`, not ADDI immediates)
- **`GPR_*` localparams:** WB payload ≠ small immediates in `rf_detail()` asm strings (avoid RF/imm confusion)
- **File list:** `sim/filelists/register_file_tb.f`

### `dispatch_hazard_tb.sv`

- **DUT:** none (`rtl/issue_dispatch/` placeholder)
- **Checks:** golden RAW (I1 uses I0 `rd`), lane conflict, forward-in-time, stall / single-issue I0 only
- **Uses:** `decode_pkg` lane types + policy functions (documents ID-stage issue rules)
- **File list:** `sim/filelists/dispatch_hazard_tb.f`

---

## `sim/tb/s3_execute/`

### `even_lane_tb.sv`

- **DUT:** `rtl/s3_execution/even_lane/scalar_alu.sv` (via `even_lane` wrapper as wired in file list)
- **Checks:** ADD, SUB, AND, OR, XOR; `reg_write`, `alu_result`, `pc_out`
- **Style:** `decoder_tb`-style stimulus — drive decode fields, compare ALU outputs
- **File list:** add `sim/filelists/even_lane_tb.f` when wired

### `odd_lane_tb.sv`

- **DUT:** `rtl/s3_execution/odd_lane/` (`branch_unit.sv`, `memory_access.sv`, `odd_lane.sv`)
- **Checks:** branches (BEQ, BNE, BLT, BGE, BLTU, BGEU), JAL/JALR targets, LW/SW `mem_addr` / byte enables
- **Style:** `run_insn` + `check_expect` per instruction mnemonic in log
- **File list:** add `sim/filelists/odd_lane_tb.f` when wired

### `ex_mem_tb.sv`

- **DUT:** `rtl/s4_memory/ex_mem_even.sv`, `rtl/s4_memory/ex_mem_odd.sv`
- **Checks:** per-lane EX→MEM capture; `stall_*` holds state; `flush_*` clears valid
- **Style:** Clocked; separate even/odd `run_insn` / `check_expect` tasks
- **File list:** add `sim/filelists/ex_mem_tb.f` when wired
