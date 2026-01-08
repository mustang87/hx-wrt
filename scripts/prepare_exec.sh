#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[PREP] fixing executable permissions..."

chmod +x "${ROOT_DIR}/scripts/"*.sh 2>/dev/null || true
chmod +x "${ROOT_DIR}/scripts/lib/"*.sh 2>/dev/null || true
chmod +x "${ROOT_DIR}/scripts/openclash/"* 2>/dev/null || true

chmod +x "${ROOT_DIR}/overlay/etc/uci-defaults/"* 2>/dev/null || true
chmod +x "${ROOT_DIR}/overlay/etc/init.d/"* 2>/dev/null || true

echo "[PREP] chmod done"
