#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="${LOCK_FILE:-${HXWRT_DIR}/.hxwrt-build.lock}"
STATE_FILE="${STATE_FILE:-${HXWRT_DIR}/.hxwrt-build.state}"

acquire_build_lock() {
  if [[ -f "${LOCK_FILE}" ]]; then
    local old_pid
    old_pid="$(cat "${LOCK_FILE}" 2>/dev/null || true)"

    if [[ -n "${old_pid}" ]] && kill -0 "${old_pid}" 2>/dev/null; then
      echo "[ERR] hx-wrt build already running!"
      echo "[ERR] PID: ${old_pid}"
      echo "[ERR] lock: ${LOCK_FILE}"
      [[ -f "${STATE_FILE}" ]] && echo "[ERR] state: ${STATE_FILE}"
      exit 1
    fi

    echo "[WARN] stale build lock found (pid=${old_pid:-unknown}), cleaning up"
    rm -f "${LOCK_FILE}" || true
  fi

  echo "$$" > "${LOCK_FILE}"
  echo "[INFO] build lock acquired: ${LOCK_FILE} (pid=$$)"
}

release_build_lock() {
  if [[ -f "${LOCK_FILE}" ]] && [[ "$(cat "${LOCK_FILE}" 2>/dev/null || true)" = "$$" ]]; then
    rm -f "${LOCK_FILE}" || true
    echo "[INFO] build lock released"
  fi
}
