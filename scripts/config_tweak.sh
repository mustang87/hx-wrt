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

# ---- Feature: argon ----
if has_feature "argon"; then
  echo "[HX-WRT] enable argon (FEATURES=${FEATURES})"
  kset CONFIG_PACKAGE_luci-theme-argon y
else
  echo "[HX-WRT] disable argon (FEATURES=${FEATURES})"
  kset CONFIG_PACKAGE_luci-theme-argon n
fi

# ---- Feature: openclash ----
if has_feature "openclash"; then
  echo "[HX-WRT] enable OpenClash deps"

  # OpenClash 本体（如果你准备下一步再加，也可以先不启用）
  # kset CONFIG_PACKAGE_openclash y
  kset CONFIG_PACKAGE_luci-compat y

  # Kernel deps
  kset CONFIG_PACKAGE_kmod-tun y
  kset CONFIG_PACKAGE_kmod-inet-diag y
  kset CONFIG_PACKAGE_kmod-nft-tproxy y
  kset CONFIG_PACKAGE_kmod-nf-conntrack-netlink y

  # Runtime deps
  kset CONFIG_PACKAGE_bash y
  kset CONFIG_PACKAGE_dnsmasq-full y
  kset CONFIG_PACKAGE_curl y
  kset CONFIG_PACKAGE_ca-bundle y
  kset CONFIG_PACKAGE_ip-full y
  kset CONFIG_PACKAGE_unzip y

  # ruby（你要的话就打开）
  kset CONFIG_PACKAGE_ruby y
  kset CONFIG_PACKAGE_ruby-yaml y
else
  echo "[HX-WRT] disable OpenClash deps"

  # kset CONFIG_PACKAGE_openclash n
  kset CONFIG_PACKAGE_luci-compat n
  kset CONFIG_PACKAGE_kmod-tun n
  kset CONFIG_PACKAGE_kmod-inet-diag n
  kset CONFIG_PACKAGE_kmod-nft-tproxy n
  kset CONFIG_PACKAGE_kmod-nf-conntrack-netlink n
  kset CONFIG_PACKAGE_bash n
  kset CONFIG_PACKAGE_dnsmasq-full n
  kset CONFIG_PACKAGE_curl n
  kset CONFIG_PACKAGE_ca-bundle n
  kset CONFIG_PACKAGE_ip-full n
  kset CONFIG_PACKAGE_unzip n
  kset CONFIG_PACKAGE_ruby n
  kset CONFIG_PACKAGE_ruby-yaml n
fi


echo "[HX-WRT] config_tweak done (no make here)"
