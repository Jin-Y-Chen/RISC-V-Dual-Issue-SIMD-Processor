#!/usr/bin/env bash
# Yosys elaboration (default) or per-top synthesis (-Synth). Run from repo root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

show_help_if_requested show_run_synth_help "$@"

parse_top_from_args "${TOP:-pc_tb}" "$@"
run_yosys_invoke -Top "$TOP_RESOLVED" "${FILTERED_ARGS[@]}"
