#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

PROFILE="${1:-hx-wrt-wr3000k-dev}"

# =========================
# TMUX / LOG CONFIG
# =========================
TMUX_SESSION="${TMUX_SESSION:-hxwrt-build}"
LOG_DIR="${LOG_DIR:-${HXWRT_DIR}/logs}"
mkdir -p "${LOG_DIR}"

TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/build-${PROFILE}-${TS}.log"

# =========================
# Helpers
# =========================
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERR] missing command: $1" >&2
    exit 127
  }
}

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
  else
    echo "----[DIAG] could not infer last package compile marker ----"
    echo
  fi

  echo "----[DIAG] last 220 lines of log ----"
  tail -n 220 "${log}" || true

  echo "============================================================"
}

# -------------------------
# 1) Auto enter tmux
# -------------------------
# 说明：
# - 如果你当前不在 tmux 内：脚本会创建/复用会话，并在会话里重新执行自己
# - 这样你本地 SSH 断线/切节点也不影响编译
if [[ -z "${TMUX:-}" ]]; then
  need_cmd tmux

  echo "[INFO] not in tmux, entering session: ${TMUX_SESSION}"
  echo "[INFO] log: ${LOG_FILE}"

  SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

  # 注意：外层不要再 tee，避免重复写日志；日志由 tmux 内层统一负责
  if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
    tmux new-window -t "${TMUX_SESSION}" -n "build-${PROFILE}-${TS}" \
      "bash '${SELF}' '${PROFILE}' --inner; echo; echo '[INFO] build finished. press ENTER to keep window'; read -r"
    tmux attach -t "${TMUX_SESSION}"
  else
    tmux new-session -s "${TMUX_SESSION}" -n "build-${PROFILE}-${TS}" \
      "bash '${SELF}' '${PROFILE}' --inner; echo; echo '[INFO] build finished. press ENTER to keep window'; read -r"
  fi

  exit 0
fi

# -------------------------
# 2) Inside tmux: harden signals (anti-mistake)
# -------------------------
INNER="${2:-}"
if [[ "${INNER}" != "--inner" ]]; then
  set -- "${PROFILE}" --inner
fi

trap 'echo; echo "[WARN] SIGINT(Ctrl+C) ignored to prevent accidental stop. If you really want to stop, run: kill <make_pid>  (shown above) or pkill -f \"make -j\"";' INT
trap 'echo; echo "[WARN] SIGTERM ignored to prevent accidental stop. If you really want to stop, kill the make process explicitly.";' TERM
trap 'echo; echo "[INFO] exit trap triggered."' EXIT

echo "[INFO] tmux: ${TMUX_SESSION}  profile: ${PROFILE}"
echo "[INFO] log file: ${LOG_FILE}"
echo "[INFO] pwd: $(pwd)"
echo "============================================================"

# =========================
# Build steps
# =========================
need_cmd make
need_cmd git
need_cmd tee

# 从这里开始：把整个脚本关键输出也落到日志里（同时仍然打印到屏幕）
# 这样你后续 diagnose 时，日志里会包含前置步骤信息
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] logging started: ${LOG_FILE}"
echo "[INFO] started at: $(date -Is)"

"${HXWRT_DIR}/scripts/openwrt_fetch.sh"
"${HXWRT_DIR}/scripts/prepare_tree.sh"

cd "${OPENWRT_DIR}"

./scripts/feeds install -a
./scripts/feeds update openclash || true
./scripts/feeds install -a -p openclash || true

echo "[DBG] config_apply start"
"${HXWRT_DIR}/scripts/config_apply.sh" "${PROFILE}"
echo "[DBG] config_apply done"

echo "[DBG] config_tweak start"
"${HXWRT_DIR}/scripts/config_tweak.sh"
echo "[DBG] config_tweak done"

make defconfig
echo "[DBG] defconfig done"

rm -f "${OPENWRT_DIR}/bin/targets/mediatek/filogic/"*tenbay_wr3000k* 2>/dev/null || true

echo "[INFO] make start: -j$(nproc)"
echo "[INFO] if ssh disconnects, build keeps running in tmux."

# 关键：后台运行拿 PID，然后 wait 获取退出码；失败自动诊断
set +e
make -j"$(nproc)" &
MAKE_PID=$!
set -e

show_make_pid "${MAKE_PID}"

wait "${MAKE_PID}"
MAKE_RC=$?

if [[ "${MAKE_RC}" -ne 0 ]]; then
  echo "[ERR] make failed, rc=${MAKE_RC}"
  diagnose_fail_from_log "${LOG_FILE}"
  exit "${MAKE_RC}"
fi

echo "[OK] build done"
echo "Artifacts: ${OPENWRT_DIR}/bin/targets/"
echo "[OK] log saved: ${LOG_FILE}"
echo "[INFO] finished at: $(date -Is)"
