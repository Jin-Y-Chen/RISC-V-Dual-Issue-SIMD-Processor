#!/usr/bin/env bash
# Shared helpers for run-sim, run-synth, and run-all.

# Sets PYTHON_CMD to a working Python 3 (avoids Windows Store python3 stub).
pick_python() {
  PYTHON_CMD=()
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then
    PYTHON_CMD=(python3)
    return 0
  fi
  if command -v py >/dev/null 2>&1 && py -3 -c 'import sys' >/dev/null 2>&1; then
    PYTHON_CMD=(py -3)
    return 0
  fi
  return 1
}

# Windows PowerShell needs C:\... paths; WSL/Git Bash pass /mnt/c/... or /c/...
to_win_path() {
  local p="$1"
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$p"
  elif command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p"
  else
    printf '%s' "$p"
  fi
}

# Git Bash /c/... or WSL wslpath -> /mnt/c/... for `wsl bash -lc`.
to_wsl_path() {
  local p="$1"
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -a "$p"
    return
  fi
  if [[ "$p" =~ ^/[a-zA-Z]/ ]]; then
    printf '/mnt/%s%s' "$(printf '%s' "${p:1:1}" | tr '[:upper:]' '[:lower:]')" "${p:2}"
    return
  fi
  if command -v wsl >/dev/null 2>&1; then
    local win
    win="$(to_win_path "$p")"
    wsl wslpath -a "$win" 2>/dev/null && return
  fi
  printf '%s' "$p"
}

# True when already inside WSL (not Git Bash on Windows).
in_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

run_yosys_invoke() {
  local ps1="$ROOT/scripts/lib/run_yosys.ps1"
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
      -File "$(to_win_path "$ps1")" "$@"
  elif command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -File "$ps1" "$@"
  else
    echo "error: need powershell.exe (Windows) or pwsh in PATH" >&2
    exit 1
  fi
}

# Sets TOP_RESOLVED and FILTERED_ARGS from TOP env default + optional -Top/-TOP on CLI.
parse_top_from_args() {
  local default_top="$1"
  shift
  TOP_RESOLVED="$default_top"
  FILTERED_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -Top|-TOP|-top)
        if [[ $# -lt 2 ]]; then
          echo "error: $1 requires a testbench name" >&2
          exit 1
        fi
        TOP_RESOLVED="$2"
        shift 2
        ;;
      *)
        FILTERED_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

show_help_if_requested() {
  local script_name="$1"
  shift
  case "${1:-}" in
    -h|--help|help)
      "$script_name"
      exit 0
      ;;
  esac
}

show_run_synth_help() {
  cat <<'EOF'
Usage: ./scripts/run-synth [options]

Yosys elaboration on one testbench (default) or synthesis with extra flags.

Examples:
  ./scripts/run-synth -TOP pc_tb
  ./scripts/run-synth -TOP decoder_tb -Synth

More: ./scripts/lib/run_yosys.ps1 -Help   scripts/README.md
EOF
}

show_run_sim_help() {
  cat <<'EOF'
Usage: ./scripts/run-sim [options]

Verilator functional sim on raw rtl/ + tb/ (logs + GTKWave trace by default).

Examples:
  ./scripts/run-sim -TOP pc_tb
  ./scripts/run-sim -TOP pc_tb --rebuild
  ./scripts/run-sim -TOP pc_tb --no-trace
  ./scripts/run-sim --help

Options:
  --rebuild    force full Verilator recompile (ignore cache)
  --no-trace   logs only (skip trace.vcd / waveform.svg)
  --no-wave    alias for --no-trace
  --no-svg     keep trace.vcd, skip waveform.svg

Output:
  sim/verilator/<top>/{compile.log,sim.log}
  sim/GTKWave/<top>/{trace.vcd,waveform.svg}   (unless --no-trace)

GTKWave: ./scripts/sim/open_waveform.sh <top>

Timing: first compile ~30–45s from Git Bash/WSL on /mnt/c; cached reruns ~1–2s.

More: sim/README.md
EOF
}

show_run_all_help() {
  cat <<'EOF'
Usage: ./scripts/run-all [options]

Run all unit testbenches through Yosys (15 tops).

Examples:
  ./scripts/run-all
  ./scripts/run-all -Synth

More: ./scripts/lib/run_yosys.ps1 -Help   scripts/README.md
EOF
}
