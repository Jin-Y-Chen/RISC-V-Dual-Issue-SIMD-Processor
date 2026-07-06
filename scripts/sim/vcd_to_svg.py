#!/usr/bin/env python3
"""VCD -> single long SVG waveform (GTKWave-style). Prefers DUT signals."""
import re
import sys
from pathlib import Path

# Per-TB pages: (slug, title, signal tails under *.dut.*)
TB_PAGES = {
    "pc_tb": [
        ("ctrl", "Control", [
            "clk", "rst_n", "enable", "fetch_stall", "dispatch_stall",
            "mode", "spec0_en", "is_spec",
        ]),
        ("pc_out", "PC outputs", ["pc0_out", "pc1_out"]),
        ("pc_in", "PC inputs", ["pc0_in", "pc1_in"]),
    ],
    "pc_selector_tb": [
        ("ctrl", "Control", ["clk", "rst_n", "stall", "mode", "spec0_en"]),
        ("pc", "PC", ["pc0_out", "pc1_out"]),
        ("pred", "Predictions", [
            "i0_pc_target", "i1_pc_target", "i0_pred_taken", "i1_pred_taken",
        ]),
    ],
    "fetch_core_struct_tb": [
        ("ctrl", "Control", ["clk", "rst_n", "stall", "mode", "spec0_en"]),
        ("pc", "PC", ["pc0_out", "pc1_out"]),
        ("instr", "Instructions", ["instr0", "instr1"]),
    ],
}

DEFAULT_PREFS = [
    "clk", "rst_n", "enable", "fetch_stall", "dispatch_stall", "stall",
    "mode", "spec0_en", "is_spec", "valid", "ready", "flush",
    "pc0_out", "pc1_out", "pc0_in", "pc1_in", "pc0", "pc1",
]

SKIP_TAILS = {
    "CLK_PERIOD", "TB_RESET_PC", "RESET_PC", "TB_FIELD_VAL_W",
    "pass_cnt", "fail_cnt", "prev_pc0", "prev_pc1", "prev_is_spec",
    "pc0_next", "pc1_next", "pc0_a", "pc1_a", "stall",
    "ILEN", "RLEN", "NUM_GPR", "ADDR_UNIT_BITS", "I_SIZE", "M_SIZE",
    "PC_INDEX_AW", "OPC_OP", "OPC_OP_IMM", "OPC_LOAD", "OPC_STORE",
    "OPC_BRANCH", "OPC_JAL", "OPC_JALR", "OPC_AUIPC", "OPC_LUI",
    "F3_ADD_SUB", "F3_SLL", "F3_SLT", "F3_XOR", "F3_SRL_SRA", "F3_OR",
    "F3_AND", "F3_LW", "F3_SW", "F3_BEQ", "F3_BNE", "F3_BLT", "F3_BGE",
    "F7_SUB", "F7_SRA",
}

SKIP_SCOPE_PARTS = {"rv_dis_pkg"}

ALIASES = {
    "pc0_out": ("pc0_out", "pc0"),
    "pc1_out": ("pc1_out", "pc1"),
    "stall": ("fetch_stall", "stall", "stall_id"),
    "rst_n": ("rst_n", "rst"),
}

ROW_H_DIGITAL = 26
ROW_H_BUS = 30
BUS_BAND_H = 16
BUS_CHAMFER = 7
PX_PER_NS = 12
MARGIN_L = 200
MARGIN_R = 24
MARGIN_TOP = 36
MARGIN_BOT = 24

# GTKWave palette (match interactive viewer)
BG = "#000000"
NAME_BG = "#000000"
GRID = "#0c1e3a"
RULER_BG = "#0a1530"
DIVIDER = "#284070"
TRACE = "#00ff00"
NAME_FG = "#ffffff"
VAL_FG = "#ffffff"
TIME_FG = "#8fa8c8"
CURSOR = "#ff0000"

