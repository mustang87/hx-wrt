#!/usr/bin/env bash
set -euo pipefail

tmux_wrap_run() {
  local profile="${1:?profile required}"

  local TMUX_SESSION="${TMUX_SESSION:-hxwrt-build}"
  local LOG_DIR="${LOG_DIR:-${HXWRT_DIR}/logs}"
  mkdir -p "${LOG_DIR}"

  local ts window log_file
  ts="$(date +%Y%m%d-%H%M%S)"
  window="build-${profile}-${ts}"
  log_file="${LOG_DIR}/build-${profile}-${ts}.log"

  # 不在 tmux 内：创建/复用会话并在新窗口执行 build_main
  if [[ -z "${TMUX:-}" ]]; then
    command -v tmux >/dev/null 2>&1 || {
      echo "[ERR] missing command: tmux" >&2
      exit 127
    }

    echo "[INFO] not in tmux, entering session: ${TMUX_SESSION}"
    echo "[INFO] window: ${window}"
    echo "[INFO] log: ${log_file}"

    # 注意：外层不 tee；日志由 build_main.sh 的 exec tee 统一处理
    local cmd
    cmd="bash '${HXWRT_DIR}/scripts/lib/build_main.sh' '${profile}' '${log_file}' '${TMUX_SESSION}' '${window}'; echo; echo '[INFO] build finished. press ENTER to keep window'; read -r"

    if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
      tmux new-window -t "${TMUX_SESSION}" -n "${window}" "${cmd}"
      tmux attach -t "${TMUX_SESSION}"
    else
      tmux new-session -s "${TMUX_SESSION}" -n "${window}" "${cmd}"
    fi
    exit 0
  fi

  # 已在 tmux 内：直接跑（仍然会记录 session/window）
  bash "${HXWRT_DIR}/scripts/lib/build_main.sh" "${profile}" "${log_file}" "${TMUX_SESSION}" "${window}"
}
