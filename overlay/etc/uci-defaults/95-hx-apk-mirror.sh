#!/bin/sh
set -e

exec >/tmp/hx-uci-95-apk.log 2>&1

LIST="/etc/apk/repositories.d/distfeeds.list"

# 备份原文件（可选）
if [ -f "$LIST" ] && [ ! -f "${LIST}.bak" ]; then
  cp "$LIST" "${LIST}.bak" || true
fi

# 替换为中科大镜像，并统一 https
if [ -f "$LIST" ]; then
  sed -i 's|downloads.openwrt.org|mirrors.ustc.edu.cn/openwrt|g' "$LIST" || true
  sed -i 's|http://|https://|g' "$LIST" || true
  echo "[OK] apk mirror updated"
else
  echo "[SKIP] $LIST not found"
fi

exit 0
