"""VCS adapter."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from .common import ROOT, SIM_DIR, sim_failed


def run(top: str, flist: Path, out: Path, plusargs: list[str], *, uvm: bool = False) -> int:
    del uvm
    if not shutil.which("vcs"):
        print("vcs not on PATH", file=__import__("sys").stderr)
        return 1

    out.mkdir(parents=True, exist_ok=True)
    log = out / "compile_run.log"
    work = SIM_DIR / "work" / "vcs" / top
    work.mkdir(parents=True, exist_ok=True)
    simv = work / "simv"

    log.write_text(f"=== vcs ===\ntop={top}\nflist={flist}\n", encoding="utf-8")

    with log.open("a", encoding="utf-8") as fh:
        rc = subprocess.run(
            [
                "vcs",
                "-full64",
                "-sverilog",
                "-ntb_opts",
                "uvm-1.2",
                "-f",
                str(flist),
                "-top",
                top,
                "-o",
                str(simv),
            ],
            cwd=str(ROOT),
            stdout=fh,
            stderr=subprocess.STDOUT,
            check=False,
        ).returncode
    if rc != 0:
        print(f"failed - see {log}", file=__import__("sys").stderr)
        return 1

    plus = [f"+{a}" for a in plusargs if a]
    with log.open("a", encoding="utf-8") as fh:
        subprocess.run(
            [str(simv), *plus],
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
