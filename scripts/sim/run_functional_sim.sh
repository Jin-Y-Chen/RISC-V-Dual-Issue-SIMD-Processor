#!/usr/bin/env bash
# Functional Verilator sim on raw rtl/ + tb/ SystemVerilog.
# Usage: run_functional_sim.sh <top> [--trace] [--svg] [--rebuild]
set -euo pipefail

SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SIM_DIR/../.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SIM_DIR/../lib/common.sh"
# shellcheck source=tb_sources.sh
. "$SIM_DIR/tb_sources.sh"

usage() {
  cat <<'EOF'
Usage: run_functional_sim.sh <top> [--trace] [--svg] [--rebuild]

Compile and run a self-checking testbench with Verilator.
Default: sim/verilator/<top>/{compile.log,sim.log} only (no VCD/SVG).

  --trace   enable VCD dump -> sim/GTKWave/<top>/trace.vcd
  --svg     render waveform.svg (requires --trace)
  --rebuild force full Verilator recompile

Waveforms: ./scripts/sim/run_functional_sim.sh <top> --trace
           ./scripts/sim/open_waveform.sh <top>
           ./scripts/sim/gen_waveform.sh <top>
EOF
}

TOP=""
DO_TRACE=0
DO_SVG=0
FORCE_REBUILD=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --trace)   DO_TRACE=1; shift ;;
    --svg)     DO_SVG=1; shift ;;
    --rebuild) FORCE_REBUILD=1; shift ;;
    --no-svg)  shift ;;
    -*) echo "error: unknown option: $1" >&2; exit 1 ;;
    *)
      [[ -z "$TOP" ]] || { echo "error: unexpected: $1" >&2; exit 1; }
      TOP="$1"; shift ;;
  esac
done

[[ -n "$TOP" ]] || { echo "error: <top> required" >&2; usage >&2; exit 1; }
[[ "$DO_SVG" -eq 0 || "$DO_TRACE" -eq 1 ]] || {
  echo "error: --svg requires --trace" >&2
  exit 1
}

for cmd in verilator make g++; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "error: $cmd not found (sudo apt install -y build-essential verilator)" >&2
    exit 1
  }
done

mapfile -t SRCS < <(get_tb_sources "$TOP") || exit 1

VER_DIR="$ROOT/sim/verilator/$TOP"
WAVE_DIR="$ROOT/sim/GTKWave/$TOP"
CACHE_ROOT="$HOME/.cache/risc-dis-verilator/$TOP"
OBJ_DIR="$CACHE_ROOT/obj_dir"
SIM_LOG="$OBJ_DIR/sim.log"
mkdir -p "$VER_DIR"
[[ "$DO_TRACE" -eq 1 ]] && mkdir -p "$WAVE_DIR"

for name in compile.log sim.log; do rm -f "$VER_DIR/$name"; done
if [[ "$DO_TRACE" -eq 1 ]]; then
  for name in trace.vcd waveform.svg; do rm -f "$WAVE_DIR/$name"; done
  rm -f "$WAVE_DIR"/waveform_*.svg "$WAVE_DIR"/waveform_index.html
fi
for legacy in sim.vvp obj_dir; do rm -rf "$VER_DIR/$legacy"; done

QUOTED=()
for src in "${SRCS[@]}"; do
  [[ -f "$ROOT/$src" ]] || { echo "error: missing: $src" >&2; exit 1; }
  QUOTED+=("$ROOT/$src")
done

write_sources_stamp() {
  local out="$1"
  : > "$out"
  for src in "${SRCS[@]}"; do
    stat -c '%Y %n' "$ROOT/$src" >>"$out"
  done
  verilator --version 2>/dev/null | head -1 >>"$out" || true
  echo "trace=$DO_TRACE" >>"$out"
}

