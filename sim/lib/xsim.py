"""XSim / Vivado adapter (xvlog → xelab → xsim)."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from .common import ROOT, sim_failed

_MSYS_RE = re.compile(r"^/([a-zA-Z])/(.*)$")
_STAGE_ERR_RE = re.compile(r"^ERROR:|\[ERROR\]", re.M)


def win_path(path: str | Path) -> str:
    """Normalize to a path Vivado Windows tools accept."""
    p = str(path).replace("\\", "/")
    # Already a Windows drive path.
    if re.match(r"^[A-Za-z]:/", p):
        return p
    # /c/Users/... → C:/Users/...
    m = _MSYS_RE.match(p)
    if m:
        return f"{m.group(1).upper()}:{m.group(2) and '/' + m.group(2)}"
    # Native pathlib absolute on Windows.
    path_obj = Path(path)
    if path_obj.is_absolute():
        return str(path_obj.resolve()).replace("\\", "/")
    return p


def find_vivado_bin() -> Path | None:
    env = os.environ.get("VIVADO", "")
    if env:
        v = Path(env)
        if v.is_file():
            bin_dir = v.parent
            if (bin_dir / "xvlog.bat").is_file() or (bin_dir / "xvlog").is_file():
                return bin_dir

    xvlog = shutil.which("xvlog")
    if xvlog:
        return Path(xvlog).resolve().parent

    # Common Windows install roots (also visible under Git Bash as /c/...).
    candidates = []
    for root in (
        Path("C:/FPGA"),
        Path("C:/Xilinx/Vivado"),
        Path("/c/FPGA"),
        Path("/c/Xilinx/Vivado"),
    ):
        if not root.exists():
            continue
        if root.name.lower() == "vivado":
            candidates.extend(root.glob("*/bin/vivado.bat"))
        else:
            candidates.extend(root.glob("*/Vivado/bin/vivado.bat"))

    for vivado in candidates:
        bin_dir = vivado.parent
        if (bin_dir / "xvlog.bat").is_file() or (bin_dir / "xvlog").is_file():
            return bin_dir
    return None


def _tool(bin_dir: Path, name: str) -> Path:
    bat = bin_dir / f"{name}.bat"
    if bat.is_file():
        return bat
    return bin_dir / name


def plusarg_normalize(arg: str, out: Path) -> str:
    if "=" not in arg:
        return arg
    key, val = arg.split("=", 1)
    if not val:
        return arg
    if not Path(val).is_absolute() and not re.match(r"^[A-Za-z]:", val):
        val = str(out / val)
    return f"{key}={win_path(val)}"


def _ui_rel(path: str, root: Path) -> str:
    p = path.replace("\\", "/")
    root_s = str(root).replace("\\", "/")
    root_w = win_path(root)
    if p.startswith(root_s + "/"):
        return p[len(root_s) + 1 :]
    if p.startswith(root_w + "/"):
        return p[len(root_w) + 1 :]
    return p


# UVM-layer headers for compile logging (compile order is unchanged).
_SRC_GROUP_ORDER = (
    "pkg",
    "dut",
    "model",
    "interface",
    "agent",
    "env",
    "sequence",
    "test",
    "tb_top",
    "other",
)


def _sv_src_group(rel: str) -> str:
    """Classify a source path into a UVM-layer compile group."""
    r = rel.replace("\\", "/")
    rl = r.lower()
    base = Path(rl).name

    # Finer UVM suite paths first (tb/uvm/...).
    if "/uvm/" in rl:
        if base.endswith("_pkg.sv") or "/pkg/" in rl:
            return "pkg"
        if "/agents/" in rl or base.endswith("_agent.sv"):
            return "agent"
        if "/env/" in rl or any(
            base.endswith(s)
            for s in ("_env.sv", "_scoreboard.sv", "_coverage.sv", "_refmodel.sv", "_env_cfg.sv")
        ):
            return "env"
        if "/seq/" in rl or "/sequences/" in rl or "sequence" in base:
            return "sequence"
        if "/test/" in rl or "/tests/" in rl or base.endswith("_tests.sv") or base.endswith("_test.sv"):
            return "test"
        if "/top/" in rl or base.endswith("_tb_top.sv") or base.endswith("_top.sv"):
            return "tb_top"
        if base.endswith("_if.sv") or "/interfaces/" in rl:
            return "interface"
        return "other"

    if (
        base.endswith("_pkg.sv")
        or "/import/" in rl
        or "/funct_pkg/" in rl
        or "/pkg/" in rl
    ):
        return "pkg"
    if "/dpi/" in rl or rl.endswith("_gm.sv") or "/shims/" in rl or "/model/" in rl:
        return "model"
    if rl.startswith("rtl/") or "/rtl/" in rl:
        return "dut"
    if base.endswith("_if.sv") or "/interfaces/" in rl:
        return "interface"
    if "/agents/" in rl or base.endswith("_agent.sv"):
        return "agent"
    if "/env/" in rl:
        return "env"
    if "/seq/" in rl or "/sequences/" in rl:
        return "sequence"
    if base.endswith("_tb_top.sv") or "/top/" in rl:
        return "tb_top"
    if "/tests/" in rl or base.endswith("_tb.sv") or base.endswith("_test.sv"):
        return "test"
    if rl.startswith("tb/"):
        return "other"
    return "other"


def _print_srcs_grouped(srcs: list[str], root: Path) -> None:
    """Print SV sources under UVM-layer headers (pkg/dut/model/test/...)."""
    err = __import__("sys").stderr
    buckets: dict[str, list[str]] = {g: [] for g in _SRC_GROUP_ORDER}
    for path in srcs:
        rel = _ui_rel(path, root)
        buckets[_sv_src_group(rel)].append(rel)
    for key in _SRC_GROUP_ORDER:
        files = buckets[key]
        if not files:
            continue
        print(f"      {key} ({len(files)}):", file=err)
        for rel in files:
            print(f"        * {rel}", file=err)


def _stage_has_error(toollog: Path) -> bool:
    if not toollog.is_file():
        return False
    return bool(_STAGE_ERR_RE.search(toollog.read_text(encoding="utf-8", errors="replace")))


def _run_capture(cmd: list[str], log: Path, cwd: Path) -> int:
    """Run a tool; append stdout/stderr to *log* (single copy — do not also append --log)."""
    with log.open("a", encoding="utf-8") as fh:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd),
            stdout=fh,
            stderr=subprocess.STDOUT,
            check=False,
        )
    return proc.returncode


def _run_toollog(cmd: list[str], toollog: Path, outlog: Path, cwd: Path) -> int:
    """Run a tool that writes --log itself; merge that file once into *outlog*."""
    proc = subprocess.run(
        cmd,
        cwd=str(cwd),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if toollog.is_file():
        with outlog.open("a", encoding="utf-8") as fh:
            fh.write(toollog.read_text(encoding="utf-8", errors="replace"))
    return proc.returncode


def run_vivado_sim(
    top: str,
    flist: Path,
    out: Path,
    plusargs: list[str],
    *,
    uvm: bool = False,
    dpi_cpp: list[str] | None = None,
) -> int:
    bin_dir = find_vivado_bin()
    if not bin_dir:
        print("Vivado bin not found (set VIVADO=.../vivado.bat)", file=__import__("sys").stderr)
        return 1

    out.mkdir(parents=True, exist_ok=True)
    log = out / "compile_run.log"
    log.write_text("", encoding="utf-8")

    srcs: list[str] = []
    incs: list[str] = []
    for raw in flist.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.split("#", 1)[0].strip().replace("\r", "")
        if not line:
            continue
        if line.startswith("+incdir+"):
            path = line[len("+incdir+") :]
            if not Path(path).is_absolute() and not re.match(r"^[A-Za-z]:", path):
                path = str(ROOT / path)
            incs.extend(["-i", win_path(path)])
        elif not line.startswith("-f"):
            path = line
            if not Path(path).is_absolute() and not re.match(r"^[A-Za-z]:", path):
                path = str(ROOT / path)
            srcs.append(win_path(path))

    if not srcs:
        print(f"no sources in filelist: {flist}", file=__import__("sys").stderr)
        return 1

    plus = [plusarg_normalize(a, out) for a in plusargs if a]
    sim_lib: list[str] = []
    if uvm or top.endswith("_tb_top") or os.environ.get("VIVADO_SIM_LIB"):
        lib = os.environ.get("VIVADO_SIM_LIB", "uvm")
        sim_lib = ["-L", lib]

    xvlog = _tool(bin_dir, "xvlog")
    xelab = _tool(bin_dir, "xelab")
    xsim = _tool(bin_dir, "xsim")
    xsc = _tool(bin_dir, "xsc")

    dpi_cpp = dpi_cpp or []
    dpi_lib_name = f"{top}_dpi"
    dpi_lib_base = out / dpi_lib_name  # persist outside temp build dir

    with tempfile.TemporaryDirectory(prefix="riscv-sim.") as build_s:
        build = Path(build_s)
        scratch = build / ".scratch"
        scratch.mkdir(parents=True, exist_ok=True)

        if dpi_cpp:
            print(file=__import__("sys").stderr)
            print(
                f"[0/3] xsc  - Compiling {len(dpi_cpp)} C++ DPI source(s) → {dpi_lib_name}",
                file=__import__("sys").stderr,
            )
            with log.open("a", encoding="utf-8") as fh:
                fh.write(f"\n=== xsc ({len(dpi_cpp)} cpp) ===\n")

            cpp_abs: list[str] = []
            include_dirs: set[str] = set()
            for p in dpi_cpp:
                path = Path(p)
                if not path.is_absolute() and not re.match(r"^[A-Za-z]:", str(path)):
                    path = ROOT / path
                path = path.resolve()
                cpp_abs.append(win_path(path))
                include_dirs.add(win_path(path.parent))
                print(f"        * {_ui_rel(str(path), ROOT)}", file=__import__("sys").stderr)

            gcc_opts: list[str] = []
            # Always expose model/ so includes like "common/types.hpp" and "s1_fetch/..." resolve.
            for inc in (ROOT / "model", ROOT / "model" / "common"):
                gcc_opts.extend(["--gcc_compile_options", f"-I{win_path(inc)}"])
            for inc in sorted(include_dirs):
                gcc_opts.extend(["--gcc_compile_options", f"-I{inc}"])

            # Windows DPI libs are .a archives; Linux uses .so (--shared).
            shared_flag = "--shared"

            # Compile objects into out/xsim.dir/... then link shared lib into out/.
            cmd_c = [
                str(xsc),
                "-c",
                *cpp_abs,
                "--cppversion",
                "14",
                *gcc_opts,
            ]
            rc = _run_capture(cmd_c, log, out)
            if rc != 0:
                return 1

            # Explicit object list — Windows shells do not expand xsc's *.obj glob.
            obj_dir = out / "xsim.dir" / "work" / "xsc"
            objs = sorted(obj_dir.glob("*.obj")) if obj_dir.is_dir() else []
            if not objs:
                print(f"xsc produced no object files under {obj_dir}", file=__import__("sys").stderr)
                return 1

            cmd_l = [
                str(xsc),
                shared_flag,
                "--cppversion",
                "14",
                "-o",
                win_path(dpi_lib_base),
                *[win_path(o) for o in objs],
            ]
            rc = _run_capture(cmd_l, log, out)
            if rc != 0:
                return 1

            lib_ok = any(
                Path(str(dpi_lib_base) + ext).is_file() for ext in (".a", ".so", ".dll", ".dylib", "")
            )
            if not lib_ok:
                print(
                    f"xsc did not produce shared library at {dpi_lib_base}",
                    file=__import__("sys").stderr,
                )
                return 1

        print(file=__import__("sys").stderr)
        print(
            f"[1/3] xvlog - Compiling {len(srcs)} SystemVerilog source(s) into the work library.",
            file=__import__("sys").stderr,
        )
        _print_srcs_grouped(srcs, ROOT)

        with log.open("a", encoding="utf-8") as fh:
            fh.write(f"\n=== xvlog ({len(srcs)} sources) ===\n")

        # Sources go in a -f filelist to avoid Windows CreateProcess length limits.
        # Keep -i include dirs on the command line (few, short); xvlog -f treats
        # "+incdir+..." lines as filenames on some Vivado builds.
        xvlog_f = scratch / "xvlog.f"
        xvlog_f.write_text("\n".join(srcs) + "\n", encoding="utf-8")

        xvlog_log = scratch / "xvlog.log"
        cmd = [
            str(xvlog),
            "-sv",
            "--incr",
            "--relax",
            "-work",
            "work",
            *sim_lib,
            *incs,
            "-f",
            win_path(xvlog_f),
            "--log",
            win_path(xvlog_log),
        ]
        rc = _run_toollog(cmd, xvlog_log, log, build)
        if rc != 0 or _stage_has_error(xvlog_log):
            return 1

        print(file=__import__("sys").stderr)
        print(
            f"[2/3] xelab - Elaborating work.{top} and building simulation snapshot {top}_sim.",
            file=__import__("sys").stderr,
        )
        with log.open("a", encoding="utf-8") as fh:
            fh.write("\n=== xelab ===\n")

        xelab_log = scratch / "xelab.log"
        cmd = [
            str(xelab),
            f"work.{top}",
            *sim_lib,
            "-s",
            f"{top}_sim",
            "--log",
            win_path(xelab_log),
        ]
        if dpi_cpp:
            # xelab resolves -sv_lib relative to cwd (.a on Windows, .so on Linux).
            for ext in (".a", ".so", ".dll", ".dylib"):
                src = Path(str(dpi_lib_base) + ext)
                if src.is_file():
                    shutil.copy2(src, build / src.name)
            cmd.extend(["-sv_lib", dpi_lib_name])
        rc = _run_toollog(cmd, xelab_log, log, build)
        if rc != 0 or _stage_has_error(xelab_log):
            return 1

        print(file=__import__("sys").stderr)
        print(
            f"[3/3] xsim  - Running simulation snapshot {top}_sim to completion.",
            file=__import__("sys").stderr,
        )
        with log.open("a", encoding="utf-8") as fh:
            fh.write("\n=== xsim ===\n")

        xsim_log = scratch / "xsim.log"
        args_file = scratch / "xsim_args.txt"
        lines = [f"{top}_sim"]
        for arg in plus:
            lines.extend(["-testplusarg", arg])
        lines.extend(["-runall", "--log", win_path(xsim_log)])
        args_file.write_text("\n".join(lines) + "\n", encoding="utf-8")

        # Snapshot lives in temp build dir; DPI lib is absolute under results/.
        _run_toollog([str(xsim), "--file", win_path(args_file)], xsim_log, log, build)
        print(file=__import__("sys").stderr)

    return 0


def run(
    top: str,
    flist: Path,
    out: Path,
    plusargs: list[str],
    *,
    uvm: bool = False,
    dpi_cpp: list[str] | None = None,
) -> int:
    rc = run_vivado_sim(top, flist, out, plusargs, uvm=uvm, dpi_cpp=dpi_cpp)
    log = out / "compile_run.log"
    if rc != 0 or sim_failed(log):
        print(f"failed - see {log}", file=__import__("sys").stderr)
        return 1
    print(f"OK  {log}")
    return 0
