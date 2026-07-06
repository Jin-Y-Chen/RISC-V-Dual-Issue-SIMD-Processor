#!/usr/bin/env bash
# Re-render waveform.svg from trace.vcd in sim/GTKWave/<top>/ (no re-simulation).
# Usage: gen_waveform.sh <top> [vcd_path]
set -euo pipefail

SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SIM_DIR/../.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SIM_DIR/../lib/common.sh"

TOP="${1:?usage: gen_waveform.sh <top> [vcd_path]}"
VCD="${2:-$ROOT/sim/GTKWave/$TOP/trace.vcd}"
WAVE_DIR="$ROOT/sim/GTKWave/$TOP"

if [[ ! -f "$VCD" ]]; then
  echo "error: VCD not found: $VCD" >&2
  echo "  run: ./scripts/run-sim -TOP $TOP" >&2
  exit 1
fi

pick_python || { echo "error: python3 not found" >&2; exit 1; }

mkdir -p "$WAVE_DIR"
"${PYTHON_CMD[@]}" "$SIM_DIR/vcd_to_svg.py" "$VCD" "$WAVE_DIR" "$TOP"
