#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/env.sh"

cd "${OPENWRT_DIR}"

kset() {
  local sym="$1"
  local val="$2"

  # 清理旧定义
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
      echo "Invalid val: ${val}" >&2
      exit 1
      ;;
  esac
}

echo "[HX-WRT] enable LuCI zh-cn (always-on)"

# ===== LuCI Chinese (核心 + 常用模块) =====
kset CONFIG_PACKAGE_luci-i18n-base-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-firewall-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-network-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-system-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn y

# 固化，避免 menuconfig 弹窗 & 覆盖
yes "" | make oldconfig >/dev/null

echo "[HX-WRT] LuCI zh-cn applied"
