#!/usr/bin/env python3
"""Unified directed + UVM simulation control panel (Python)."""

from __future__ import annotations

import argparse
import os
import shutil
import sys
import tempfile
from pathlib import Path

# Allow `python sim/run.py` from repo root without installing a package.
_SIM_DIR = Path(__file__).resolve().parent
if str(_SIM_DIR) not in sys.path:
    sys.path.insert(0, str(_SIM_DIR))

from lib import questa, vcs, xcelium, xsim  # noqa: E402
from lib.common import (  # noqa: E402
    PROJECT_FLIST,
    ROOT,
    SIM_DIR,
    UVM_SUITES,
    abs_path,
    do_clean,
    doctor_report,
    is_uvm_target,
    list_directed_tops,
    list_uvm_suites,
    load_target_config,
    pass_fail_counts,
    results_dir_for,
    write_full_flist,
    write_minimal_flist,
)

ADAPTERS = {
    "xsim": xsim,
    "questa": questa,
    "vcs": vcs,
    "xcelium": xcelium,
}


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="python sim/run.py",
        description="Directed and UVM simulation control panel",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python sim/run.py pc_tb
  python sim/run.py rename_uvm --test rename_random_test
  python sim/run.py --list
  python sim/run.py doctor
  python sim/run.py clean
""",
    )
    p.add_argument("top", nargs="?", help="Directed top (*_tb) or UVM suite (e.g. rename_uvm)")
    p.add_argument("--list", action="store_true", help="List available tops / UVM suites")
    p.add_argument("--kind", choices=("directed", "uvm", "all"), default="all")
    p.add_argument("--sim", choices=tuple(ADAPTERS), default="xsim")
    p.add_argument("--test", dest="uvm_test", default="", help="UVM test name")
    p.add_argument("--verbosity", default="UVM_MEDIUM", help="UVM verbosity")
    p.add_argument("--flist", type=str, default="", help="Override file list")
    p.add_argument("--full", action="store_true", help="Directed: compile all RTL/GM from project.f")
    p.add_argument("--mem", type=str, default="", help="Set +imem_mem=<path>")
    p.add_argument(
        "--plusarg",
        action="append",
        default=[],
        metavar="K=V",
        help="Extra plusarg (repeatable)",
    )
    p.add_argument("--target", type=str, default="", help="Alias for top (used with clean)")
    p.add_argument(
        "extra",
        nargs="*",
        help="Extra plusargs (key=value)",
    )
    return p


def parse_args(argv: list[str] | None = None) -> tuple[argparse.Namespace, str, bool]:
    """Return (args, utility_command, sim_explicitly_set)."""
    argv = list(sys.argv[1:] if argv is None else argv)
    cmd = ""
    if argv and argv[0] in {"doctor", "clean"}:
        cmd = argv.pop(0)
    sim_set = any(a == "--sim" or a.startswith("--sim=") for a in argv)
    args = build_parser().parse_args(argv)
    if args.target and not args.top:
        args.top = args.target
    return args, cmd, sim_set


def cmd_list(kind: str) -> int:
    if kind in ("directed", "all"):
        print("Directed tops (.slang/project.f *_tb.sv):")
        for t in list_directed_tops():
            print(f"  {t}")
    if kind == "all":
        print()
    if kind in ("uvm", "all"):
        print("UVM suites:")
        for name, top, test in list_uvm_suites():
            print(f"  {name}  (top={top}, default_test={test})")
    return 0


def run_simulation(args: argparse.Namespace) -> int:
    top = args.top
    if not top:
        build_parser().print_help()
        return 1

    sim = args.sim
    adapter = ADAPTERS[sim]
    out = results_dir_for(top, sim)
    mem_file = str(abs_path(args.mem)) if args.mem else ""

    cfg = load_target_config(top, root=ROOT, out=out, mem_file=mem_file)
    plusargs: list[str] = list(cfg["plusargs"])
    artifacts: list[str] = list(cfg["artifacts"])
    extra_sources: list[str] = list(cfg["extra_sources"])
    dpi_cpp: list[str] = list(cfg.get("dpi_cpp", []))
    full = bool(args.full or cfg.get("full"))

    flist: Path | None = abs_path(args.flist) if args.flist else None
    tmp_flist: Path | None = None
    uvm = is_uvm_target(top)

    try:
        if uvm:
            info = UVM_SUITES[top]
            elab_top = info["top"]
            uvm_test = args.uvm_test or info["default_test"]
            if flist is None:
                flist = abs_path(info["flist"])
            plusargs.extend(
                [
                    f"UVM_TESTNAME={uvm_test}",
                    f"UVM_VERBOSITY={args.verbosity}",
                ]
            )
        else:
            elab_top = top
            if flist is None:
                fd, name = tempfile.mkstemp(prefix="riscv-sim-flist.", suffix=".f")
                os.close(fd)
                tmp_flist = Path(name)
                flist = tmp_flist
                if full:
                    write_full_flist(flist, top)
                else:
                    write_minimal_flist(flist, top, extra_sources)

        assert flist is not None
        if not flist.is_file():
            print(f"No filelist: {flist}", file=sys.stderr)
            return 1
        if not PROJECT_FLIST.is_file() and not uvm and not args.flist:
            print(f"Missing {PROJECT_FLIST}", file=sys.stderr)
            return 1

        out.mkdir(parents=True, exist_ok=True)

        if mem_file:
            plusargs.append(f"imem_mem={mem_file}")
        plusargs.extend(args.plusarg or [])
        plusargs.extend(args.extra or [])

        rc = adapter.run(elab_top, flist, out, plusargs, uvm=uvm, dpi_cpp=dpi_cpp)
        log = out / "compile_run.log"

        counts = pass_fail_counts(log)
        if counts is not None:
            passed, failed = counts
            print(f"    {passed} passed, {failed} failed")
        if rc != 0:
            return rc

        for art in artifacts:
            hit = out / art
            if hit.exists():
                print(f"    {hit}")
        return 0
    finally:
        if tmp_flist is not None:
            tmp_flist.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    args, cmd, sim_set = parse_args(argv)

    if args.list:
        return cmd_list(args.kind)
    if cmd == "doctor":
        doctor_report()
        return 0
    if cmd == "clean":
        if not args.top and not sim_set:
            do_clean("", "")
        elif not args.top:
            do_clean("", args.sim)
        elif not sim_set:
            do_clean(args.top, "")
        else:
            do_clean(args.top, args.sim)
        return 0

    return run_simulation(args)


if __name__ == "__main__":
    sys.exit(main())
