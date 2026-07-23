"""Questa adapter."""

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
    del uvm  # always link UVM lib when available
    del dpi_cpp  # TODO: wire DPI-C when Questa flow is used
    for tool in ("vlib", "vmap", "vlog", "vsim"):
        if not shutil.which(tool):
            print(f"{tool} not on PATH", file=__import__("sys").stderr)
            return 1

    out.mkdir(parents=True, exist_ok=True)
    log = out / "compile_run.log"
    work = SIM_DIR / "work" / "questa" / top
    work.mkdir(parents=True, exist_ok=True)
    lib = work / "work"
    if lib.exists():
        shutil.rmtree(lib)

    log.write_text(f"=== questa ===\ntop={top}\nflist={flist}\n", encoding="utf-8")

    def append_run(cmd: list[str]) -> int:
        with log.open("a", encoding="utf-8") as fh:
            return subprocess.run(
                cmd, cwd=str(ROOT), stdout=fh, stderr=subprocess.STDOUT, check=False
            ).returncode

    if append_run(["vlib", str(lib)]) != 0:
        return 1
    if append_run(["vmap", "work", str(lib)]) != 0:
        return 1
    if append_run(["vlog", "-sv", "-L", "uvm", "-f", str(flist)]) != 0:
        return 1

    plus = [f"+{a}" for a in plusargs if a]
    append_run(
        [
            "vsim",
            "-c",
            "-L",
            "uvm",
            "-work",
            str(lib),
            top,
            *plus,
            "-do",
            "run -all; quit -f",
        ]
    )

    if sim_failed(log):
        print(f"failed - see {log}", file=__import__("sys").stderr)
        return 1
    print(f"OK  {log}")
    return 0
