#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/features.sh"

cd "${OPENWRT_DIR}"

kset() {
  local sym="$1"
  local val="$2"

  # 删除旧值（y/m/n 或 not set）
  sed -i -E "/^${sym}=.*/d" .config
  sed -i -E "/^# ${sym} is not set$/d" .config

  case "${val}" in
    y|m)
      echo "${sym}=${val}" >> .config
      ;;
    n)
      echo "# ${sym} is not set" >> .config
      ;;
    *)
      echo "Invalid val: ${val} (use y/m/n)" >&2
      exit 1
      ;;
  esac
}

# ---- Always-on: LuCI Chinese ----
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

# 关键：用非交互 oldconfig 固化配置，避免弹 menu
yes "" | make oldconfig >/dev/null

echo "[OK] config tweak applied"
