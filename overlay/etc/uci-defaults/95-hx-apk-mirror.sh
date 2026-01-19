#!/bin/sh
set -e

exec >/tmp/hx-uci-95-apk.log 2>&1

LIST="/etc/apk/repositories.d/distfeeds.list"
USTC_BASE="https://mirrors.ustc.edu.cn/openwrt"
SNAPSHOT_URL="${USTC_BASE}/snapshots"

echo "[INFO] hx-apk-mirror start"

# 备份原文件
if [ -f "$LIST" ] && [ ! -f "${LIST}.bak" ]; then
  cp "$LIST" "${LIST}.bak" || true
  echo "[OK] backup created"
fi

if [ ! -f "$LIST" ]; then
  echo "[SKIP] $LIST not found"
  exit 0
fi

# 统一域名 + https
sed -i 's|downloads.openwrt.org|mirrors.ustc.edu.cn/openwrt|g' "$LIST" || true
sed -i 's|http://|https://|g' "$LIST" || true

# ========= 关键逻辑 =========
# 只要发现 snapshot / main / trunk / 25.x → 强制 snapshots
if grep -qiE 'snapshot|snapshots|/25\.|/main|/trunk' "$LIST"; then
  echo "[INFO] detected snapshot-style feeds, forcing snapshots"

  # 所有 releases/* / 25.x-* 统一干掉，指向 snapshots
  sed -i -E "s|${USTC_BASE}/releases/[^/]+|${SNAPSHOT_URL}|g" "$LIST"
  sed -i -E "s|${USTC_BASE}/snapshots.*|${SNAPSHOT_URL}|g" "$LIST"
else
  echo "[INFO] detected release feeds, keep releases path"
fi

echo "[OK] apk mirror updated"
exit 0