def parse_vcd(path):
    signals = {}
    order = []
    cur_scope = []
    timescale_ps = 1

    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("$timescale"):
                blob = line
                m = re.search(r"(\d+)\s*(fs|ps|ns|us|ms|s)", blob)
                if not m:
                    nxt = f.readline()
                    blob = line + " " + (nxt or "")
                    m = re.search(r"(\d+)\s*(fs|ps|ns|us|ms|s)", blob)
                if m:
                    n, unit = int(m.group(1)), m.group(2)
                    scale = {"fs": 0.001, "ps": 1, "ns": 1000, "us": 1e6, "ms": 1e9, "s": 1e12}
                    timescale_ps = n * scale[unit]
            elif line.startswith("$scope"):
                parts = line.split()
                if len(parts) >= 3:
                    cur_scope.append(parts[2])
            elif line.startswith("$upscope"):
                if cur_scope:
                    cur_scope.pop()
            elif line.startswith("$var"):
                parts = line.split()
                width = int(parts[2])
                vid = parts[3]
                name = parts[4]
                full = ".".join(cur_scope + [name])
                signals[vid] = {"name": full, "width": width, "tv": []}
                order.append(vid)
            elif line.startswith("$enddefinitions"):
                break

    with open(path, encoding="utf-8", errors="replace") as f:
        in_defs = False
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("$enddefinitions"):
                in_defs = True
                continue
            if not in_defs:
                continue
            if line[0] == "#":
                time = int(line[1:])
            elif line[0] == "b":
                space = line.rfind(" ")
                if space > 1:
                    val = line[1:space]
                    vid = line[space + 1 :]
                    if vid in signals:
                        signals[vid]["tv"].append((time, val))
            elif line[0] in "01xXzZ":
                val = line[0]
                vid = line[1:]
                if vid in signals:
                    signals[vid]["tv"].append((time, val))

    return signals, order, timescale_ps


def in_dut(name):
    return any(part == "dut" for part in name.split("."))


def skip_signal(name, tail):
    if any(part in SKIP_SCOPE_PARTS for part in name.split(".")):
        return True
    if tail in SKIP_TAILS:
        return True
    if not in_dut(name):
        return True
    return False


def signal_changes(tv):
    if not tv:
        return False
    return len({v for _, v in tv}) > 1


def resolve_dut(signals, order, want_tails):
    by_tail = {}
    for vid in order:
        name = signals[vid]["name"]
        if skip_signal(name, name.split(".")[-1]):
            continue
        tail = name.split(".")[-1]
        by_tail.setdefault(tail, []).append(vid)

    out = []
    for tail in want_tails:
        cands = []
        for key in ALIASES.get(tail, (tail,)):
            cands.extend(by_tail.get(key, []))
        if not cands:
            out.append(None)
            continue
        best = cands[0]
        for vid in cands:
            if in_dut(signals[vid]["name"]):
                best = vid
                break
        out.append(best)
    return out


def pick_extra_signals(signals, order, exclude_vids, max_n=16):
    labels = []
    vids = []
    for vid in order:
        if len(labels) >= max_n:
            break
        if vid in exclude_vids or not signals[vid]["tv"]:
            continue
        name = signals[vid]["name"]
        tail = name.split(".")[-1]
        if skip_signal(name, tail) or not signal_changes(signals[vid]["tv"]):
            continue
        labels.append(tail)
        vids.append(vid)
    return labels, vids


def signal_prefs(tb_top):
    if tb_top in TB_PAGES:
        prefs = []
        for _, _, want in TB_PAGES[tb_top]:
            prefs.extend(want)
        return prefs
    return list(DEFAULT_PREFS)


def pick_all_signals(signals, order, tb_top):
    seen = set()
    labels = []
    vids = []

    for pref in signal_prefs(tb_top):
        if pref in seen:
            continue
        seen.add(pref)
        vid = resolve_dut(signals, order, [pref])[0]
        if vid is None or vid in vids or not signals[vid]["tv"]:
            continue
        labels.append(pref)
        vids.append(vid)

    extra_labels, extra_vids = pick_extra_signals(signals, order, set(vids), max_n=32)
    for label, vid in zip(extra_labels, extra_vids):
        if vid not in vids:
            labels.append(label)
            vids.append(vid)

    return labels, vids


def expand_tv(tv, t_end):
    if not tv:
        return []
    out = []
    prev_t, prev_v = tv[0]
    out.append((prev_t, prev_v))
    for t, v in tv[1:]:
        out.append((t, prev_v))
        out.append((t, v))
        prev_v = v
    out.append((t_end, prev_v))
    return out


def bus_holds(tv, t_end):
    if not tv:
        return []
    holds = []
    for i, (t, v) in enumerate(tv):
        t_next = tv[i + 1][0] if i + 1 < len(tv) else t_end
        holds.append((t, t_next, v))
    return holds


