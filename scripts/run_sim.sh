#!/usr/bin/env bash
# Verilator compile + TB self-test (-Sim). Requires verilator in WSL.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

show_help_if_requested show_run_sim_help "$@"

TOP="${TOP:-pc_tb}"
run_yosys_invoke -Top "$TOP" -Sim "$@"
