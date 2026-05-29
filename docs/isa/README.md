# ISA documentation

Document encoding and pipeline assignment for scalar and **128-bit SIMD** instructions.

## Scalar (RV32I-style subset)

- Arithmetic: ADD, SUB
- Logical: AND, OR, XOR
- Memory: LOAD, STORE
- Control: BRANCH, JUMP
- Immediates: I-type scalar operations

Each scalar opcode maps to **even** (compute) or **odd** (memory/control) for issue logic.

## 128-bit SIMD extension

| Parameter | Value |
|-----------|--------|
| Vector width | 128 bits |
| Vector registers | `v0`–`v7` (8 × 128-bit), separate from scalar `x0`–`x31` |
| Alignment | Vector memory ops require **16-byte** aligned addresses |

### Lane modes (funct3 or opcode subfield)

| Mode | Lanes | Per-lane op width |
|------|-------|-------------------|
| `.b` | 16 | 8-bit |
| `.h` | 8 | 16-bit |
| `.w` | 4 | 32-bit |

### Even-lane vector ALU

| Instruction | Operation | Pipeline |
|-------------|-----------|----------|
| VADD | Lane-wise add | Even |
| VSUB | Lane-wise subtract | Even |
| VAND | Lane-wise AND | Even |
| VOR | Lane-wise OR | Even |
| VXOR | Lane-wise XOR | Even |

Operands: `vd`, `vs1`, `vs2` (vector register indices 0–7).

### Odd-lane vector memory

| Instruction | Operation | Pipeline |
|-------------|-----------|----------|
| VLD128 | Load 128 bits from memory → VR | Odd |
| VST128 | Store 128 bits from VR → memory | Odd |

Address: scalar base register + optional immediate offset; effective address must be 16-byte aligned.

### Dual-issue pairing examples

Valid pairs (even + odd in same cycle):

- `add x5, x6, x7` + `vld128 v2, (x10)`
- `vadd.vw v1, v2, v3` + `beq x1, x2, label`
- `vadd.vb v4, v5, v6` + `vst128 v4, (x11)`

Invalid: two vector ALU ops, two vector loads, or any pair with a register/file port conflict.

## Encoding (TBD)

Reserve opcode space in `rtl/common/spu_lite_pkg.vhd`:

- Scalar ops: existing R/I/S/B/J-style 32-bit layouts
- Vector ALU: R-type variant with vector register fields in `rd/rs1/rs2` positions
- Vector mem: I/S-type variant targeting VR index and scalar base register
