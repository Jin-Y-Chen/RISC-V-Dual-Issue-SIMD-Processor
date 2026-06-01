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

## Encoding (opcodes in `rtl/common/rv_dis_pkg.sv`; scalar decode in `rtl/s2_decode/rv_dis_decode_pkg.sv`)

Uses RISC-V **custom-0** / **custom-1** major opcodes (not RVV `OP-V`):

| Class | `opcode [6:0]` | Format |
|-------|----------------|--------|
| Vector ALU (even) | `0001011` (`OPC_VEC_ALU`) | R-type: `funct7` op, `rs2`/`rs1`/`rd` = `vs2`/`vs1`/`vd` (use `[2:0]`), `funct3` = lane mode |
| Vector mem (odd) | `0101011` (`OPC_VEC_MEM`) | `F3_VLD128`: I-type imm + scalar base; `F3_VST128`: S-type imm + scalar base, `rs2` = `vs` |

**Lane `funct3`:** `000` = `.b` (16×8), `001` = `.h` (8×16), `010` = `.w` (4×32)

**Vector ALU `funct7`:** `VADD=0`, `VSUB=1`, `VAND=2`, `VOR=3`, `VXOR=4`

Scalar ops remain standard RV32I encodings.
