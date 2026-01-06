#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/features.sh"

cd "${OPENWRT_DIR}"

# 确保 conf 工具存在（通常在 make defconfig 后就有）
if [ ! -x "scripts/config/conf" ]; then
  make -C scripts/config conf
fi

kset() {
  local sym="$1"
  local val="$2"
  scripts/config/conf --file .config --set-val "${sym}" "${val}"
}

# ---- Always-on: LuCI Chinese (你可以先放这里验证链路) ----
# 注意：这里我们强制 set，然后不再跑 defconfig 覆盖它
kset CONFIG_PACKAGE_luci-i18n-base-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-firewall-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn y

# ---- Feature: argon ----
if has_feature "argon"; then
  echo "[FEATURE] enable argon"
  kset CONFIG_PACKAGE_luci-theme-argon y
else
  echo "[FEATURE] disable argon"
  kset CONFIG_PACKAGE_luci-theme-argon n
fi

# 可选：如果你想避免 bootstrap 占空间
# kset CONFIG_PACKAGE_luci-theme-bootstrap n

echo "[OK] config tweak applied"
