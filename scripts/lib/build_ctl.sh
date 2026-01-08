#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"
source "${HXWRT_DIR}/scripts/lib/build_lock.sh"

read_state() {
  if [[ -f "${STATE_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
  fi
}

is_pid_alive() {
  local pid="${1:-}"
  [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
}

hint_attach() {
  if [[ -n "${TMUX_SESSION:-}" ]] && command -v tmux >/dev/null 2>&1; then
    echo
    echo "[STATUS] tmux session: ${TMUX_SESSION}"
    echo "[STATUS] tmux window:  ${TMUX_WINDOW:-unknown}"
    echo
    echo "[HINT] attach command:"
    if [[ -n "${TMUX_WINDOW:-}" ]]; then
      echo "  tmux attach -t ${TMUX_SESSION} \\; select-window -t ${TMUX_WINDOW}"
    else
      echo "  tmux attach -t ${TMUX_SESSION}"
    fi
  fi
}

cmd_status() {
  read_state

  echo "[STATUS] lock:  ${LOCK_FILE}"
  echo "[STATUS] state: ${STATE_FILE}"
  echo

  if [[ -f "${LOCK_FILE}" ]]; then
    local pid
    pid="$(cat "${LOCK_FILE}" 2>/dev/null || true)"
    if is_pid_alive "${pid}"; then
      echo "[STATUS] running: YES"
      echo "[STATUS] script pid: ${pid}"
    else
      echo "[STATUS] running: NO (stale lock pid=${pid:-unknown})"
    fi
  else
    echo "[STATUS] running: NO"
  fi

  echo
  echo "[STATUS] profile:   ${PROFILE:-unknown}"
  echo "[STATUS] start_at:  ${START_AT:-unknown}"
  echo "[STATUS] log_file:  ${LOG_FILE:-unknown}"
  echo "[STATUS] make_pid:  ${MAKE_PID:-unknown}"

  hint_attach

  echo
  if [[ -n "${LOG_FILE:-}" && -f "${LOG_FILE:-/dev/null}" ]]; then
    echo "[STATUS] last log lines:"
    tail -n 20 "${LOG_FILE}" || true
  else
    echo "[STATUS] log missing / not recorded yet."
  fi
}

cmd_tail() {
  read_state
  if [[ -z "${LOG_FILE:-}" ]]; then
    echo "[ERR] no log file recorded (state missing)."
    exit 1
  fi
  if [[ ! -f "${LOG_FILE}" ]]; then
    echo "[ERR] log file not found: ${LOG_FILE}"
    exit 1
  fi
  echo "[INFO] tailing: ${LOG_FILE}"
  tail -n 200 -f "${LOG_FILE}"
}

cmd_stop() {
  read_state

  if [[ ! -f "${LOCK_FILE}" ]]; then
    echo "[INFO] no lock file, nothing to stop."
    exit 0
  fi

  local spid
  spid="$(cat "${LOCK_FILE}" 2>/dev/null || true)"

  if ! is_pid_alive "${spid}"; then
    echo "[WARN] lock pid not alive, cleaning lock/state"
    rm -f "${LOCK_FILE}" "${STATE_FILE}" || true
    exit 0
  fi

  local target_make="${MAKE_PID:-}"
  local term_wait=12

  echo "[INFO] stopping build..."
  echo "[INFO] script pid: ${spid}"
  echo "[INFO] make pid:   ${target_make:-unknown}"
  echo "[INFO] lock:       ${LOCK_FILE}"
  echo "[INFO] state:      ${STATE_FILE}"

  hint_attach

  if is_pid_alive "${target_make}"; then
    echo "[INFO] sending SIGTERM to make pid ${target_make}"
    kill -TERM "${target_make}" 2>/dev/null || true
  fi

  echo "[INFO] sending SIGTERM to script pid ${spid}"
  kill -TERM "${spid}" 2>/dev/null || true

  for _ in $(seq 1 "${term_wait}"); do
    sleep 1
    if ! is_pid_alive "${spid}" && { [[ -z "${target_make}" ]] || ! is_pid_alive "${target_make}"; }; then
      echo "[OK] stopped gracefully"
      rm -f "${LOCK_FILE}" "${STATE_FILE}" || true
      exit 0
    fi
  done

  echo "[WARN] still running, escalating to SIGKILL"

  if is_pid_alive "${target_make}"; then
    kill -KILL "${target_make}" 2>/dev/null || true
  fi
  if is_pid_alive "${spid}"; then
    kill -KILL "${spid}" 2>/dev/null || true
  fi

  sleep 1
  rm -f "${LOCK_FILE}" "${STATE_FILE}" || true
  echo "[OK] stopped (killed)"
}

case "${1:-}" in
  status) cmd_status ;;
  tail)   cmd_tail ;;
  stop)   cmd_stop ;;
  *)
    echo "Usage: build_ctl.sh {status|tail|stop}"
    exit 2
    ;;
esac
