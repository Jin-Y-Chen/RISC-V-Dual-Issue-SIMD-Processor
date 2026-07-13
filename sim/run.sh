#!/usr/bin/env bash
# Vivado batch simulation runner.
set -euo pipefail

source "$(dirname "$0")/lib/vivado.sh"

SIM_DIR="$(sim_root)"
ROOT="$(repo_root)"
PROJECT_FLIST="${ROOT}/.slang/project.f"

TOP=""
FLIST=""
MEM_FILE=""
EXTRA_PLUSARGS=()
USER_FLIST=0
FULL=0

usage() {
  cat <<'EOF'
Usage: sim/run.sh <top> [options] [extra plusargs...]

Options:
  --list              List tops (*_tb.sv) in .slang/project.f
  --flist <path>      Override file list (default: filtered .slang/project.f)
  --full              Compile all RTL/GM from project.f (slow)
  --mem <path>        Set +imem_mem=<path>
  --plusarg <k=v>     Extra xsim -testplusarg (repeatable)
  -h, --help          This message

Default: compile only rtl/import + matching DUT/GM + <top>.sv (fast).
Optional: sim/config/<top>.env - PLUSARGS, ARTIFACTS, EXTRA_SRCS.

Outputs: sim/out/<top>/compile_run.log (+ ARTIFACTS). Vivado scratch uses a temp dir.
EOF
}

list_tops() {
  local line base
  local -a lines=()
  echo "Tops (.slang/project.f *_tb.sv):"
  mapfile -t lines < "$PROJECT_FLIST"
  for line in "${lines[@]}"; do
    line="${line%%#*}"
    line="${line//$'\r'/}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ "$line" == *_tb.sv ]] || continue
    base="$(basename "$line" .sv)"
    echo "  ${base}"
  done
}

# Minimal sources for <top>: +incdir+, rtl/import/*, DUT, GM, TB (+ EXTRA_SRCS).
write_minimal_flist() {
  local dest="$1" stem="${TOP%_tb}"
  local line trimmed base keep raw
  local -a lines=()
  : > "$dest"
  mapfile -t lines < "$PROJECT_FLIST"
  for line in "${lines[@]}"; do
    raw="$line"
    line="${line%%#*}"
    line="${line//$'\r'/}"
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -z "$trimmed" ]] && continue

    if [[ "$trimmed" == +incdir+* ]]; then
      printf '%s\n' "${raw//$'\r'/}" >> "$dest"
      continue
    fi
    [[ "$trimmed" == *.sv ]] || continue
    base="$(basename "$trimmed")"

    keep=0
    [[ "$trimmed" == rtl/import/* ]] && keep=1
    [[ "$base" == "${stem}.sv" || "$base" == "${stem}_gm.sv" || "$base" == "${TOP}.sv" ]] && keep=1
    for extra in "${EXTRA_SRCS[@]+"${EXTRA_SRCS[@]}"}"; do
      [[ "$trimmed" == "$extra" || "$base" == "$(basename "$extra")" ]] && keep=1
    done

    if [[ "$keep" -eq 1 ]]; then
      printf '%s\n' "${raw//$'\r'/}" >> "$dest"
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)   list_tops; exit 0 ;;
    --flist)  FLIST="$(abs_path "$2")"; USER_FLIST=1; shift 2 ;;
    --full)   FULL=1; shift ;;
    --mem)    MEM_FILE="$(abs_path "$2")"; shift 2 ;;
    --plusarg) EXTRA_PLUSARGS+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; EXTRA_PLUSARGS+=("$@"); break ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)
      if [[ -z "$TOP" ]]; then TOP="$1"; else EXTRA_PLUSARGS+=("$1"); fi
      shift
      ;;
  esac
done

[[ -n "$TOP" ]] || { usage; exit 1; }

OUT="${SIM_DIR}/out/${TOP}"
PLUSARGS=()
ARTIFACTS=()
EXTRA_SRCS=()
FLIST_TMP=""

export ROOT SIM_DIR TOP OUT FLIST MEM_FILE

CONFIG="${SIM_DIR}/config/${TOP}.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

cleanup_flist() { [[ -n "$FLIST_TMP" ]] && rm -f "$FLIST_TMP"; }
trap cleanup_flist EXIT

if [[ "$USER_FLIST" -eq 1 ]]; then
  :
elif [[ "$FULL" -eq 1 ]]; then
  FLIST_TMP="$(mktemp "${TMPDIR:-/tmp}/riscv-sim-flist.XXXXXX")"
  FLIST="$FLIST_TMP"
  : > "$FLIST"
  mapfile -t _full_lines < "$PROJECT_FLIST"
  for line in "${_full_lines[@]}"; do
    raw="$line"
    line="${line%%#*}"
    line="${line//$'\r'/}"
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    if [[ "$trimmed" == *_tb.sv ]]; then
      [[ "$(basename "$trimmed" .sv)" == "$TOP" ]] || continue
    fi
    printf '%s\n' "${raw//$'\r'/}" >> "$FLIST"
  done
else
  FLIST_TMP="$(mktemp "${TMPDIR:-/tmp}/riscv-sim-flist.XXXXXX")"
  FLIST="$FLIST_TMP"
  write_minimal_flist "$FLIST"
fi

[[ -f "$FLIST" ]] || { echo "No filelist: ${FLIST}" >&2; exit 1; }

mkdir -p "$OUT"
# Drop any leftover out/<top>/_build from older runs.
rm -rf "${OUT}/_build"

[[ -n "$MEM_FILE" ]] && PLUSARGS+=("imem_mem=${MEM_FILE}")
for arg in "${EXTRA_PLUSARGS[@]}"; do PLUSARGS+=("$arg"); done

run_vivado_sim "$TOP" "$FLIST" "$OUT" "${PLUSARGS[@]}" || {
  echo "failed - see ${OUT}/compile_run.log" >&2
  exit 1
}

LOG="${OUT}/compile_run.log"
if sim_tb_failed "$LOG"; then
  echo "failures - see ${LOG}" >&2
  exit 1
fi

echo "OK  ${LOG}"
for a in "${ARTIFACTS[@]}"; do
  if [[ -e "${OUT}/${a}" ]]; then
    echo "    ${OUT}/${a}"
  fi
done
