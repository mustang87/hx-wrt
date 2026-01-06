#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

PROFILE="${1:-hx-wrt-wr3000k-dev}"
CFG="${HXWRT_DIR}/configs/wr3000k/${PROFILE}.config"

if [ ! -f "${CFG}" ]; then
  echo "Config not found: ${CFG}"
  exit 1
fi

cd "${OPENWRT_DIR}"
cp "${CFG}" .config
make defconfig

echo "[OK] applied config: ${PROFILE}"
