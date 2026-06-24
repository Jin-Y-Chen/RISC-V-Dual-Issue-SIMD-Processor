#!/usr/bin/env bash
# Run all unit TBs through Yosys (optional -Sim / -Synth via extra args).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

show_help_if_requested show_run_all_help "$@"

run_yosys_invoke -All "$@"
