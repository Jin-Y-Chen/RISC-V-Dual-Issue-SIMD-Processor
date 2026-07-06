#!/usr/bin/env bash
# Open trace.vcd in GTKWave (interactive waveform window).
# Usage: open_waveform.sh <top> [vcd_path]
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPTS/../.." && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPTS/../lib/common.sh"

TOP="${1:?usage: open_waveform.sh <top> [vcd_path]}"
VCD="${2:-$ROOT/sim/GTKWave/$TOP/trace.vcd}"

run_sim_with_trace() {
  echo "[INFO] Generating trace.vcd via ./scripts/run-sim -TOP $TOP"
  "$ROOT/scripts/run-sim" -TOP "$TOP"
}

try_copy_cache_vcd() {
  local cache_vcd=""
  if in_wsl; then
    cache_vcd="$HOME/.cache/risc-dis-verilator/$TOP/obj_dir/trace.vcd"
  elif command -v wsl >/dev/null 2>&1; then
    cache_vcd="$(wsl bash -lc "printf '%s' \"\$HOME/.cache/risc-dis-verilator/$TOP/obj_dir/trace.vcd\"")"
  fi
  if [[ -n "$cache_vcd" && -f "$cache_vcd" ]]; then
    mkdir -p "$(dirname "$VCD")"
    cp "$cache_vcd" "$VCD"
    echo "[INFO] Restored trace.vcd from Verilator cache"
    return 0
  fi
  return 1
}

ensure_vcd() {
  if [[ -f "$VCD" ]]; then
    return 0
  fi
  try_copy_cache_vcd || true
  if [[ -f "$VCD" ]]; then
    return 0
  fi
  run_sim_with_trace
  if [[ -f "$VCD" ]]; then
    return 0
  fi
  echo "error: VCD not found after sim: $VCD" >&2
  echo "  try: ./scripts/run-sim -TOP $TOP --rebuild" >&2
  exit 1
}

run_gtkwave_in_wsl() {
  local wvcd="$1"
  if in_wsl; then
    command -v gtkwave >/dev/null 2>&1 || {
      echo "error: gtkwave not found in WSL (sudo apt install -y gtkwave)" >&2
      exit 1
    }
    exec gtkwave "$wvcd"
  elif command -v wsl >/dev/null 2>&1; then
    wvcd="$(to_wsl_path "$VCD")"
    wsl bash -lc "command -v gtkwave >/dev/null 2>&1 || { echo 'error: gtkwave not found in WSL — run: wsl sudo apt install -y gtkwave' >&2; exit 1; }; exec gtkwave '$wvcd'"
  elif command -v gtkwave >/dev/null 2>&1; then
    exec gtkwave "$VCD"
  else
    echo "error: need WSL with gtkwave, or gtkwave in PATH" >&2
    echo "  install in WSL: wsl sudo apt install -y gtkwave" >&2
    exit 1
  fi
}

ensure_vcd
run_gtkwave_in_wsl "$VCD"
