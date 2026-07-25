"""Xcelium adapter."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from .common import ROOT, SIM_DIR, sim_failed


def run(
    top: str,
    flist: Path,
    out: Path,
    plusargs: list[str],
    *,
    uvm: bool = False,
    dpi_cpp: list[str] | None = None,
) -> int:
    del uvm
    del dpi_cpp
    if not shutil.which("xrun"):
        print("xrun not on PATH", file=__import__("sys").stderr)
        return 1

    out.mkdir(parents=True, exist_ok=True)
    log = out / "compile_run.log"
    work = SIM_DIR / "work" / "xcelium" / top
    work.mkdir(parents=True, exist_ok=True)

    log.write_text(f"=== xcelium ===\ntop={top}\nflist={flist}\n", encoding="utf-8")
    plus = [f"+{a}" for a in plusargs if a]

    with log.open("a", encoding="utf-8") as fh:
        subprocess.run(
            [
                "xrun",
                "-64bit",
                "-uvm",
                "-uvmhome",
                "CDNS-1.2",
                "-sv",
                "-f",
                str(flist),
                "-top",
                top,
                "-xmlibdirname",
                str(work / "xcelium.d"),
                *plus,
            ],
            cwd=str(ROOT),
            stdout=fh,
            stderr=subprocess.STDOUT,
            check=False,
        )

    if sim_failed(log):
        print(f"failed - see {log}", file=__import__("sys").stderr)
        return 1
    print(f"OK  {log}")
    return 0
