#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/features.sh"

cd "${OPENWRT_DIR}"

# argon
if has_feature "argon"; then
  ./scripts/config set CONFIG_PACKAGE_luci-theme-argon=y || true
else
  ./scripts/config set CONFIG_PACKAGE_luci-theme-argon=n || true
fi

# openclash（先预留，不启用也没关系）
if has_feature "openclash"; then
  ./scripts/config set CONFIG_PACKAGE_luci-app-openclash=y || true
else
  ./scripts/config set CONFIG_PACKAGE_luci-app-openclash=n || true
fi
