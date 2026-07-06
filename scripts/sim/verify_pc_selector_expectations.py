#!/usr/bin/env python3
"""Reference model for pc_selector.sv — mirrors tb/s1_fetch/pc_selector_tb.sv model_ref."""


def align(x):
    return x & ~3


def model(
    is_spec,
    i0_pred,
    i1_pred,
    i0_rec,
    i1_rec,
    pc0_in,
    pc1_in,
    i0_tgt,
    i1_tgt,
    i0_exec,
    i1_exec,
):
    recover_any = i0_rec or i1_rec
    stall = (i0_pred or i1_pred) and is_spec and not recover_any
    spec0_en = (i0_pred or i1_pred or is_spec) and not recover_any
    mode = (i0_pred ^ i1_pred) and not recover_any

    pc0 = align(pc0_in)
    pc1 = align(pc1_in)

    if i0_rec:
        pc0 = align(i0_exec)
        pc1 = align(i0_exec) + 4
    elif i1_rec:
        pc0 = align(i1_exec)
        pc1 = align(i1_exec) + 4
    elif i0_pred and i1_pred:
        pc0 = align(i0_tgt)
        pc1 = align(i0_tgt) + 4
    elif i0_pred:
        pc0 = align(i0_tgt)
        pc1 = align(pc1_in)
    elif i1_pred:
        pc0 = align(i1_tgt)
        pc1 = align(pc0_in)

    return pc0, pc1, stall, mode, spec0_en


CASES = [
    ("default_pass", (0, 0, 0, 0, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("default_align", (0, 0, 0, 0, 0, 0x1003, 0x1007, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("i0_predict", (0, 1, 0, 0, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("i1_predict", (0, 0, 1, 0, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("i0_predict_align", (0, 1, 0, 0, 0, 0x1000, 0x1004, 0x2003, 0x3000, 0x4000, 0x5000)),
    ("double_predict", (0, 1, 1, 0, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("in_spec_hold", (1, 0, 0, 0, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("stall_i0_in_spec", (1, 1, 0, 0, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("stall_i1_in_spec", (1, 0, 1, 0, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("stall_both_in_spec", (1, 1, 1, 0, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("i0_recover", (0, 0, 0, 1, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("i1_recover", (0, 0, 0, 0, 1, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("i0_recover_priority", (0, 0, 0, 1, 1, 0x1000, 0x1004, 0x2000, 0x3000, 0x4005, 0x5009)),
    ("i0_recover_align", (0, 0, 0, 1, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4005, 0x5000)),
    ("recover_over_predict", (1, 1, 0, 1, 0, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("recover_over_dual_pred", (1, 1, 1, 0, 1, 0x1000, 0x1004, 0x2000, 0x3000, 0x4000, 0x5000)),
    ("dual_predict_no_stall", (0, 1, 1, 0, 0, 0xA000, 0xA004, 0xB000, 0xC000, 0xD000, 0xE000)),
]


def main():
    print("pc_selector reference expectations:\n")
    for name, args in CASES:
        pc0, pc1, stall, mode, spec0_en = model(*args)
        print(
            f"{name:24s} pc0=0x{pc0:08x} pc1=0x{pc1:08x} "
            f"stall={stall} mode={mode} spec0_en={spec0_en}"
        )


if __name__ == "__main__":
    main()
