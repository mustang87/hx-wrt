#!/usr/bin/env bash
set -euo pipefail

show_make_pid() {
  local pid="$1"
  echo "[INFO] make PID: ${pid}"
  echo "[INFO] stop build: kill ${pid}   (or: pkill -P ${pid}  # kill children)"
}

diagnose_fail_from_log() {
  local log="$1"
  echo
  echo "====================[DIAG] build failed ===================="

  if [[ ! -f "${log}" ]]; then
    echo "[DIAG] log not found: ${log}"
    return 0
  fi

  echo "[DIAG] log: ${log}"
  echo

  echo "----[DIAG] last package/feed compile markers (tail 60) ----"
  grep -nE 'make\[[0-9]+\] -C (package|feeds)/[^ ]+ (compile|install)|Entering directory|Leaving directory' "${log}" \
    | tail -n 60 || true
  echo

  echo "----[DIAG] error keywords (last 160 hits) ----"
  grep -nE '(^|\s)(Error|ERROR|error:|fatal:|FAILED|No such file|undefined reference|not found|permission denied|Cannot|CMake Error|ninja: error|collect2: error|missing separator|recipe for target).*' "${log}" \
    | tail -n 160 || true
  echo

  local last_pkg ln start end
  last_pkg="$(grep -E 'make\[[0-9]+\] -C (package|feeds)/[^ ]+ compile' "${log}" \
    | tail -n 1 \
    | sed -E 's/.*-C ((package|feeds)\/[^ ]+).*/\1/')" || true

  if [[ -n "${last_pkg}" ]]; then
    echo "----[DIAG] suspected failing package path ----"
    echo "[DIAG] ${last_pkg}"
    echo

    ln="$(grep -nE "make\[[0-9]+\] -C ${last_pkg//\//\\/} compile" "${log}" | tail -n 1 | cut -d: -f1)" || true
    if [[ -n "${ln}" ]]; then
      start=$(( ln - 80 )); [[ "${start}" -lt 1 ]] && start=1
      end=$(( ln + 260 ))
      echo "----[DIAG] context around last '${last_pkg} compile' (L${start}-L${end}) ----"
      sed -n "${start},${end}p" "${log}" || true
      echo
    fi
  fi

  echo "----[DIAG] last 220 lines of log ----"
  tail -n 220 "${log}" || true

  echo "============================================================"
}
