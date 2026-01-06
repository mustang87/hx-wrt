#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

cd "${OPENWRT_DIR}"

# 1) 注入 overlay -> OpenWrt 的 files/
rm -rf files
cp -a "${HXWRT_DIR}/overlay" files

# 2) 注入自定义 package
mkdir -p package/hx
rm -rf package/hx/hx-brand
cp -a "${HXWRT_DIR}/package/hx-brand" package/hx/hx-brand

# 3) feeds（在 OpenWrt 默认 feeds 基础上追加）
#    如果你更希望“完全可控”，也可以改成覆盖整个 feeds.conf.default（后面再做）
cat > feeds.conf.hx <<'EOF'
src-git openclash https://github.com/vernesong/OpenClash.git
EOF

echo "[OK] injected overlay/package/feeds.conf.hx"