def bus_segment_hex_points(x0, x1, yc, band_h=BUS_BAND_H, chamfer=BUS_CHAMFER):
    w = x1 - x0
    cf = min(chamfer, max(0, (w - 4) / 2))
    yt = yc - band_h / 2
    yb = yc + band_h / 2
    if cf < 1:
        return [(x0, yt), (x1, yt), (x1, yb), (x0, yb)]
    return [
        (x0 + cf, yt),
        (x1 - cf, yt),
        (x1, yc),
        (x1 - cf, yb),
        (x0 + cf, yb),
        (x0, yc),
    ]


def sidebar_name(label, width):
    if width > 1:
        return f"{label}[{width - 1}:0]"
    return label


def sidebar_val(v, width):
    if width == 1:
        return v if v in "01" else v
    return hex_val_gtk(v, width)


def detect_grid_step_ns(signals, vids, timescale_ps):
    for vid in vids:
        if not vid or signals[vid]["width"] != 1:
            continue
        tail = signals[vid]["name"].split(".")[-1]
        if tail != "clk":
            continue
        tv = signals[vid]["tv"]
        rises = []
        prev = None
        for t, v in tv:
            if v in "1hH" and prev not in ("1", "h", "H"):
                rises.append(t)
            prev = v
        if len(rises) >= 2:
            period_ps = rises[1] - rises[0]
            return max(1.0, (period_ps * timescale_ps) / 1000.0)
    return None


def grid_step_ns(t_end_ns, clk_period_ns=None):
    if clk_period_ns and clk_period_ns > 0:
        return clk_period_ns
    if t_end_ns <= 100:
        return 10
    if t_end_ns <= 500:
        return 50
    if t_end_ns <= 2000:
        return 100
    return 500


def hex_val_gtk(v, width):
    if v in ("x", "X"):
        return "x"
    if v in ("z", "Z"):
        return "z"
    try:
        n = int(v, 2) & ((1 << width) - 1)
        hex_digits = max(1, (width + 3) // 4)
        return f"{n:0{hex_digits}x}"
    except ValueError:
        return "?"


def row_height(width):
    return ROW_H_DIGITAL if width == 1 else ROW_H_BUS


def plot_width_px(t_end, timescale_ps):
    t_end_ns = (t_end * timescale_ps) / 1000.0
    plot_w = max(400, int(t_end_ns * PX_PER_NS))
    return MARGIN_L + plot_w + MARGIN_R


def render_svg(signals, vids, labels, t_end, timescale_ps, out_path, title):
    width = plot_width_px(t_end, timescale_ps)
    row_heights = [row_height(signals[vid]["width"] if vid else 1) for vid in vids]
    plot_h = sum(row_heights)
    height = MARGIN_TOP + plot_h + MARGIN_BOT
    plot_w = width - MARGIN_L - MARGIN_R
    t_end_ns = (t_end * timescale_ps) / 1000.0
    clk_period_ns = detect_grid_step_ns(signals, vids, timescale_ps)
    step_ns = grid_step_ns(t_end_ns, clk_period_ns)

    def x(t):
        return MARGIN_L + (t / max(t_end, 1)) * plot_w

    def x_ns(ns):
        return MARGIN_L + (ns / max(t_end_ns, 1e-9)) * plot_w

    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">',
        f'<rect width="100%" height="100%" fill="{BG}"/>',
        f'<rect x="{MARGIN_L}" y="0" width="{plot_w}" height="{MARGIN_TOP - 4}" fill="{RULER_BG}"/>',
        f'<line x1="{MARGIN_L}" y1="{MARGIN_TOP - 1}" x2="{width - MARGIN_R}" y2="{MARGIN_TOP - 1}" '
        f'stroke="{DIVIDER}" stroke-width="1"/>',
        f'<line x1="{MARGIN_L}" y1="0" x2="{MARGIN_L}" y2="{height}" stroke="{DIVIDER}" stroke-width="1"/>',
    ]

    t_mark = 0.0
    while t_mark <= t_end_ns + 1e-9:
        xm = x_ns(t_mark)
        lines.append(
            f'<line x1="{xm:.1f}" y1="{MARGIN_TOP}" x2="{xm:.1f}" y2="{height - MARGIN_BOT}" '
            f'stroke="{GRID}" stroke-width="1"/>'
        )
        t_mark += step_ns

    cursor_x = x_ns(step_ns * 0.5) if t_end_ns > step_ns else x(0)
    lines.append(
        f'<line x1="{cursor_x:.1f}" y1="{MARGIN_TOP}" x2="{cursor_x:.1f}" y2="{height - MARGIN_BOT}" '
        f'stroke="{CURSOR}" stroke-width="1"/>'
    )

    y0 = MARGIN_TOP
    for vid, label, rh in zip(vids, labels, row_heights):
        yc_row = y0 + rh / 2
        y_hi = y0 + 5
        y_lo = y0 + rh - 5
        lines.append(
            f'<line x1="{MARGIN_L}" y1="{y0 + rh}" x2="{width - MARGIN_R}" y2="{y0 + rh}" '
            f'stroke="{GRID}" stroke-width="1"/>'
        )

        if vid is None:
            lines.append(
                f'<text x="4" y="{yc_row + 4}" fill="{NAME_FG}" font-family="monospace" font-size="10">'
                f'{label}</text>'
            )
            y0 += rh
            continue

        sig = signals[vid]
        w = sig["width"]
        v0 = sig["tv"][0][1] if sig["tv"] else "?"
        sname = sidebar_name(label, w)
        sval = sidebar_val(v0, w)
        lines.append(
            f'<text x="4" y="{yc_row + 4}" fill="{NAME_FG}" font-family="monospace" font-size="10">'
            f'{sname}={sval}</text>'
        )

        if not sig["tv"]:
            y0 += rh
            continue

        if w == 1:
            tv = expand_tv(sig["tv"], t_end)
            pts = []
            for t, v in tv:
                yn = y_hi if v in "1hH" else y_lo
                pts.append(f"{x(t):.1f},{yn:.1f}")
            if len(pts) >= 2:
                lines.append(
                    f'<polyline fill="none" stroke="{TRACE}" stroke-width="1.5" '
                    f'points="{" ".join(pts)}"/>'
                )
        else:
            yc = yc_row
            for t0, t1, v in bus_holds(sig["tv"], t_end):
                x0, x1 = x(t0), x(t1)
                if x1 - x0 < 2:
                    continue
                pts = bus_segment_hex_points(x0, x1, yc)
                pt_str = " ".join(f"{px:.1f},{py:.1f}" for px, py in pts)
                lines.append(
                    f'<polygon fill="none" stroke="{TRACE}" stroke-width="1.5" points="{pt_str}"/>'
                )
                txt = hex_val_gtk(v, w)
                if x1 - x0 >= 36:
                    lines.append(
                        f'<text text-anchor="middle" x="{(x0 + x1) / 2:.1f}" y="{yc + 4:.1f}" '
                        f'fill="{VAL_FG}" font-family="monospace" font-size="9">{txt}</text>'
                    )
        y0 += rh

    lines.append("</svg>")
    Path(out_path).write_text("\n".join(lines), encoding="utf-8")

