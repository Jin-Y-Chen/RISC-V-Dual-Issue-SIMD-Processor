# ISA notes

Scalar RV32I-style subset: ADD/SUB, AND/OR/XOR, LOAD/STORE, BRANCH, JUMP. Each opcode maps to even (compute) or odd (mem/control) for dual issue.

## Encoding

Packages: `rtl/import/rv_dis_pkg.sv`. Decode helpers: `decode_pkg` in `rtl/s2_decode/funct_pkg/decode.sv`.

Implemented scalar ops use standard RV32I encodings. Subset details: LW/SW only for memory; branches BEQ, BNE, BLT, BGE.

## Dual-issue rules

| Even lane (compute) | Odd lane (mem/control) |
|-------------------|------------------------|
| OP, OP-IMM | LOAD, STORE, BRANCH, JAL, JALR, LUI, AUIPC |

Valid pair example: `add` + `lw`. Invalid: two odd-lane ops, two even-lane ops, or port conflicts on the same GPR in the same cycle.
