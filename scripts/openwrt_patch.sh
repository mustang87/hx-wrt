#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

cd "${OPENWRT_DIR}"

PATCH_FILE="${HXWRT_DIR}/patches/001-tenbay-wr3000k-big-overlay.patch"

# 已应用则跳过：用 reverse check 判断
if git apply --reverse --check "${PATCH_FILE}" >/dev/null 2>&1; then
  echo "[SKIP] Patch already applied: $(basename "${PATCH_FILE}")"
else
  git apply "${PATCH_FILE}"
  echo "[OK] Applied patch: $(basename "${PATCH_FILE}")"
fi
