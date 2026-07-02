#!/usr/bin/env bash
# Shared helpers for run-sim, run-synth, and run-all.

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

Yosys elab + Verilator TB self-test. Requires verilator, make, g++ in WSL.

Examples:
  ./scripts/run-sim -TOP pc_tb
  ./scripts/run-sim --help

Output: synth/reports/runs/latest/<top>/sim.log
         sim/verilator/<top>/trace.vcd and waveform.svg (auto on pass)

More: ./scripts/lib/run_yosys.ps1 -Help   scripts/README.md
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
