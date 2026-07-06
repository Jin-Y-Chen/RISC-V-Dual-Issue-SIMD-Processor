#!/usr/bin/env python3
"""Verify pc_tb sim.log expectations against pc.sv RTL model."""
import re
import sys
from pathlib import Path

RESET_PC = 0


def align(x):
    return x & ~3


def sim_step(state, inp):
    pc0, pc1, is_spec = state
    rst_n = inp["rst_n"]
    enable = inp["enable"]
    stall = inp["fetch_stall"] or inp["dispatch_stall"]
    mode = inp["mode"]
    spec0_en = inp["spec0_en"]
    pc0_in = inp["pc0_in"]
    pc1_in = inp["pc1_in"]

    if not rst_n:
        pc0, pc1, is_spec = RESET_PC, RESET_PC + 4, 0
    elif enable and not stall:
        d = 4 if mode else 8
        pc0 = (align(pc0_in) + d) & 0xFFFFFFFF
        pc1 = (align(pc1_in) + d) & 0xFFFFFFFF
        is_spec = spec0_en
    return pc0, pc1, is_spec


def hx(s):
    return int(s, 16) if s and s != "TBD" else None


def parse_log(path):
    text = Path(path).read_text(encoding="utf-8")
    blocks = re.split(r"-{7,}", text)
    cases = []
    for block in blocks:
        m = re.search(r"\[PASS\]\s+(\S+)\s+\|\s+(.+)", block)
        if not m:
            continue
        name, detail = m.group(1), m.group(2).strip()

        def get_field(pat):
            mm = re.search(pat, block)
            return mm.group(1) if mm else None

        inp = {
            "rst_n": int(get_field(r"rst_n\s*=\s*(\d+)")),
            "enable": int(get_field(r"enable\s*=\s*(\d+)")),
            "fetch_stall": int(get_field(r"fetch_stall\s*=\s*(\d+)")),
            "dispatch_stall": int(get_field(r"dispatch_stall\s*=\s*(\d+)")),
            "mode": int(get_field(r"mode\s*=\s*(\d+)")),
            "spec0_en": int(get_field(r"spec0_en\s*=\s*(\d+)")),
            "pc0_in": hx(get_field(r"pc0_in\s*=\s*(0x[0-9a-fA-F]+)")),
            "pc1_in": hx(get_field(r"pc1_in\s*=\s*(0x[0-9a-fA-F]+)")),
        }
        exp_is = re.search(r"is_spec\s*=\s*\d+\s*\(exp:\s*(\d+)\)", block)
        exp_pc0 = re.search(r"pc0_out\s*=\s*\S+\s*\(exp:\s*(0x[0-9a-fA-F]+)\)", block)
        exp_pc1 = re.search(r"pc1_out\s*=\s*\S+\s*\(exp:\s*(0x[0-9a-fA-F]+)\)", block)
        exp = {
            "is_spec": int(exp_is.group(1)) if exp_is else None,
            "pc0": int(exp_pc0.group(1), 16) if exp_pc0 else None,
            "pc1": int(exp_pc1.group(1), 16) if exp_pc1 else None,
        }
        cases.append((name, detail, inp, exp))
    return cases


def main():
    root = Path(__file__).resolve().parents[2]
    log_path = root / "sim/verilator/pc_tb/sim.log"
    cases = parse_log(log_path)
    state = (0, 4, 0)
    corrections = []
    matches = []

    for name, detail, inp, exp in cases:
        state = sim_step(state, inp)
        pc0, pc1, is_spec = state
        issues = []
        if exp["pc0"] is not None and pc0 != exp["pc0"]:
            issues.append(f"pc0_out: 0x{exp['pc0']:08x} -> 0x{pc0:08x}")
        if exp["pc1"] is not None and pc1 != exp["pc1"]:
            issues.append(f"pc1_out: 0x{exp['pc1']:08x} -> 0x{pc1:08x}")
        if exp["is_spec"] is not None and is_spec != exp["is_spec"]:
            issues.append(f"is_spec: {exp['is_spec']} -> {is_spec}")
        row = (name, pc0, pc1, is_spec)
        if issues:
            corrections.append((name, detail, issues, row))
        else:
            matches.append(row)

    print(f"Verified {len(cases)} cases against pc.sv model\n")
    print(f"Correct expectations: {len(matches)}")
    print(f"Need correction: {len(corrections)}\n")

    if corrections:
        print("=== CORRECTIONS (log exp -> RTL correct) ===\n")
        for name, detail, issues, row in corrections:
            print(f"{name} | {detail}")
            for issue in issues:
                print(f"  {issue}")
            _, pc0, pc1, is_spec = row
            print(f"  => pc0_out=0x{pc0:08x}  pc1_out=0x{pc1:08x}  is_spec={is_spec}\n")

    print("=== FULL REFERENCE (all cases, RTL outputs) ===\n")
    state = (0, 4, 0)
    for name, detail, inp, exp in cases:
        state = sim_step(state, inp)
        pc0, pc1, is_spec = state
        print(
            f"{name}: pc0_out=0x{pc0:08x} pc1_out=0x{pc1:08x} is_spec={is_spec}"
        )


if __name__ == "__main__":
    main()
