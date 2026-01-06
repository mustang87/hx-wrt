#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

if [ ! -d "${OPENWRT_DIR}/.git" ]; then
  git clone "${OPENWRT_REMOTE}" "${OPENWRT_DIR}"
fi

cd "${OPENWRT_DIR}"
git fetch --all --tags
git checkout "${OPENWRT_BRANCH}"
git pull --ff-only || true

echo "[OK] OpenWrt: ${OPENWRT_REMOTE} @ ${OPENWRT_BRANCH}"
