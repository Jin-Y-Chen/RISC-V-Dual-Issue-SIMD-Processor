#!/usr/bin/env bash
# Shared Vivado tool helpers for sim/run.sh

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sim_root() {
  (cd "${_LIB_DIR}/.." && pwd)
}

repo_root() {
  (cd "${_LIB_DIR}/../.." && pwd)
}

win_path() {
  local p="${1//\\//}"
  # Git Bash: convert any MSYS path (incl. /tmp) to a Windows drive path.
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$p" 2>/dev/null && return
  fi
  [[ "$p" =~ ^/([a-zA-Z])/(.+)$ ]] && p="$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]'):/${BASH_REMATCH[2]}"
  echo "$p"
}

abs_path() {
  local p="$1" root
  root="$(repo_root)"
  [[ "$p" = /* ]] || [[ "$p" =~ ^[A-Za-z]: ]] && { echo "$p"; return; }
  echo "${root}/${p}"
}

# Normalize plusarg paths for the TB ($fopen). Relative values are under <out>.
plusarg_normalize() {
  local arg="$1" out="$2" key val
  [[ "$arg" == *=* ]] || { echo "$arg"; return; }
  key="${arg%%=*}"
  val="${arg#*=}"
  [[ -z "$val" ]] && { echo "$arg"; return; }
  if [[ "$val" != /* && ! "$val" =~ ^[A-Za-z]: ]]; then
    val="${out}/${val}"
  fi
  echo "${key}=$(win_path "$val")"
}

find_vivado_bin() {
  local v="${VIVADO:-}" bin
  if [[ -n "$v" && ( -x "$v" || -f "$v" ) ]]; then
    bin="$(cd "$(dirname "$v")" && pwd)"
    [[ -f "$bin/xvlog" || -f "$bin/xvlog.bat" ]] && { echo "$bin"; return; }
  fi
  if command -v xvlog &>/dev/null; then
    dirname "$(command -v xvlog)"
    return
  fi
  for v in /c/FPGA/*/Vivado/bin/vivado.bat /c/Xilinx/Vivado/*/bin/vivado.bat; do
    [[ -f $v ]] || continue
    bin="$(cd "$(dirname "$v")" && pwd)"
    [[ -f "$bin/xvlog" || -f "$bin/xvlog.bat" ]] && { echo "$bin"; return; }
  done
  echo "Vivado bin not found (set VIVADO=.../vivado.bat)" >&2
  return 1
}

tool() {
  local bin="$1" name="$2"
  if [[ -f "$bin/${name}.bat" ]]; then
    echo "$bin/${name}.bat"
  else
    echo "$bin/$name"
  fi
}

sim_tb_failed() {
  local log="$1"
  [[ -f "$log" ]] || return 1
  grep -qE '\[FAIL\]|SUMMARY:.*[1-9][0-9]* failed' "$log"
}

_stage_has_error() {
  local toollog="$1"
  [[ -f "$toollog" ]] && grep -qE '^ERROR:|\[ERROR\]' "$toollog"
}

# run_vivado_sim <top> <filelist> <out_dir> [plusarg ...]
# Vivado work/xsim.dir live in a temp dir (not under out/). out/ keeps log + artifacts.
run_vivado_sim() {
  local top="$1" flist="$2" out="$3"
  shift 3

  local root build bin log scratch xvlog xelab xsim rc
  local -a srcs=() incs=() plus=() flines=()
  local line path
  local prev_pwd="$PWD"

  root="$(repo_root)"
  build="$(mktemp -d "${TMPDIR:-/tmp}/riscv-sim.XXXXXX")"
  bin="$(find_vivado_bin)" || { rm -rf "$build"; return 1; }
  log="${out}/compile_run.log"
  scratch="${build}/.scratch"

  mkdir -p "$out" "$scratch"
  : > "$log"

  # Clean temp build when this function returns (do not clobber caller's EXIT trap).
  cleanup_build() { cd "$prev_pwd" 2>/dev/null || true; rm -rf "$build"; }
  trap cleanup_build RETURN

  mapfile -t flines < "$flist"
  for line in "${flines[@]}"; do
    line="${line%%#*}"
    line="${line//$'\r'/}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    if [[ "$line" == +incdir+* ]]; then
      path="${line#+incdir+}"
      [[ "$path" = /* || "$path" =~ ^[A-Za-z]: ]] || path="${root}/${path}"
      incs+=(-i "$(win_path "$path")")
    elif [[ "$line" != -f* ]]; then
      path="$line"
      [[ "$path" = /* || "$path" =~ ^[A-Za-z]: ]] || path="${root}/${path}"
      srcs+=("$(win_path "$path")")
    fi
  done

  if [[ ${#srcs[@]} -eq 0 ]]; then
    echo "no sources in filelist: $flist" >&2
    return 1
  fi

  for arg in "$@"; do
    [[ -n "$arg" ]] || continue
    plus+=("$(plusarg_normalize "$arg" "$out")")
  done

  xvlog="$(tool "$bin" xvlog)"
  xelab="$(tool "$bin" xelab)"
  xsim="$(tool "$bin" xsim)"

  cd "$build" || return 1

  # Pretty-print paths relative to repo for the terminal UI.
  _ui_rel() {
    local p="$1"
    p="${p//\\//}"
    if [[ "$p" == "$root"/* ]]; then
      echo "${p#"$root"/}"
    elif [[ "$p" =~ ^[A-Za-z]:/ ]]; then
      local rp
      rp="$(win_path "$root")"
      [[ "$p" == "$rp"/* ]] && echo "${p#"$rp"/}" && return
      echo "$p"
    else
      echo "$p"
    fi
  }

  echo >&2
  echo "[1/3] xvlog — Compiling ${#srcs[@]} SystemVerilog source(s) into the work library." >&2
  for path in "${srcs[@]}"; do
    echo "        · $(_ui_rel "$path")" >&2
  done
  {
    echo
    echo "=== xvlog (${#srcs[@]} sources) ==="
  } >>"$log"
  rc=0
  "$xvlog" -sv --incr --relax -work work "${incs[@]}" "${srcs[@]}" \
    --log "$(win_path "${scratch}/xvlog.log")" >>"$log" 2>&1 || rc=$?
  [[ -f "${scratch}/xvlog.log" ]] && cat "${scratch}/xvlog.log" >>"$log"
  if [[ $rc -ne 0 ]] || _stage_has_error "${scratch}/xvlog.log"; then
    return 1
  fi

  echo >&2
  echo "[2/3] xelab — Elaborating work.${top} and building simulation snapshot ${top}_sim." >&2
  {
    echo
    echo "=== xelab ==="
  } >>"$log"
  rc=0
  "$xelab" "work.${top}" -s "${top}_sim" --log "$(win_path "${scratch}/xelab.log")" >>"$log" 2>&1 || rc=$?
  [[ -f "${scratch}/xelab.log" ]] && cat "${scratch}/xelab.log" >>"$log"
  if [[ $rc -ne 0 ]] || _stage_has_error "${scratch}/xelab.log"; then
    return 1
  fi

  echo >&2
  echo "[3/3] xsim  — Running simulation snapshot ${top}_sim to completion." >&2
  {
    echo
    echo "=== xsim ==="
  } >>"$log"
  # xsim.bat splits cmdline on '='; write args one-per-line and use --file.
  {
    echo "${top}_sim"
    for arg in "${plus[@]}"; do
      echo "-testplusarg"
      echo "$arg"
    done
    echo "-runall"
    echo "--log"
    echo "$(win_path "${scratch}/xsim.log")"
  } >"${scratch}/xsim_args.txt"
  "$xsim" --file "$(win_path "${scratch}/xsim_args.txt")" >>"$log" 2>&1 || true
  [[ -f "${scratch}/xsim.log" ]] && cat "${scratch}/xsim.log" >>"$log"
  echo >&2

  return 0
}