sources_unchanged() {
  local stamp="$CACHE_ROOT/sources.stamp"
  [[ -f "$stamp" ]] || return 1
  local tmp
  tmp="$(mktemp)"
  write_sources_stamp "$tmp"
  if cmp -s "$stamp" "$tmp"; then
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

NEED_COMPILE=1
if [[ "$FORCE_REBUILD" -eq 0 && -x "$OBJ_DIR/V$TOP" ]] && sources_unchanged; then
  NEED_COMPILE=0
fi

VERILATOR_ARGS=(
  --binary --timing --relative-includes
  -Wall -Wno-fatal -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM
  --top-module "$TOP" -Mdir "$OBJ_DIR"
)
if [[ "$DO_TRACE" -eq 1 ]]; then
  VERILATOR_ARGS+=(--trace +define+TRACE_VCD)
fi

if [[ "$NEED_COMPILE" -eq 1 ]]; then
  if [[ "$FORCE_REBUILD" -eq 1 ]]; then
    echo "Rebuilding $TOP (clean)..."
  else
    echo "Compiling $TOP with Verilator (first build ~30s from /mnt/c; progress below)..."
  fi
  rm -rf "$CACHE_ROOT"
  mkdir -p "$OBJ_DIR"
  cd "$ROOT"
  verilator "${VERILATOR_ARGS[@]}" "${QUOTED[@]}" 2>&1 | tee "$VER_DIR/compile.log"
  write_sources_stamp "$CACHE_ROOT/sources.stamp"
else
  echo "Using cached Verilator build for $TOP (sources unchanged)."
  echo "verilator: skipped (cache hit)" >"$VER_DIR/compile.log"
fi

if [[ "$NEED_COMPILE" -eq 1 ]] && grep -qE '(^ERROR:|%Error:)' "$VER_DIR/compile.log"; then
  echo "error: Verilator compile failed — $VER_DIR/compile.log" >&2
  exit 1
fi

if [[ ! -x "$OBJ_DIR/V$TOP" ]]; then
  echo "error: simulator binary missing: $OBJ_DIR/V$TOP (try --rebuild)" >&2
  exit 1
fi

echo "Running V$TOP..."
rm -f "$SIM_LOG" "$OBJ_DIR/trace.vcd" "$ROOT/trace.vcd"

if [[ "$TOP" == "instruction_cache_tb" ]]; then
  cp "$ROOT/tests/bin/demo_instructions.hex" "$OBJ_DIR/demo_instructions.hex"
fi

SIM_TIMEOUT="${SIM_TIMEOUT:-120}"
if ! timeout "$SIM_TIMEOUT" bash -c "cd '$OBJ_DIR' && './V$TOP' >'$SIM_LOG' 2>&1"; then
  cp "$SIM_LOG" "$VER_DIR/sim.log" 2>/dev/null || true
  if [[ ! -s "$SIM_LOG" ]]; then
    echo "error: V$TOP timed out or failed (${SIM_TIMEOUT}s) — try --rebuild" >&2
  else
    echo "error: V$TOP exited non-zero — $VER_DIR/sim.log" >&2
  fi
  exit 1
fi
cp "$SIM_LOG" "$VER_DIR/sim.log"
echo "V$TOP done ($(wc -l < "$SIM_LOG" | tr -d ' ') log lines)."

for artifact in "$OBJ_DIR"/*_final.txt; do
  if [[ -f "$artifact" ]]; then
    cp "$artifact" "$VER_DIR/"
    echo "OK    $(basename "$artifact"): $VER_DIR/$(basename "$artifact")"
  fi
done

if [[ "$DO_TRACE" -eq 1 ]]; then
  if [[ -f "$OBJ_DIR/trace.vcd" ]]; then
    cp "$OBJ_DIR/trace.vcd" "$WAVE_DIR/trace.vcd"
  elif [[ -f "$ROOT/trace.vcd" ]]; then
    cp "$ROOT/trace.vcd" "$WAVE_DIR/trace.vcd"
    rm -f "$ROOT/trace.vcd"
  fi
fi

if grep -qE '\[FAIL\]' "$VER_DIR/sim.log" || grep -qE '^\s*FAIL\b' "$VER_DIR/sim.log"; then
  echo "FAIL  $TOP — $VER_DIR/sim.log" >&2
  exit 1
fi

if [[ "$DO_SVG" -eq 1 && -f "$WAVE_DIR/trace.vcd" && -f "$SIM_DIR/vcd_to_svg.py" ]]; then
  if pick_python; then
    "${PYTHON_CMD[@]}" "$SIM_DIR/vcd_to_svg.py" "$WAVE_DIR/trace.vcd" "$WAVE_DIR" "$TOP"
  fi
fi

echo "OK    sim.log:     $VER_DIR/sim.log"
echo "OK    compile.log: $VER_DIR/compile.log"
if [[ "$DO_TRACE" -eq 1 && -f "$WAVE_DIR/trace.vcd" ]]; then
  echo "OK    trace.vcd:   $WAVE_DIR/trace.vcd"
fi
if [[ "$DO_SVG" -eq 1 && -f "$WAVE_DIR/waveform.svg" ]]; then
  echo "OK    waveform.svg: $WAVE_DIR/waveform.svg"
fi
