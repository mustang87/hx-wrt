#!/usr/bin/env bash
set -euo pipefail

# =========================
# hx-wrt clean script
# =========================

# 项目根目录（自动定位）
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENWRT_DIR="${ROOT_DIR}/openwrt"

BUILD_DIR="${OPENWRT_DIR}/build_dir"
STAGING_DIR="${OPENWRT_DIR}/staging_dir"
DL_DIR="${OPENWRT_DIR}/dl"
BIN_DIR="${OPENWRT_DIR}/bin"

MODE="${1:-safe}"

echo "==> hx-wrt clean mode: ${MODE}"
echo "==> openwrt dir: ${OPENWRT_DIR}"
echo

# 基础校验，防止误删
if [[ ! -d "${OPENWRT_DIR}" ]]; then
  echo "ERROR: openwrt dir not found"
  exit 1
fi

case "${MODE}" in
  # -------------------------
  # L1: 安全清理（强烈推荐）
  # -------------------------
  safe)
    echo "[SAFE] Cleaning build artifacts (no recompilation penalty)"
    rm -rf "${BUILD_DIR}/tmp" 2>/dev/null || true
    rm -rf "${OPENWRT_DIR}/logs" 2>/dev/null || true
    rm -rf "${BIN_DIR}"/* 2>/dev/null || true
    echo "[SAFE] Done."
    ;;

  # -------------------------
  # L2: 常规清理（推荐在成功编译后）
  # -------------------------
  normal)
    echo "[NORMAL] Cleaning build_dir (packages + target)"
    cd "${OPENWRT_DIR}"
    make package/clean
    make target/linux/clean
    echo "[NORMAL] Done."
    ;;

  # -------------------------
  # L3: 激进清理（谨慎）
  # -------------------------
  deep)
    echo "[DEEP] Full clean (will recompile everything)"
    cd "${OPENWRT_DIR}"
    make clean
    echo "[DEEP] Done."
    ;;

  *)
    echo "Usage: $0 {safe|normal|deep}"
    echo
    echo "  safe   : remove logs/bin/tmp (no rebuild needed)"
    echo "  normal : clean package + kernel build (recommended)"
    echo "  deep   : full clean (slow, use with care)"
    exit 1
    ;;
esac
