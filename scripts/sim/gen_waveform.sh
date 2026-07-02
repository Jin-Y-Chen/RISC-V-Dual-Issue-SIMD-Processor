#!/usr/bin/env bash
# Render waveform.svg from trace.vcd (produced by ./scripts/run-sim).
# Usage: gen_waveform.sh <top> [vcd_path]
set -euo pipefail

SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SIM_DIR/../.." && pwd)"
TOP="${1:?usage: gen_waveform.sh <top> [vcd_path]}"
VCD="${2:-$ROOT/sim/verilator/$TOP/trace.vcd}"
SVG="$ROOT/sim/verilator/$TOP/waveform.svg"

if [[ ! -f "$VCD" ]]; then
  echo "error: VCD not found: $VCD (run ./scripts/run-sim -TOP $TOP first)" >&2
  exit 1
fi

python3 "$SIM_DIR/vcd_to_svg.py" "$VCD" "$SVG" "$TOP"
echo "SVG: $SVG"
