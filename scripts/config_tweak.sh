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
    y|m) echo "${sym}=${val}" >> .config ;;
    n)   echo "# ${sym} is not set" >> .config ;;
    *)   echo "Invalid val: ${val} (use y/m/n)" >&2; exit 1 ;;
  esac
}

echo "[HX-WRT] enable LuCI zh_Hans (always-on)"
kset CONFIG_LUCI_LANG_zh_Hans y
kset CONFIG_PACKAGE_luci-i18n-base-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-firewall-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn y
kset CONFIG_PACKAGE_luci-i18n-attendedsysupgrade-zh-cn y

if has_feature "argon"; then
  echo "[HX-WRT] enable argon (FEATURES=${FEATURES})"
  kset CONFIG_PACKAGE_luci-theme-argon y
else
  echo "[HX-WRT] disable argon (FEATURES=${FEATURES})"
  kset CONFIG_PACKAGE_luci-theme-argon n
fi

echo "[HX-WRT] config_tweak done (no make here)"
