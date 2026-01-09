#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/features.sh"

# 拉第三方源码（按 lock）
"${HXWRT_DIR}/scripts/sources.sh"

CACHE_DIR="${HXWRT_DIR}/.cache/sources"

cd "${OPENWRT_DIR}"

# BRAND: patch model/version/luci identity (safe & idempotent)
"${HXWRT_DIR}/scripts/brand_identity.sh"

# 0) 生成 OpenClash init-run 到 overlay（避免 repo 的 bin/ 被 gitignore 误伤）
if [ -f "${HXWRT_DIR}/scripts/openclash/hx-openclash-init-run" ]; then
  mkdir -p "${HXWRT_DIR}/overlay/usr/bin"
  install -m 0755 \
    "${HXWRT_DIR}/scripts/openclash/hx-openclash-init-run" \
    "${HXWRT_DIR}/overlay/usr/bin/hx-openclash-init-run"
fi

# 1) 注入 overlay -> OpenWrt 的 files/
rm -rf files
cp -a "${HXWRT_DIR}/overlay" files

# ensure uci-defaults are executable
if [ -d "files/etc/uci-defaults" ]; then
  chmod +x files/etc/uci-defaults/* || true
fi

# 2) 注入自定义 package（你的包）
mkdir -p package/hx
rm -rf package/hx/hx-brand
cp -a "${HXWRT_DIR}/package/hx-brand" package/hx/hx-brand

# 3) 可选：argon 主题（FEATURES=argon）
if has_feature "argon"; then
  echo "[FEATURE] argon enabled"

  mkdir -p package/hx/thirdparty
  rm -rf package/hx/thirdparty/luci-theme-argon
  cp -a "${CACHE_DIR}/luci-theme-argon" package/hx/thirdparty/luci-theme-argon

  mkdir -p files/etc/uci-defaults
  cp -a "${HXWRT_DIR}/overlay-features/argon/uci-defaults/15-hx-luci-theme.sh" \
        files/etc/uci-defaults/15-hx-luci-theme.sh
  chmod +x files/etc/uci-defaults/15-hx-luci-theme.sh
fi

# 4) 可选：OpenClash（FEATURES=openclash）
if has_feature "openclash"; then
  echo "[FEATURE] openclash enabled"

  mkdir -p package/hx/thirdparty
  rm -rf package/hx/thirdparty/luci-app-openclash

  # OpenClash 仓库里真正的 OpenWrt package 目录叫 luci-app-openclash
  cp -a "${CACHE_DIR}/luci-app-openclash/luci-app-openclash" \
        package/hx/thirdparty/luci-app-openclash
fi


echo "[OK] injected overlay/package (+features)"
