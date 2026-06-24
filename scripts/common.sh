#!/usr/bin/env bash
# Shared helpers for run_*.sh wrappers.

run_yosys_invoke() {
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
      -File "$ROOT/scripts/run_yosys.ps1" "$@"
  else
    pwsh -NoProfile -File "$ROOT/scripts/run_yosys.ps1" "$@"
  fi
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
Usage: run_synth.sh [options]

Yosys elaboration on one testbench (default) or synthesis with extra flags.

Environment:
  TOP    Testbench top name (default: pc_tb)

Examples:
  ./scripts/run_synth.sh
  TOP=decoder_tb ./scripts/run_synth.sh
  ./scripts/run_synth.sh -Synth
  ./scripts/run_synth.sh -Top forward_unit_tb -Synth

Options are passed through to scripts/run_yosys.ps1 (-Top, -Synth, -Clean, …).
Run from repo root, or call ./scripts/run_synth.sh (not run_synth without path).

More flags: ./scripts/run_yosys.ps1 -Help   or   scripts/README.md
EOF
}

show_run_sim_help() {
  cat <<'EOF'
Usage: run_sim.sh [options]

Yosys elab + Verilator compile and TB self-test (-Sim). Requires verilator in WSL.

Environment:
  TOP    Testbench top name (default: pc_tb)

Examples:
  ./scripts/run_sim.sh
  TOP=pc_tb ./scripts/run_sim.sh
  ./scripts/run_sim.sh -Top decoder_tb

Output:
  synth/reports/runs/latest/<top>/sim.log   [PASS] / SUMMARY lines
  sim/verilator/<top>/                      Verilator build scratch

Run from repo root: ./scripts/run_sim.sh (not rum_sim or run_sim without ./).

More flags: ./scripts/run_yosys.ps1 -Help   or   scripts/README.md
EOF
}

show_run_all_help() {
  cat <<'EOF'
Usage: run_all.sh [options]

Run all unit testbenches through Yosys (15 tops). Missing sources are skipped.

Examples:
  ./scripts/run_all.sh
  ./scripts/run_all.sh -Synth
  ./scripts/run_all.sh -Sim

Extra args pass through to scripts/run_yosys.ps1.

More flags: ./scripts/run_yosys.ps1 -Help   or   scripts/README.md
EOF
}