def t_end_for_vids(signals, vids):
    t_end = 0
    for vid in vids:
        if vid and signals[vid]["tv"]:
            t_end = max(t_end, signals[vid]["tv"][-1][0])
    if t_end == 0:
        t_end = 1
    return int(t_end * 1.02) + 1


def resolve_out_path(out_arg):
    if out_arg.suffix.lower() == ".svg":
        return out_arg, out_arg.parent
    out_arg.mkdir(parents=True, exist_ok=True)
    return out_arg / "waveform.svg", out_arg


def cleanup_stale_outputs(out_dir):
    for old in out_dir.glob("waveform_*.svg"):
        old.unlink()
    index = out_dir / "waveform_index.html"
    if index.exists():
        index.unlink()


def main():
    vcd_path = Path(sys.argv[1])
    out_arg = Path(sys.argv[2])
    tb_top = sys.argv[3] if len(sys.argv) > 3 else vcd_path.parent.name

    out_path, out_dir = resolve_out_path(out_arg)
    out_dir.mkdir(parents=True, exist_ok=True)
    cleanup_stale_outputs(out_dir)

    signals, order, timescale_ps = parse_vcd(vcd_path)
    labels, vids = pick_all_signals(signals, order, tb_top)
    if not vids:
        print("error: no DUT signals found in VCD", file=sys.stderr)
        sys.exit(1)

    t_end = t_end_for_vids(signals, vids)
    render_svg(
        signals, vids, labels, t_end, timescale_ps, out_path,
        title=f"{tb_top} — DUT",
    )
    t_end_ns = (t_end * timescale_ps) / 1000.0
    width = plot_width_px(t_end, timescale_ps)
    print(f"Wrote {out_path} ({width}px wide, {t_end_ns:.0f} ns, {len(labels)} signals)")


if __name__ == "__main__":
    main()
