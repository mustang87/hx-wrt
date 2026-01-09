#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

log() { echo "[FORCE-LUCI] $*"; }

OPENWRT_DIR="${OPENWRT_DIR:?OPENWRT_DIR not set}"

log "start force rebuild luci-base"

# -------------------------
# 1) Kill old luci-base build cache
# -------------------------
log "remove luci-base build_dir cache"
rm -rf "${OPENWRT_DIR}"/build_dir/*/luci-base* 2>/dev/null || true

# -------------------------
# 2) Kill staged version files
# -------------------------
log "remove staged luci version files"
rm -f "${OPENWRT_DIR}"/staging_dir/*/root-*/usr/share/ucode/luci/version.uc 2>/dev/null || true
rm -f "${OPENWRT_DIR}"/staging_dir/*/root-*/usr/share/rpcd/ucode/luci 2>/dev/null || true

# -------------------------
# 3) Force recompile luci-base
#    (tree layout differs across feeds, try both)
# -------------------------
cd "${OPENWRT_DIR}"

if make package/feeds/luci/luci-base/compile V=s; then
  log "compiled luci-base via package/feeds/luci"
elif make package/luci-base/compile V=s; then
  log "compiled luci-base via package/luci-base"
else
  log "WARN: luci-base compile target not found (will rely on full make)"
fi

# -------------------------
# 4) Force reinstall luci-base into staging_dir
# -------------------------
if make package/feeds/luci/luci-base/install V=s; then
  log "installed luci-base via package/feeds/luci"
elif make package/luci-base/install V=s; then
  log "installed luci-base via package/luci-base"
else
  log "WARN: luci-base install target not found"
fi

log "force rebuild luci-base done"
