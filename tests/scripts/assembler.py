#!/usr/bin/env python3
"""
RV-DIS assembler — RV32I subset matching rtl/s2_decode (even/odd lanes).

Converts .asm to machine code for instruction fetch (32-bit words, byte PC).

Usage (from repo root):
  py tests/scripts/assembler.py tests/asm/demo_instructions.asm

Outputs (default: tests/bin/ — flat, no subfolders):
  <name>.txt   — listing: byte PC, hex insn, mnemonic, [even|odd]
  <name>.hex   — Verilog $readmemh: @byte_address, one 32-bit hex word per line
  <name>.mem   — byte-wide IMEM init: @byte_address, one 00..FF hex byte per line

Example: tests/asm/demo_instructions.asm → tests/bin/demo_instructions.{hex,mem,txt}

Supported mnemonics: add addi sub lw sw beq bne blt bge jal jalr lui auipc
  and R-type ALU: sll slt xor srl sra or and (even lane)

Directives: .org <addr>   .word <hex|dec>   .align 4
Registers: x0-x31, zero, ra, sp, gp, tp, t0-t6, a0-a7, s0-s1, etc.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# RV32I opcodes (match rv_dis_pkg.sv)
OPC_OP = 0b0110011
OPC_OP_IMM = 0b0010011
OPC_LOAD = 0b0000011
OPC_STORE = 0b0100011
OPC_BRANCH = 0b1100011
OPC_JAL = 0b1101111
OPC_JALR = 0b1100111
OPC_LUI = 0b0110111
OPC_AUIPC = 0b0010111

F3 = {
    "add": 0b000,
    "sub": 0b000,
    "sll": 0b001,
    "slt": 0b010,
    "xor": 0b100,
    "srl": 0b101,
    "sra": 0b101,
    "or": 0b110,
    "and": 0b111,
    "addi": 0b000,
    "lw": 0b010,
    "sw": 0b010,
    "beq": 0b000,
    "bne": 0b001,
    "blt": 0b100,
    "bge": 0b101,
    "jalr": 0b000,
}

F7_SUB = 0b0100000
F7_SRA = 0b0100000

REG_NAMES = {
    "zero": 0,
    "ra": 1,
    "sp": 2,
    "gp": 3,
    "tp": 4,
    "t0": 5,
    "t1": 6,
    "t2": 7,
    "s0": 8,
    "fp": 8,
    "s1": 9,
    "a0": 10,
    "a1": 11,
    "a2": 12,
    "a3": 13,
    "a4": 14,
    "a5": 15,
    "a6": 16,
    "a7": 17,
    "s2": 18,
    "s3": 19,
    "s4": 20,
    "s5": 21,
    "s6": 22,
    "s7": 23,
    "s8": 24,
    "s9": 25,
    "s10": 26,
    "s11": 27,
    "t3": 28,
    "t4": 29,
    "t5": 30,
    "t6": 31,
}


def reg_num(name: str) -> int:
    n = name.strip().lower()
    if n in REG_NAMES:
        return REG_NAMES[n]
    if n.startswith("x") and n[1:].isdigit():
        v = int(n[1:])
        if 0 <= v <= 31:
            return v
    raise ValueError(f"unknown register: {name}")


def align4(x: int) -> int:
    return x & ~3


def parse_imm(token: str) -> int:
    t = token.strip().lower()
    if t.startswith("0x"):
        return int(t, 16)
    if t.startswith("-0x"):
        v = int(t[3:], 16)
        return -v
    return int(t, 10)


@dataclass
class Line:
    pc: int
    word: int
    text: str
    lane: str


def enc_r(opc: int, f3: int, rd: int, rs1: int, rs2: int, f7: int = 0) -> int:
    return (
        (f7 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (f3 << 12)
        | (rd << 7)
        | opc
    )


def enc_i(opc: int, f3: int, rd: int, rs1: int, imm: int) -> int:
    imm12 = imm & 0xFFF
    return (
        ((imm12 >> 5) << 25)
        | ((imm12 & 0x1F) << 20)
        | (rs1 << 15)
        | (f3 << 12)
        | (rd << 7)
        | opc
    )


def enc_s(opc: int, f3: int, rs1: int, rs2: int, imm: int) -> int:
    imm12 = imm & 0xFFF
    return (
        ((imm12 >> 5) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (f3 << 12)
        | ((imm12 & 0x1F) << 7)
        | opc
    )


def enc_b(opc: int, f3: int, rs1: int, rs2: int, imm: int) -> int:
    """B-type branch offset (byte), imm[0]=0."""
    imm = align4(imm)
    if imm & 1:
        raise ValueError(f"branch offset must be even, got {imm}")
    imm13 = imm & 0x1FFF
    bit12 = (imm13 >> 12) & 1
    bit11 = (imm13 >> 11) & 1
    bits10_5 = (imm13 >> 5) & 0x3F
    bits4_1 = (imm13 >> 1) & 0xF
    return (
        (bit12 << 31)
        | (bits10_5 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (f3 << 12)
        | (bits4_1 << 8)
        | (bit11 << 7)
        | opc
    )


def enc_j(opc: int, rd: int, imm: int) -> int:
    imm = align4(imm)
    if imm & 1:
        raise ValueError(f"jump offset must be even, got {imm}")
    imm21 = imm & 0x1FFFFF
    bit20 = (imm21 >> 20) & 1
    bits10_1 = (imm21 >> 1) & 0x3FF
    bit11 = (imm21 >> 11) & 1
    bits19_12 = (imm21 >> 12) & 0xFF
    return (
        (bit20 << 31)
        | (bits10_1 << 21)
        | (bit11 << 20)
        | (bits19_12 << 12)
        | (rd << 7)
        | opc
    )


def enc_u(opc: int, rd: int, imm: int) -> int:
    imm20 = (imm >> 12) & 0xFFFFF
    return (imm20 << 12) | (rd << 7) | opc


def lane_for_word(word: int) -> str:
    opc = word & 0x7F
    if opc in (OPC_OP, OPC_OP_IMM):
        return "even"
    if opc in (OPC_LOAD, OPC_STORE, OPC_BRANCH, OPC_JAL, OPC_JALR, OPC_LUI, OPC_AUIPC):
        return "odd"
    return "?"


class Assembler:
    def __init__(self) -> None:
        self.pc = 0
        self.labels: Dict[str, int] = {}
        self.lines_src: List[Tuple[int, str]] = []  # pass1: (line_no, text)
        self.words: List[Tuple[int, int, str]] = []  # (pc, word, asm)

    def parse_file(self, path: Path) -> None:
        raw = path.read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(raw, 1):
            s = line.split("#", 1)[0].split(";", 1)[0].strip()
            if not s:
                continue
            self.lines_src.append((i, s))

    def pass1_labels(self) -> None:
        pc = self.pc
        for _, s in self.lines_src:
            if s.endswith(":"):
                self.labels[s[:-1].strip()] = pc
                continue
            parts = s.replace(",", " ").split()
            if parts[0].lower() == ".org":
                pc = parse_imm(parts[1])
                continue
            if parts[0].lower() == ".align":
                a = parse_imm(parts[1]) if len(parts) > 1 else 4
                pc = (pc + a - 1) & ~(a - 1)
                continue
            if parts[0].lower() == ".word":
                pc += 4
                continue
            pc += 4
        self.pc = pc

    def resolve_label(self, tok: str, at_pc: int, is_branch: bool) -> int:
        if tok in self.labels:
            target = self.labels[tok]
            return (target - at_pc) if is_branch else target
        return parse_imm(tok)

    def pass2_assemble(self) -> List[Line]:
        pc = 0
        out: List[Line] = []
        for _, s in self.lines_src:
            if s.endswith(":"):
                continue
            parts = s.replace(",", " ").split()
            op = parts[0].lower()

            if op == ".org":
                pc = parse_imm(parts[1])
                continue
            if op == ".align":
                a = parse_imm(parts[1]) if len(parts) > 1 else 4
                pc = (pc + a - 1) & ~(a - 1)
                continue
            if op == ".word":
                w = parse_imm(parts[1]) & 0xFFFFFFFF
                out.append(Line(pc, w, f".word 0x{w:08X}", lane_for_word(w)))
                pc += 4
                continue

            word = self.encode(op, parts[1:], pc, s)
            out.append(Line(pc, word, s, lane_for_word(word)))
            pc += 4
        return out

    def encode(self, op: str, args: List[str], pc: int, raw: str) -> int:
        if op in ("add", "sub", "sll", "slt", "xor", "srl", "sra", "or", "and"):
            rd, rs1, rs2 = (reg_num(a) for a in args[:3])
            f7 = F7_SUB if op == "sub" else (F7_SRA if op == "sra" else 0)
            return enc_r(OPC_OP, F3[op], rd, rs1, rs2, f7)

        if op == "addi":
            rd, rs1, imm = args[0], args[1], args[2]
            return enc_i(OPC_OP_IMM, F3["addi"], reg_num(rd), reg_num(rs1), parse_imm(imm))

        if op == "lw":
            # lw rd, imm(rs1)
            rd = reg_num(args[0])
            m = re.match(r"(-?\w+)\((\w+)\)", args[1])
            if not m:
                raise ValueError(f"lw syntax: lw rd, imm(rs1): {raw}")
            imm, rs1 = parse_imm(m.group(1)), reg_num(m.group(2))
            return enc_i(OPC_LOAD, F3["lw"], rd, rs1, imm)

        if op == "sw":
            # sw rs2, imm(rs1)
            rs2 = reg_num(args[0])
            m = re.match(r"(-?\w+)\((\w+)\)", args[1])
            if not m:
                raise ValueError(f"sw syntax: sw rs2, imm(rs1): {raw}")
            imm, rs1 = parse_imm(m.group(1)), reg_num(m.group(2))
            return enc_s(OPC_STORE, F3["sw"], rs1, rs2, imm)

        if op in ("beq", "bne", "blt", "bge"):
            rs1, rs2, tgt = args[0], args[1], args[2]
            off = self.resolve_label(tgt, pc, True)
            return enc_b(OPC_BRANCH, F3[op], reg_num(rs1), reg_num(rs2), off)

        if op == "jal":
            rd, tgt = args[0], args[1]
            off = self.resolve_label(tgt, pc, True)
            return enc_j(OPC_JAL, reg_num(rd), off)

        if op == "jalr":
            rd, rest = args[0], args[1]
            m = re.match(r"(-?\w+)\((\w+)\)", rest)
            if not m:
                raise ValueError(f"jalr syntax: jalr rd, imm(rs1): {raw}")
            imm, rs1 = parse_imm(m.group(1)), reg_num(m.group(2))
            return enc_i(OPC_JALR, F3["jalr"], reg_num(rd), rs1, imm)

        if op == "lui":
            rd, imm = args[0], args[1]
            return enc_u(OPC_LUI, reg_num(rd), parse_imm(imm))

        if op == "auipc":
            rd, imm = args[0], args[1]
            return enc_u(OPC_AUIPC, reg_num(rd), parse_imm(imm))

        raise ValueError(f"unsupported mnemonic: {op} ({raw})")

    def assemble(self, path: Path) -> List[Line]:
        self.pc = 0
        self.labels.clear()
        self.lines_src.clear()
        self.parse_file(path)
        self.pass1_labels()
        self.pc = 0
        return self.pass2_assemble()


def write_listing(path: Path, src: Path, lines: List[Line]) -> None:
    with path.open("w", encoding="utf-8") as f:
        f.write(f"# RV-DIS listing — assembled from {src.name}\n")
        f.write("# Format: byte_address : machine_hex  mnemonic  [even|odd lane]\n")
        f.write("# RV-DIS subset: LW/SW only; branches BEQ BNE BLT BGE; no LB/SB/SH\n")
        f.write("#\n")
        for ln in lines:
            f.write(f"0x{ln.pc:08X} : 0x{ln.word:08X}  {ln.text:<32}  [{ln.lane}]\n")
        f.write(f"#\n# Total: {len(lines)} instructions ({len(lines) * 4} bytes)\n")


def write_hex(path: Path, lines: List[Line]) -> None:
    """32-bit words at byte PC — use with $readmemh into word array[PC>>2]."""
    with path.open("w", encoding="utf-8") as f:
        if not lines:
            return
        f.write("// RV-DIS IMEM — $readmemh word hex (@ = byte address of insn)\n")
        base = lines[0].pc
        f.write(f"@{base:08X}\n")
        for ln in lines:
            if ln.pc != base:
                f.write(f"@{ln.pc:08X}\n")
                base = ln.pc
            f.write(f"{ln.word:08X}\n")
            base += 4


def build_byte_image(lines: List[Line]) -> bytearray:
    """Sparse byte map: index = byte address, value = 8-bit memory cell."""
    if not lines:
        return bytearray()
    end = max(ln.pc for ln in lines) + 4
    img = bytearray(end)
    for ln in lines:
        img[ln.pc : ln.pc + 4] = ln.word.to_bytes(4, "little")
    return img


def write_mem8(path: Path, lines: List[Line]) -> None:
    """One byte per line for 8-bit-wide instruction ROM (RV-DIS byte addressing)."""
    img = build_byte_image(lines)
    if not img:
        return
    base = lines[0].pc
    with path.open("w", encoding="utf-8") as f:
        f.write("// RV-DIS byte IMEM — $readmemh into reg [7:0] imem [0:N-1] @ byte addr\n")
        f.write(f"@{base:08X}\n")
        for addr in range(base, len(img)):
            if addr > base and (addr - base) % 16 == 0:
                f.write(f"@{addr:08X}\n")
            f.write(f"{img[addr]:02X}\n")


def main() -> int:
    ap = argparse.ArgumentParser(description="RV-DIS assembler")
    ap.add_argument("input", type=Path, help="assembly source (.asm)")
    ap.add_argument("-o", "--listing", type=Path, help="listing output (.txt)")
    ap.add_argument("--hex", type=Path, help="hex init file (.hex)")
    ap.add_argument("--mem", type=Path, help="byte-wide Verilog $readmemh (.mem)")
    args = ap.parse_args()

    if not args.input.is_file():
        print(f"error: not found: {args.input}", file=sys.stderr)
        return 1

    try:
        lines = Assembler().assemble(args.input)
    except (ValueError, IndexError) as e:
        print(f"assemble error: {e}", file=sys.stderr)
        return 1

    name = args.input.stem
    tests_root = Path(__file__).resolve().parent.parent
    out_dir = tests_root / "bin"
    out_dir.mkdir(parents=True, exist_ok=True)

    listing = args.listing or (out_dir / f"{name}.txt")
    hexpath = args.hex or (out_dir / f"{name}.hex")
    mempath = args.mem or (out_dir / f"{name}.mem")

    write_listing(listing, args.input, lines)
    write_hex(hexpath, lines)
    write_mem8(mempath, lines)

    entry = lines[0].pc if lines else 0
    print(f"assembled {len(lines)} instructions ({len(lines) * 4} bytes)")
    print(f"  entry PC (byte): 0x{entry:08X}")
    print(f"  listing: {listing}")
    print(f"  hex:     {hexpath}")
    print(f"  mem:     {mempath}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
