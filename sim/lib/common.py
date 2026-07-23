"""Shared helpers for the Python simulation control panel."""

from __future__ import annotations

import json
import os
import re
import shutil
from pathlib import Path
from typing import Any

SIM_DIR = Path(__file__).resolve().parent.parent
ROOT = SIM_DIR.parent
PROJECT_FLIST = ROOT / ".slang" / "project.f"

UVM_SUITES: dict[str, dict[str, str]] = {
    "rename_uvm": {
        "flist": "sim/filelists/uvm/rename.f",
        "top": "rename_tb_top",
        "default_test": "rename_smoke_test",
    },
}

FAIL_RE = re.compile(
    r"\[FAIL\]|"
    r"SUMMARY:.*[1-9][0-9]* failed|"
    r"UVM_ERROR\s*:|"
    r"UVM_FATAL\s*:|"
    r"UVM_ERROR\s+[1-9]|"
    r"UVM_FATAL\s+[1-9]"
)


def abs_path(path: str | Path) -> Path:
    p = Path(path)
    if p.is_absolute():
        return p
    return (ROOT / p).resolve()


def results_dir_for(target: str, sim: str) -> Path:
    return SIM_DIR / "results" / target / sim


def is_uvm_target(name: str) -> bool:
    return name in UVM_SUITES


def list_directed_tops() -> list[str]:
    tops: list[str] = []
    if not PROJECT_FLIST.is_file():
        return tops
    for raw in PROJECT_FLIST.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.split("#", 1)[0].strip().replace("\r", "")
        if not line.endswith("_tb.sv"):
            continue
        tops.append(Path(line).stem)
    return tops


def list_uvm_suites() -> list[tuple[str, str, str]]:
    rows = []
    for name, info in sorted(UVM_SUITES.items()):
        rows.append((name, info["top"], info["default_test"]))
    return rows


def sim_failed(log: Path) -> bool:
    if not log.is_file():
        return False
    text = log.read_text(encoding="utf-8", errors="replace")
    return bool(FAIL_RE.search(text))


_SUMMARY_RE = re.compile(r"\*\*\* SUMMARY: (\d+) passed, (\d+) (?:failed|FAILED)")
_UVM_COUNT_RE = re.compile(r"^(UVM_ERROR|UVM_FATAL)\s*:\s*(\d+)", re.M)


def pass_fail_counts(log: Path) -> tuple[int, int] | None:
    """Extract (passed, failed) from a run log, or None if no summary found.

    Prefers the directed-TB `*** SUMMARY ***` line; falls back to counting
    [PASS]/[FAIL] markers, then to the UVM report-server error totals.
    """
    if not log.is_file():
        return None
    text = log.read_text(encoding="utf-8", errors="replace")

    m = None
    for m in _SUMMARY_RE.finditer(text):
        pass  # keep last summary line
    if m:
        return int(m.group(1)), int(m.group(2))

    n_pass = len(re.findall(r"\[PASS\]", text))
    n_fail = len(re.findall(r"\[FAIL\]", text))
    if n_pass or n_fail:
        return n_pass, n_fail

    uvm = {k: int(v) for k, v in _UVM_COUNT_RE.findall(text)}
    if uvm:
        return 0, uvm.get("UVM_ERROR", 0) + uvm.get("UVM_FATAL", 0)
    return None


def expand_placeholders(value: str, mapping: dict[str, str]) -> str:
    out = value
    for key, val in mapping.items():
        out = out.replace(f"${{{key}}}", val)
        out = out.replace(f"${key}", val)
    return out


def load_target_config(
    target: str,
    *,
    root: Path,
    out: Path,
    mem_file: str = "",
) -> dict[str, Any]:
    """Load sim/config/<target>.json with placeholder expansion."""
    cfg_path = SIM_DIR / "config" / f"{target}.json"
    data: dict[str, Any] = {
        "extra_sources": [],
        "plusargs": [],
        "artifacts": [],
        "dpi_cpp": [],
        "full": False,
    }
    if not cfg_path.is_file():
        return data

    raw = json.loads(cfg_path.read_text(encoding="utf-8"))
    mapping = {
        "ROOT": str(root).replace("\\", "/"),
        "OUT": str(out).replace("\\", "/"),
        "MEM_FILE": mem_file.replace("\\", "/")
        if mem_file
        else str(root / "program" / "bin" / "demo_instructions.mem").replace("\\", "/"),
    }

    for key in ("extra_sources", "plusargs", "artifacts", "dpi_cpp"):
        vals = raw.get(key, [])
        if not isinstance(vals, list):
            raise ValueError(f"{cfg_path}: '{key}' must be a list")
        data[key] = [expand_placeholders(str(v), mapping) for v in vals]

    data["full"] = bool(raw.get("full", False))
    return data


