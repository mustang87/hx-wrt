#!/usr/bin/env bash
set -euo pipefail

# scripts/lib -> scripts
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"
 

PROFILE="${1:-hx-wrt-wr3000k-dev}"
LOG_FILE="${2:-}"
TMUX_SESSION_NAME="${3:-}"
TMUX_WINDOW_NAME="${4:-}"

# 先确定日志文件（否则后面 exec tee 没地方写）
if [[ -z "${LOG_FILE}" ]]; then
  LOG_DIR="${LOG_DIR:-${HXWRT_DIR}/logs}"
  mkdir -p "${LOG_DIR}"
  TS="$(date +%Y%m%d-%H%M%S)"
  LOG_FILE="${LOG_DIR}/build-${PROFILE}-${TS}.log"
fi

# 先产生开始时间（set -u 下不能引用未定义变量）
START_AT="$(date -Is)"

source "${HXWRT_DIR}/scripts/lib/build_lock.sh"
source "${HXWRT_DIR}/scripts/lib/diagnose.sh"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERR] missing command: $1" >&2
    exit 127
  }
}

trap 'echo; echo "[WARN] SIGINT(Ctrl+C) ignored. To stop: ./build.sh stop";' INT
trap 'echo; echo "[WARN] SIGTERM ignored. To stop: ./build.sh stop";' TERM

need_cmd tee
need_cmd make
need_cmd git

acquire_build_lock
trap release_build_lock EXIT

# 全程写日志（从这里开始，后面所有输出都会进 LOG_FILE）
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] profile: ${PROFILE}"
echo "[INFO] log: ${LOG_FILE}"
echo "[INFO] started at: ${START_AT}"
echo "[INFO] lock: ${LOCK_FILE}"
echo "[INFO] state: ${STATE_FILE}"
echo "[INFO] tmux: session=${TMUX_SESSION_NAME:-} window=${TMUX_WINDOW_NAME:-}"
echo "============================================================"

# 这一步建议放到 tee 之后，让 chmod 的输出也进日志
chmod +x "${HXWRT_DIR}/scripts/prepare_exec.sh" 2>/dev/null || true
"${HXWRT_DIR}/scripts/prepare_exec.sh"

# 写状态文件（让 status/tail/stop 有据可查）
cat > "${STATE_FILE}" <<EOF
PROFILE=${PROFILE}
LOG_FILE=${LOG_FILE}
START_AT=${START_AT}
SCRIPT_PID=$$
MAKE_PID=
TMUX_SESSION=${TMUX_SESSION_NAME}
TMUX_WINDOW=${TMUX_WINDOW_NAME}
EOF

echo "[INFO] state written: ${STATE_FILE}"
echo "============================================================"

"${HXWRT_DIR}/scripts/openwrt_fetch.sh"
"${HXWRT_DIR}/scripts/prepare_tree.sh"

cd "${OPENWRT_DIR}"

./scripts/feeds install -a
./scripts/feeds update openclash || true
./scripts/feeds install -a -p openclash || true

# BRAND: feeds ready now, patch LuCI identity (variant/branch) reliably
echo "[DBG] brand_identity start"
"${HXWRT_DIR}/scripts/brand_identity.sh"
echo "[DBG] brand_identity done"


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

set +e
make -j"$(nproc)" &
MAKE_PID=$!
set -e

# 回写 make pid
sed -i "s/^MAKE_PID=.*/MAKE_PID=${MAKE_PID}/" "${STATE_FILE}" 2>/dev/null || {
  # busybox sed 兼容
  tmp="${STATE_FILE}.tmp"
  awk -v mpid="${MAKE_PID}" '
    BEGIN{FS=OFS="="}
    $1=="MAKE_PID"{$2=mpid}
    {print}
  ' "${STATE_FILE}" > "${tmp}" && mv "${tmp}" "${STATE_FILE}"
}

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
