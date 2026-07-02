#!/usr/bin/env python3
"""Minimal VCD -> SVG waveform plotter (stdlib only)."""
import re
import sys
from pathlib import Path


def parse_vcd(path):
    signals = {}
    order = []
    cur_scope = []
    cur_var = None
    cur_id = None
    time = 0

    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("$scope"):
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

    return signals, order


def val_num(v):
    if v in ("x", "X", "z", "Z"):
        return 0.0
    if len(v) == 1:
        return float(int(v, 2) if v in "01" else 0)
    try:
        return float(int(v, 2))
    except ValueError:
        return 0.0


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


def resolve(signals, order, want_tails):
    by_tail = {}
    for vid in order:
        name = signals[vid]["name"]
        tail = name.split(".")[-1]
        by_tail.setdefault(tail, []).append(vid)
    out = []
    aliases = {
        "rob_write_ptr":  ("write_ptr_q", "write_ptr", "rob_write_ptr"),
        "rob_read_ptr":   ("read_ptr_q", "read_ptr", "rob_read_ptr"),
        "rob_commit_ptr": ("commit_ptr_q", "commit_ptr", "rob_commit_ptr"),
        "br_inflight":    ("br_inflight_q", "br_inflight"),
    }
    for tail in want_tails:
        cands = []
        for key in aliases.get(tail, (tail,)):
            cands.extend(by_tail.get(key, []))
        if not cands:
            out.append(None)
            continue
        best = cands[0]
        for vid in cands:
            if ".dut." in signals[vid]["name"]:
                best = vid
                break
        out.append(best)
    return out


def pick_signals(signals, order, max_n=10):
    prefs = [
        "clk", "rst_n", "rst", "enable", "stall_id", "stall",
        "flush", "valid", "ready", "commit_en",
        "rob_write_ptr", "rob_read_ptr", "rob_commit_ptr", "br_inflight",
    ]
    labels = []
    vids = []
    for pref in prefs:
        if len(labels) >= max_n:
            break
        vid = resolve(signals, order, [pref])[0]
        if vid is not None and vid not in vids and signals[vid]["tv"]:
            labels.append(pref)
            vids.append(vid)
    for vid in order:
        if len(labels) >= max_n:
            break
        if vid in vids or not signals[vid]["tv"]:
            continue
        tail = signals[vid]["name"].split(".")[-1]
        labels.append(tail)
        vids.append(vid)
    return labels, vids


def render_svg(signals, vids, labels, t_end, out_path, title="Verilator VCD", width=1400, row_h=48):
    n = len(vids)
    height = 80 + n * row_h
    margin_l = 140
    margin_r = 20
    plot_w = width - margin_l - margin_r

    def x(t):
        return margin_l + (t / max(t_end, 1)) * plot_w

    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">',
        '<rect width="100%" height="100%" fill="#0f1117"/>',
        f'<text x="{margin_l}" y="28" fill="#e6e6e6" font-family="monospace" font-size="16">'
        f'{title}</text>',
    ]

    for i, (vid, label) in enumerate(zip(vids, labels)):
        y0 = 50 + i * row_h
        y_mid = y0 + row_h // 2
        lines.append(
            f'<text x="8" y="{y_mid + 4}" fill="#9cdcfe" font-family="monospace" font-size="11">{label}</text>'
        )
        lines.append(
            f'<line x1="{margin_l}" y1="{y0 + row_h - 8}" x2="{width - margin_r}" y2="{y0 + row_h - 8}" stroke="#333" />'
        )
        if vid is None:
            lines.append(
                f'<text x="{margin_l + 8}" y="{y_mid + 4}" fill="#666" font-family="monospace" font-size="11">(missing)</text>'
            )
            continue
        tv = expand_tv(signals[vid]["tv"], t_end)
        if not tv:
            continue
        pts = []
        for t, v in tv:
            yn = y_mid - val_num(v) * (row_h * 0.35)
            pts.append(f"{x(t):.1f},{yn:.1f}")
        if len(pts) >= 2:
            lines.append(
                f'<polyline fill="none" stroke="#4ec9b0" stroke-width="1.5" points="{" ".join(pts)}"/>'
            )

    lines.append(
        f'<text x="{margin_l}" y="{height - 12}" fill="#888" font-family="monospace" font-size="11">0 ns</text>'
    )
    lines.append(
        f'<text x="{width - margin_r - 80}" y="{height - 12}" fill="#888" font-family="monospace" font-size="11">{t_end / 1000:.0f} ns</text>'
    )
    lines.append("</svg>")

    Path(out_path).write_text("\n".join(lines), encoding="utf-8")


def main():
    vcd_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2])
    tb_top = sys.argv[3] if len(sys.argv) > 3 else vcd_path.stem
    signals, order = parse_vcd(vcd_path)
    labels, vids = pick_signals(signals, order)
    t_end_ps = 0
    for vid in vids:
        if vid and signals[vid]["tv"]:
            t_end_ps = max(t_end_ps, signals[vid]["tv"][-1][0])
    t_end_ns = t_end_ps / 1000.0
    render_svg(signals, vids, labels, t_end_ps, out_path, title=f"{tb_top} — Verilator VCD")
    print(f"Wrote {out_path} ({t_end_ns:.0f} ns, VCD timescale 1ps)")


if __name__ == "__main__":
    main()
