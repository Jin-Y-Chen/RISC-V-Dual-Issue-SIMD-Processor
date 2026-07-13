# ISA notes

Scalar: RV32I-style subset (ADD/SUB, AND/OR/XOR, LOAD/STORE, BRANCH, JUMP). Each opcode maps to even (compute) or odd (mem/control) for issue.

SIMD: 128-bit vectors, `v0`–`v7`, 16-byte aligned loads/stores. Lane modes `.b` (16×8), `.h` (8×16), `.w` (4×32).

## Vector ops (planned)

| Even lane ALU | Odd lane mem |
|---------------|--------------|
| VADD, VSUB, VAND, VOR, VXOR | VLD128, VST128 |

Valid dual-issue example: `add` + `vld128`, or `vadd.vw` + `beq`. Invalid: two vector ALUs, two vector mem ops, or port conflicts.

## Encoding

Packages: `rtl/package/rv_dis_pkg.sv`. Scalar decode helpers: `decode_pkg` in `rtl/s2_decode/core/decoder.sv`.

Custom opcodes (not RVV `OP-V`):

| Class | `opcode [6:0]` | Notes |
|-------|----------------|-------|
| Vector ALU | `0001011` | R-type; `funct3` = lane mode, `funct7` = op |
| Vector mem | `0101011` | VLD128 I-type, VST128 S-type |

Lane `funct3`: `000`=.b, `001`=.h, `010`=.w

Vector ALU `funct7`: VADD=0, VSUB=1, VAND=2, VOR=3, VXOR=4

Scalar ops use standard RV32I encodings.
