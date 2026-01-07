#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/env.sh"

cd "${OPENWRT_DIR}"

kset() {
  local sym="$1"
  local val="$2"

  sed -i -E "/^${sym}=.*/d" .config
  sed -i -E "/^# ${sym} is not set$/d" .config

  case "${val}" in
    y|m) echo "${sym}=${val}" >> .config ;;
    n)   echo "# ${sym} is not set" >> .config ;;
    *)   echo "Invalid val: ${val}" >&2; exit 1 ;;
  esac
}

echo "[HX-WRT] enable LuCI zh_Hans (always-on)"

# ✅ 关键：打开 LuCI 简体中文语言开关
kset CONFIG_LUCI_LANG_zh_Hans y

# ✅ 再选对应的 i18n 包（你要 zh-cn 的这些）
kset CONFIG_PACKAGE_luci-i18n-base-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-firewall-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-network-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-system-zh-cn y


echo "[HX-WRT] config_tweak done (no make here)"