def doctor_report() -> None:
    print(f"Repo root: {ROOT}")
    print(f"Sim dir:   {SIM_DIR}")
    print(f"Project:   {PROJECT_FLIST}")
    print(f"project.f: {'OK' if PROJECT_FLIST.is_file() else 'MISSING'}")

    from . import xsim

    viv = xsim.find_vivado_bin()
    if viv:
        print(f"XSim/Vivado bin: {viv}")
    else:
        print("XSim/Vivado bin: not found (set VIVADO=.../vivado.bat)")

    for tool in ("vsim", "vcs", "xrun"):
        path = shutil.which(tool)
        print(f"{tool}: {path if path else 'not on PATH'}")

    print("UVM filelists:")
    for name, info in sorted(UVM_SUITES.items()):
        flist = ROOT / info["flist"]
        status = "OK" if flist.is_file() else "MISSING"
        print(f"  {name}: {status} ({info['flist']})")


def do_clean(target: str = "", sim: str = "") -> None:
    if target and sim:
        path = SIM_DIR / "results" / target / sim
        shutil.rmtree(path, ignore_errors=True)
        shutil.rmtree(SIM_DIR / "work" / sim / target, ignore_errors=True)
        print(f"cleaned {path}")
        return
    if target:
        path = SIM_DIR / "results" / target
        shutil.rmtree(path, ignore_errors=True)
        print(f"cleaned {path}")
        return
    if sim:
        results = SIM_DIR / "results"
        if results.is_dir():
            for child in results.iterdir():
                hit = child / sim
                if hit.is_dir():
                    shutil.rmtree(hit, ignore_errors=True)
        shutil.rmtree(SIM_DIR / "work" / sim, ignore_errors=True)
        print(f"cleaned results/*/{sim} and work/{sim}")
        return

    for name in ("results", "work", "out"):
        shutil.rmtree(SIM_DIR / name, ignore_errors=True)
    (SIM_DIR / "results").mkdir(parents=True, exist_ok=True)
    (SIM_DIR / "work").mkdir(parents=True, exist_ok=True)
    (SIM_DIR / "results" / ".gitkeep").touch()
    (SIM_DIR / "work" / ".gitkeep").touch()
    print("cleaned sim/results, sim/work")


def write_minimal_flist(
    dest: Path,
    top: str,
    extra_sources: list[str],
) -> None:
    stem = top[:-3] if top.endswith("_tb") else top
    extras = {Path(s).as_posix() for s in extra_sources}
    extra_bases = {Path(s).name for s in extra_sources}
    lines_out: list[str] = []

    for raw in PROJECT_FLIST.read_text(encoding="utf-8", errors="replace").splitlines():
        cleaned = raw.split("#", 1)[0].strip().replace("\r", "")
        if not cleaned:
            continue
        if cleaned.startswith("+incdir+"):
            lines_out.append(cleaned)
            continue
        if not cleaned.endswith(".sv"):
            continue
        base = Path(cleaned).name
        keep = False
        if cleaned.startswith("rtl/import/"):
            keep = True
        if base in {f"{stem}.sv", f"{stem}_gm.sv", f"{top}.sv"}:
            keep = True
        if cleaned in extras or base in extra_bases:
            keep = True
        if keep:
            lines_out.append(cleaned)

    dest.write_text("\n".join(lines_out) + ("\n" if lines_out else ""), encoding="utf-8")


def write_full_flist(dest: Path, top: str) -> None:
    lines_out: list[str] = []
    for raw in PROJECT_FLIST.read_text(encoding="utf-8", errors="replace").splitlines():
        cleaned = raw.split("#", 1)[0].strip().replace("\r", "")
        if cleaned.endswith("_tb.sv") and Path(cleaned).stem != top:
            continue
        # Preserve comments/blank? Keep non-empty original-ish cleaned lines only.
        if not cleaned and not raw.strip():
            continue
        if cleaned:
            lines_out.append(cleaned)
    dest.write_text("\n".join(lines_out) + ("\n" if lines_out else ""), encoding="utf-8")


def which_tool(name: str) -> str | None:
    return shutil.which(name)
